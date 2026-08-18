import Foundation
import Observation
import ActivitiesCore

/// Weiß, welche Dateien unter Versionsverwaltung stehen.
///
/// **⚠️ Zwei getrennte Auskünfte, weil sie verschieden teuer sind.**
///
/// 1. **„Liegt in einer Arbeitskopie"** – Aufstieg über die Ordner, bis `.git`
///    oder `.svn` liegt. Reine `stat`-Aufrufe, sofort verfügbar. Gemessen am
///    Bestand des Anwenders: 8.763 Ordner, ohne Puffer 71.205 Aufstiege in
///    738 ms – **mit** Ahnen-Puffer einer je Ordner.
/// 2. **„Ist versioniert"** – die Liste der geführten Dateien, je Arbeitskopie
///    einmal über einen Unterprozess. Gemessen: `git ls-files` 26–29 ms,
///    `svn status --xml` 98–230 ms je Arbeitskopie.
///
/// **⚠️ Der Unterschied ist nicht akademisch.** Auf der Platte des Anwenders
/// liegen 35.182 Dateien in git-Repos, **versioniert sind 470** – der Rest ist
/// Bauwerk. „Liegt in einem Repo" hätte 98,7 % Fehlalarm gehabt.
///
/// **⚠️ Solange (2) noch lädt, antwortet (1).** Versioniert ist immer eine
/// Teilmenge von „liegt in einer Arbeitskopie" – die Rückfallantwort irrt also
/// nur in Richtung **Warnung**, nie in Richtung Sorglosigkeit.
@MainActor
@Observable
final class RepoIndex {

    /// Ordner → Arbeitskopie. Enthält auch die Ahnen jedes Aufstiegs.
    @ObservationIgnored private var byFolder: [URL: RepoMark?] = [:]
    /// Wurzel → geführte Dateien. `nil` = noch nicht geladen.
    @ObservationIgnored private var tracked: [URL: Set<URL>] = [:]

    /// Steigt bei jedem abgeschlossenen Ladevorgang – die Ansicht hängt daran.
    private(set) var generation = 0

    @ObservationIgnored private var laufend: Task<Void, Never>?

    // MARK: - Auskunft

    /// In welcher Arbeitskopie liegt dieser Ordner?
    func mark(forFolder folder: URL) -> RepoMark? {
        if let fertig = byFolder[folder] { return fertig }

        // ⚠️ Der Aufstieg traegt ALLE besuchten Ahnen ein, nicht nur den
        // Startordner – daraus wird aus 71.205 Schritten einer je Ordner.
        var besucht: [URL] = []
        let treffer = RepoDetection.find(from: folder) { kandidat in
            besucht.append(kandidat)
            let fm = FileManager.default
            // ⚠️ `.git` kann eine DATEI sein: Bei Worktrees und Submodulen steht
            // dort `gitdir: …`. Wer nur auf Ordner prueft, uebersieht jedes
            // Submodul – deshalb `fileExists` ohne Typfrage.
            if fm.fileExists(atPath: kandidat.appendingPathComponent(".git").path) { return .git }
            if fm.fileExists(atPath: kandidat.appendingPathComponent(".svn").path) { return .svn }
            return nil
        }
        for ordner in besucht { byFolder[ordner] = treffer }
        return treffer
    }

    /// Steht diese Datei unter Versionsverwaltung?
    ///
    /// Solange die Liste der geführten Dateien noch lädt, gilt die Zugehörigkeit
    /// zur Arbeitskopie – siehe Typkommentar.
    func mark(forFile url: URL) -> RepoMark? {
        guard let treffer = mark(forFolder: url.deletingLastPathComponent()) else { return nil }
        guard let geführt = tracked[treffer.root] else { return treffer }
        return geführt.contains(url.standardizedFileURL) ? treffer : nil
    }

    /// Wie viele der Dateien je Verwaltung versioniert sind – für den Dialog.
    func versionedCounts(_ urls: [URL]) -> [RepoKind: Int] {
        var result: [RepoKind: Int] = [:]
        for url in urls {
            guard let treffer = mark(forFile: url) else { continue }
            result[treffer.kind, default: 0] += 1
        }
        return result
    }

    // MARK: - Laden

    /// Lädt die Listen der geführten Dateien für alle vorkommenden Arbeitskopien.
    ///
    /// **⚠️ Im Hintergrund und abbrechbar.** Ein `svn status` auf einer großen
    /// Arbeitskopie dauert Zehntelsekunden; auf einem Netzlaufwerk kann es
    /// deutlich länger dauern. Auf dem Hauptstrang stünde dann die Liste.
    func refresh(folders: [URL]) {
        laufend?.cancel()
        var wurzeln: Set<RepoMark> = []
        for ordner in folders {
            if let treffer = mark(forFolder: ordner) { wurzeln.insert(treffer) }
        }
        let offen = wurzeln.filter { tracked[$0.root] == nil }
        guard !offen.isEmpty else { return }

        laufend = Task { [weak self] in
            for marke in offen {
                if Task.isCancelled { return }
                let menge = await Self.lade(marke)
                guard let self, !Task.isCancelled else { return }
                self.tracked[marke.root] = menge
                self.generation &+= 1
            }
        }
    }

    /// Vergisst alles – nach einem vollständigen Suchlauf.
    func invalidate() {
        laufend?.cancel()
        byFolder = [:]
        tracked = [:]
        generation &+= 1
    }

    nonisolated private static func lade(_ marke: RepoMark) async -> Set<URL> {
        await Task.detached(priority: .utility) {
            switch marke.kind {
            case .git: gitTracked(at: marke.root)
            case .svn: svnTracked(at: marke.root)
            }
        }.value
    }

    // MARK: - Die beiden Abfragen

    /// **⚠️ `--no-optional-locks`**, damit die Abfrage die Index-Datei nicht
    /// anfasst. Ohne das schreibt git beim Lesen zurück – ein Programm, das nur
    /// **anzeigen** will, hätte fremde Arbeitskopien verändert.
    ///
    /// **⚠️ `core.quotePath=false` und `-z`**, sonst kommen Umlaute als
    /// Oktal-Fluchtfolgen zurück und Pfade mit Zeilenumbruch zerreißen die
    /// Ausgabe.
    nonisolated private static func gitTracked(at root: URL) -> Set<URL> {
        let ausgabe = run("/usr/bin/git",
                          ["--no-optional-locks", "-c", "core.quotePath=false", "ls-files", "-z"],
                          in: root)
        return Set(ausgabe.split(separator: "\0").map {
            root.appendingPathComponent(String($0)).standardizedFileURL
        })
    }

    /// **⚠️ `--xml`, nicht die Spaltenausgabe.** Die Textform von `svn status`
    /// hat Status-Spalten fester Breite und den Pfad dahinter – bei Pfaden mit
    /// Leerzeichen und bei abweichenden Zuständen ist das nicht zuverlässig zu
    /// trennen. Die XML-Form nennt Pfad und Zustand getrennt.
    ///
    /// **⚠️ `svn status`, nicht `svn list`.** Letzteres fragt den **Server** –
    /// eine Netzanfrage für eine Anzeige, und ohne Verbindung schlägt sie fehl.
    nonisolated private static func svnTracked(at root: URL) -> Set<URL> {
        let ausgabe = run("/usr/bin/svn", ["status", "-v", "--xml", "--no-ignore", "."], in: root)
        guard let daten = ausgabe.data(using: .utf8) else { return [] }
        let leser = SvnStatusParser(root: root)
        let parser = XMLParser(data: daten)
        parser.delegate = leser
        parser.parse()
        return leser.versioniert
    }

    nonisolated private static func run(_ pfad: String, _ argumente: [String], in ordner: URL) -> String {
        let prozess = Process()
        prozess.executableURL = URL(fileURLWithPath: pfad)
        prozess.arguments = argumente
        prozess.currentDirectoryURL = ordner
        let rohr = Pipe()
        prozess.standardOutput = rohr
        prozess.standardError = FileHandle.nullDevice
        do {
            try prozess.run()
            let daten = rohr.fileHandleForReading.readDataToEndOfFile()
            prozess.waitUntilExit()
            return String(data: daten, encoding: .utf8) ?? ""
        } catch {
            // Kein git/svn auf diesem Rechner: keine Auskunft, keine Meldung.
            // ⚠️ Das ist KEIN Fehlerfall fuer den Anwender – er hat dann nur
            // keinen Anhaenger, und das ist die richtige Antwort.
            return ""
        }
    }
}

/// Liest `svn status --xml` und sammelt die **versionierten** Pfade.
private final class SvnStatusParser: NSObject, XMLParserDelegate {
    let root: URL
    var versioniert: Set<URL> = []
    private var aktuellerPfad: String?

    init(root: URL) { self.root = root }

    func parser(_ parser: XMLParser, didStartElement element: String,
                namespaceURI: String?, qualifiedName: String?,
                attributes: [String: String]) {
        if element == "entry" {
            aktuellerPfad = attributes["path"]
        } else if element == "wc-status", let pfad = aktuellerPfad {
            let zustand = attributes["item"] ?? ""
            // ⚠️ Aufgezaehlt wird, was NICHT gefuehrt ist. Die Liste der
            // gefuehrten Zustaende ist laenger (normal, modified, added,
            // replaced, conflicted, missing, deleted …) und waechst mit svn –
            // eine Positivliste liefe der naechsten Version hinterher.
            let ungefuehrt = ["unversioned", "ignored", "external", "none"]
            if !ungefuehrt.contains(zustand) {
                versioniert.insert(URL(fileURLWithPath: pfad, relativeTo: root).standardizedFileURL)
            }
            aktuellerPfad = nil
        }
    }
}
