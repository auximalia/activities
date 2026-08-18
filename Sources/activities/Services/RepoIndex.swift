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
    /// Wurzel → eingetragene Fernadresse. Schlüssel fehlt = noch nicht gelesen,
    /// `.some(nil)` = gelesen und keine vorhanden.
    ///
    /// **⚠️ Kommt im selben Durchgang wie ``tracked``.** Beides braucht denselben
    /// Unterprozess-Ausflug je Arbeitskopie; zwei getrennte Ladewege wären zwei
    /// Zustände, die auseinanderlaufen können – und der zweite käme dann
    /// ausgerechnet dann noch nicht an, wenn das Menü schon offen ist.
    @ObservationIgnored private var remotes: [URL: String?] = [:]

    /// Steigt bei jedem abgeschlossenen Ladevorgang – die Ansicht hängt daran.
    private(set) var generation = 0

    /// Läuft gerade – **wird nur von ``invalidate()`` abgebrochen**.
    @ObservationIgnored private var laufend: Task<Void, Never>?
    /// Arbeitskopien, die noch zu lesen sind. Wächst bei jedem ``refresh(folders:)``.
    @ObservationIgnored private var offen: Set<RepoMark> = []

    // MARK: - Auskunft

    /// In welcher Arbeitskopie liegt dieser Ordner?
    func mark(forFolder folder: URL) -> RepoMark? {
        if let fertig = byFolder[folder] { return fertig }

        // ⚠️ Der Aufstieg traegt ALLE besuchten Ahnen ein, nicht nur den
        // Startordner – daraus wird aus 71.205 Schritten einer je Ordner.
        var visited: [URL] = []
        let found = RepoDetection.find(from: folder) { candidate in
            visited.append(candidate)
            let fm = FileManager.default
            // ⚠️ `.git` kann eine DATEI sein: Bei Worktrees und Submodulen steht
            // dort `gitdir: …`. Wer nur auf Ordner prueft, uebersieht jedes
            // Submodul – deshalb `fileExists` ohne Typfrage.
            if fm.fileExists(atPath: candidate.appendingPathComponent(".git").path) { return .git }
            if fm.fileExists(atPath: candidate.appendingPathComponent(".svn").path) { return .svn }
            return nil
        }
        for folder in visited { byFolder[folder] = found }
        if let found { vormerken(found) }
        return found
    }

    /// Meldet den Bedarf an: Diese Arbeitskopie soll gelesen werden.
    ///
    /// **⚠️ Der Index füttert sich selbst – das ist der eigentliche Fund.**
    /// Bisher hing das Laden allein an ``refresh(folders:)``, und das musste ein
    /// **Aufrufer** zur richtigen Zeit auslösen. Genau dort ist es liegen
    /// geblieben: Das Untermenü zeigte dauerhaft „Adresse wird gelesen …", weil
    /// nie jemand gelesen hat. *Eine Zusicherung, die davon abhängt, dass ein
    /// fremdes Bauteil sich erinnert, ist keine.*
    ///
    /// Jetzt gilt der Zusammenhang, der ohnehin stimmt: **Wer nach der
    /// Arbeitskopie eines Ordners fragt, braucht die Auskunft dazu.** Jede
    /// gezeichnete Zeile mit Anhänger meldet den Bedarf damit selbst an — und
    /// eine Zeile wird lange vor dem Rechtsklick gezeichnet.
    ///
    /// **⚠️ Nur beim Puffer-Fehlschlag, nicht bei jedem Treffer.** Das hier
    /// läuft im Rumpf einer Zeile; auf dem heißen Pfad darf nichts stehen, was
    /// je Neuzeichnung Arbeit macht. Nach ``invalidate()`` fehlt der Puffer
    /// wieder, und damit wird auch wieder angemeldet.
    ///
    /// **⚠️ Der Anstoß wird auf die nächste Runde verschoben.** `mark(forFolder:)`
    /// wird aus Ansichtsrümpfen gerufen; einen Zustand mitten in einer
    /// Aktualisierung zu ändern, ist genau das, wovor SwiftUI warnt.
    private func vormerken(_ mark: RepoMark) {
        guard tracked[mark.root] == nil, offen.insert(mark).inserted else { return }
        Task { @MainActor [weak self] in self?.starteNaechsten() }
    }


    /// Steht diese Datei unter Versionsverwaltung?
    ///
    /// Solange die Liste der geführten Dateien noch lädt, gilt die Zugehörigkeit
    /// zur Arbeitskopie – siehe Typkommentar.
    func mark(forFile url: URL) -> RepoMark? {
        guard let found = mark(forFolder: url.deletingLastPathComponent()) else { return nil }
        guard let geführt = tracked[found.root] else { return found }
        return geführt.contains(url.standardizedFileURL) ? found : nil
    }

    /// Wie viele der Dateien je Verwaltung versioniert sind – für den Dialog.
    func versionedCounts(_ urls: [URL]) -> [RepoKind: Int] {
        var result: [RepoKind: Int] = [:]
        for url in urls {
            guard let found = mark(forFile: url) else { continue }
            result[found.kind, default: 0] += 1
        }
        return result
    }

    /// Welche Fernadresse trägt diese Arbeitskopie?
    ///
    /// **⚠️ Fragt die Platte NICHT.** Diese Auskunft wird aus dem Kontextmenü
    /// gelesen, und dessen Rumpf läuft erst beim Aufklappen – ein Unterprozess
    /// darin ließe das Menü sichtbar später aufgehen, auf einem Netzlaufwerk
    /// spürbar lange. Geladen wird in ``refresh(folders:)``, hier steht nur der
    /// Puffer. Solange er leer ist, lautet die Antwort ``RepoRemote/unknown``
    /// und nicht ``RepoRemote/missing``.
    func remote(for mark: RepoMark) -> RepoRemote {
        guard let entry = remotes[mark.root] else { return .unknown }
        guard let address = entry else { return .missing }
        return .address(address)
    }

    // MARK: - Laden

    /// Wärmt die Arbeitskopien vor, die in dieser Ordnerliste vorkommen.
    ///
    /// **⚠️ Nur noch ein Vorlauf, keine Zusicherung mehr.** Die Zusicherung
    /// hängt seit v2.0.14 an ``vormerken(_:)``: Jede Zeile, die einen Anhänger
    /// zeichnet, meldet ihren Bedarf selbst an. Diese Methode nimmt die Arbeit
    /// nur **früher** vorweg — vor dem ersten Zeichnen, für alle Ordner auf
    /// einmal — und darf deshalb ausfallen, ohne dass etwas fehlt.
    ///
    /// **⚠️ Sie bricht nichts mehr ab, aber das war NICHT die Ursache.** Bis
    /// v2.0.13 begann sie mit `laufend?.cancel()`, und weil sie aus
    /// ``ReportViewModel/applyWindowChange()`` kommt, warf jeder Filter-,
    /// Zeitraum- und Beobachterlauf die halb fertige Arbeit weg. Das sah nach
    /// der Erklärung aus. *Ein Nachbau hat sie widerlegt:* Unter dreißig
    /// Abbrüchen im 30-ms-Takt lieferte auch der alte Bau — 25 ms nachdem der
    /// Sturm aufhörte. **Ein Abbruch, dem ein weiterer Aufruf folgt, verliert
    /// nichts.** Der Abbruch ist trotzdem raus, weil Wegwerfen von gültiger
    /// Arbeit keinen Vorteil hat; als Fehlererklärung taugt er nicht.
    ///
    /// **⚠️ Die Ursache war die Abhängigkeit selbst.** Das Laden fand nur statt,
    /// wenn ein **Aufrufer** sich erinnerte. Gemessen im Nachbau: Wird
    /// `refresh` nie gerufen, kommt die Auskunft nie — und genau das war zu
    /// sehen. Mit ``vormerken(_:)`` kommt sie **ohne jeden Aufrufer** nach
    /// 75 ms, allein vom Zeichnen der Zeilen.
    func refresh(folders: [URL]) {
        for folder in folders { _ = mark(forFolder: folder) }
    }

    /// Nimmt sich die nächste offene Arbeitskopie vor – eine nach der anderen.
    ///
    /// ⚠️ Seriell: Ein `svn status` je Wurzel gleichzeitig wäre der
    /// Unterprozess-Sturm, den der Hintergrundlauf vermeiden soll.
    private func starteNaechsten() {
        guard laufend == nil, let mark = offen.first else { return }
        offen.remove(mark)
        laufend = Task { [weak self] in
            let amount = await Self.load(mark)
            guard let self, !Task.isCancelled else { return }
            self.tracked[mark.root] = amount.tracked
            self.remotes[mark.root] = amount.remote
            self.generation &+= 1
            self.laufend = nil
            self.starteNaechsten()
        }
    }

    /// Vergisst alles – nach einem vollständigen Suchlauf.
    func invalidate() {
        laufend?.cancel()
        laufend = nil
        offen = []
        byFolder = [:]
        tracked = [:]
        remotes = [:]
        generation &+= 1
    }

    nonisolated private static func load(_ mark: RepoMark) async -> (tracked: Set<URL>, remote: String?) {
        await Task.detached(priority: .utility) {
            switch mark.kind {
            case .git: (gitTracked(at: mark.root), gitRemote(at: mark.root))
            case .svn: (svnTracked(at: mark.root), svnRemote(at: mark.root))
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
        return leser.versioned
    }

    /// Die eingetragene Fernadresse einer git-Arbeitskopie.
    ///
    /// **⚠️ `config --get`, nicht `remote get-url`.** Beide lesen dasselbe Feld,
    /// aber `config` gibt es seit jeher und schweigt, wenn nichts da ist;
    /// `remote get-url` schreibt in einem solchen Fall auf die Fehlerausgabe.
    /// Hier ist „nichts eingetragen" ein **Ergebnis**, kein Fehler.
    ///
    /// **⚠️ Nur `origin`.** Ein Repository kann mehrere Gegenstellen führen;
    /// welche davon „das Repository" ist, weiß nur der Anwender. `origin` ist
    /// die Antwort, die git selbst überall voraussetzt – und eine Auswahlliste
    /// im Kontextmenü wäre eine Frage an einen, der sie nicht gestellt hat.
    nonisolated private static func gitRemote(at root: URL) -> String? {
        clean(run("/usr/bin/git",
                  ["--no-optional-locks", "config", "--get", "remote.origin.url"],
                  in: root))
    }

    /// Die Adresse, unter der die svn-Arbeitskopie ausgecheckt wurde.
    ///
    /// **⚠️ `svn info` auf einem PFAD fragt keinen Server.** Es liest die
    /// örtliche `.svn/wc.db`; nur `svn info <URL>` ginge ins Netz. Gemessen:
    /// 70–110 ms je Arbeitskopie, also in derselben Größenordnung wie das
    /// `svn status`, das ohnehin schon läuft.
    ///
    /// **⚠️ Die Adresse der Arbeitskopie, nicht die Repository-Wurzel.** In svn
    /// arbeitet man in `…/trunk` oder `…/branches/x`; `repos-root-url` führte
    /// auf eine Ebene, die mit der Arbeit nichts zu tun hat.
    nonisolated private static func svnRemote(at root: URL) -> String? {
        clean(run("/usr/bin/svn", ["info", "--show-item", "url", "."], in: root))
    }

    /// Eine Zeile Prozessausgabe → Adresse oder ``nil``.
    nonisolated private static func clean(_ ausgabe: String) -> String? {
        let getrimmt = ausgabe.trimmingCharacters(in: .whitespacesAndNewlines)
        return getrimmt.isEmpty ? nil : getrimmt
    }

    nonisolated private static func run(_ path: String, _ argumente: [String], in folder: URL) -> String {
        let prozess = Process()
        prozess.executableURL = URL(fileURLWithPath: path)
        prozess.arguments = argumente
        prozess.currentDirectoryURL = folder
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
    var versioned: Set<URL> = []
    private var currentPath: String?

    init(root: URL) { self.root = root }

    func parser(_ parser: XMLParser, didStartElement element: String,
                namespaceURI: String?, qualifiedName: String?,
                attributes: [String: String]) {
        if element == "entry" {
            currentPath = attributes["path"]
        } else if element == "wc-status", let path = currentPath {
            let state = attributes["item"] ?? ""
            // ⚠️ Aufgezaehlt wird, was NICHT gefuehrt ist. Die Liste der
            // gefuehrten Zustaende ist laenger (normal, modified, added,
            // replaced, conflicted, missing, deleted …) und waechst mit svn –
            // eine Positivliste liefe der naechsten Version hinterher.
            let untracked = ["unversioned", "ignored", "external", "none"]
            if !untracked.contains(state) {
                versioned.insert(URL(fileURLWithPath: path, relativeTo: root).standardizedFileURL)
            }
            currentPath = nil
        }
    }
}
