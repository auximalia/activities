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
    /// Wurzel → eingetragene Fernadresse. Schlüssel fehlt = noch nicht gelesen.
    ///
    /// **⚠️ Kommt im selben Durchgang wie ``tracked``.** Beides braucht denselben
    /// Unterprozess-Ausflug je Arbeitskopie; zwei getrennte Ladewege wären zwei
    /// Zustände, die auseinanderlaufen können – und der zweite käme dann
    /// ausgerechnet dann noch nicht an, wenn das Menü schon offen ist.
    @ObservationIgnored private var remotes: [URL: RepoRemote] = [:]

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
        remotes[mark.root] ?? .unknown
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
            // **⚠️ Bei gescheiterter Abfrage wird `tracked` NICHT gesetzt.**
            // Ein fehlender Schlüssel heißt „weiß ich nicht" und lässt die
            // Rückfallantwort aus ``mark(forFile:)`` greifen – „liegt in einer
            // Arbeitskopie". Eine leere Menge hieße dagegen „nichts davon ist
            // versioniert", und genau das hat die App behauptet, als
            // `/usr/bin/svn` ins Leere zeigte.
            if let gefuehrt = amount.tracked { self.tracked[mark.root] = gefuehrt }
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

    /// - Returns: `tracked == nil` heißt **Abfrage gescheitert**, nicht „leer".
    nonisolated private static func load(_ mark: RepoMark) async -> (tracked: Set<URL>?, remote: RepoRemote) {
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
    nonisolated private static func gitTracked(at root: URL) -> Set<URL>? {
        guard let lauf = run(.git,
                             ["--no-optional-locks", "-c", "core.quotePath=false", "ls-files", "-z"],
                             in: root),
              lauf.status == 0 else { return nil }
        return Set(lauf.ausgabe.split(separator: "\0").map {
            root.appendingPathComponent(String($0)).standardizedFileURL
        })
    }

    /// **⚠️ `config --get`, nicht `remote get-url`.** Beide lesen dasselbe Feld,
    /// aber `config` gibt es seit jeher.
    ///
    /// **⚠️ Rückgabe 1 heißt „kein `origin`", nicht „Fehler".** `git config
    /// --get` beendet sich mit 1, wenn der Schlüssel fehlt – das ist hier ein
    /// **Ergebnis**. Nur ein Programm, das gar nicht erst startet, ist ein
    /// Fehlschlag.
    ///
    /// **⚠️ Nur `origin`.** Ein Repository kann mehrere Gegenstellen führen;
    /// eine Auswahlliste im Kontextmenü wäre eine Frage an einen, der sie nicht
    /// gestellt hat.
    nonisolated private static func gitRemote(at root: URL) -> RepoRemote {
        guard let lauf = run(.git, ["--no-optional-locks", "config", "--get", "remote.origin.url"],
                             in: root) else { return .unreadable }
        guard lauf.status == 0 else { return .missing }
        return adresse(lauf.ausgabe)
    }

    /// **⚠️ `--xml`, nicht die Spaltenausgabe.** Die Textform von `svn status`
    /// hat Status-Spalten fester Breite und den Pfad dahinter – bei Pfaden mit
    /// Leerzeichen und bei abweichenden Zuständen ist das nicht zuverlässig zu
    /// trennen. Die XML-Form nennt Pfad und Zustand getrennt.
    ///
    /// **⚠️ `svn status`, nicht `svn list`.** Letzteres fragt den **Server** –
    /// eine Netzanfrage für eine Anzeige, und ohne Verbindung schlägt sie fehl.
    nonisolated private static func svnTracked(at root: URL) -> Set<URL>? {
        guard let lauf = run(.svn, ["status", "-v", "--xml", "--no-ignore", "."], in: root),
              lauf.status == 0,
              let daten = lauf.ausgabe.data(using: .utf8) else { return nil }
        let leser = SvnStatusParser(root: root)
        let parser = XMLParser(data: daten)
        parser.delegate = leser
        parser.parse()
        return leser.versioned
    }

    /// Die Adresse, unter der die svn-Arbeitskopie ausgecheckt wurde.
    ///
    /// **⚠️ `svn info` auf einem PFAD fragt keinen Server.** Es liest die
    /// örtliche `.svn/wc.db`; nur `svn info <URL>` ginge ins Netz. Gemessen an
    /// der Arbeitskopie des Anwenders: **126 ms**.
    ///
    /// **⚠️ Die Adresse der Arbeitskopie, nicht die Repository-Wurzel.** In svn
    /// arbeitet man in `…/trunk` oder `…/branches/x`; `repos-root-url` führte
    /// auf eine Ebene, die mit der Arbeit nichts zu tun hat.
    nonisolated private static func svnRemote(at root: URL) -> RepoRemote {
        guard let lauf = run(.svn, ["info", "--show-item", "url", "."], in: root),
              lauf.status == 0 else { return .unreadable }
        return adresse(lauf.ausgabe)
    }

    /// Eine Zeile Prozessausgabe → Adresse oder „keine hinterlegt".
    nonisolated private static func adresse(_ ausgabe: String) -> RepoRemote {
        let getrimmt = ausgabe.trimmingCharacters(in: .whitespacesAndNewlines)
        return getrimmt.isEmpty ? .missing : .address(getrimmt)
    }

    /// Führt das Programm aus – ``nil``, wenn es **gar nicht lief**.
    ///
    /// **⚠️ Der Unterschied zwischen „nichts gefunden" und „nicht nachgesehen"
    /// ist der Kern dieses Rückgabetyps.** Vorher gab diese Methode bei einem
    /// Fehlschlag eine leere Zeichenkette zurück – nicht zu unterscheiden von
    /// einer erfolgreichen Abfrage ohne Treffer. Aus „`svn` gibt es hier nicht"
    /// wurde damit „keine dieser Dateien ist versioniert", und das war eine
    /// **Behauptung** an der Stelle, an der Schweigen richtig gewesen wäre.
    ///
    /// Der Rückgabestatus bleibt drin, weil er nicht überall dasselbe heißt:
    /// `git config --get` meldet 1 für „Schlüssel fehlt" – ein Ergebnis, kein
    /// Fehler. Diese Deutung gehört zum Aufrufer, nicht hierher.
    nonisolated private static func run(_ kind: RepoKind, _ argumente: [String],
                                        in folder: URL) -> (status: Int32, ausgabe: String)? {
        let fm = FileManager.default
        guard let pfad = RepoTooling.executable(for: kind, isExecutable: fm.isExecutableFile(atPath:))
        else { return nil }
        let prozess = Process()
        prozess.executableURL = URL(fileURLWithPath: pfad)
        prozess.arguments = argumente
        prozess.currentDirectoryURL = folder
        let rohr = Pipe()
        prozess.standardOutput = rohr
        prozess.standardError = FileHandle.nullDevice
        do {
            try prozess.run()
            let daten = rohr.fileHandleForReading.readDataToEndOfFile()
            prozess.waitUntilExit()
            return (prozess.terminationStatus, String(data: daten, encoding: .utf8) ?? "")
        } catch {
            // ⚠️ „Konnte nicht starten" ist KEIN leeres Ergebnis. Der Aufrufer
            // laesst daraufhin die Rueckfallantwort greifen, statt etwas ueber
            // die Dateien zu behaupten.
            return nil
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
