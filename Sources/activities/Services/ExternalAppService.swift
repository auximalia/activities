import AppKit
import ActivitiesCore

/// Ein Programm, mit dem sich Ordner und Dateien oeffnen lassen.
///
/// Traegt den **echten** Namen aus dem Bundle, nicht eine fest verdrahtete
/// Zeichenkette: Wer statt Visual Studio Code das Programm Cursor benutzt, soll
/// „In Cursor oeffnen" lesen und nicht den Namen eines Programms, das er nie
/// installiert hat.
struct ExternalApp: Identifiable, Hashable, Sendable {
    var id: String { bundleID }
    let bundleID: String
    let name: String
    let url: URL
}

/// Startet Ordner und Dateien in einem **anderen** Programm als dem Finder.
///
/// **Warum die beiden Plaetze KEINE Liste „Oeffnen mit …" sind.** Der
/// naheliegende Weg waere ``NSWorkspace/urlsForApplications(toOpen:)``. Gemessen
/// an einem echten Benutzerordner liefert das neun Programme, davon fuenf
/// sinnlose (QuickTime, Archivierungsprogramm, Books, VLC …) – und
/// **Terminal.app fehlt darin ganz**, weil sie sich bei LaunchServices nicht als
/// Ordner-Oeffner meldet. Als *Ersatz* fuer die Plaetze taugt die Liste also
/// nicht: „Editor" und „Terminal" sind zwei verschiedene Handgriffe
/// (Code ansehen · hier arbeiten), keine zwei Eintraege einer Liste — und beide
/// tragen ein Kuerzel und wirken auch auf **Ordner**.
///
/// **⚠️ Dieser Absatz war bis v2.1.1 eine Absage an das Untermenue ueberhaupt,
/// und das war zu weit gegriffen (PR-71).** Beide Gruende zielen auf **Ersatz**,
/// nicht auf **Ergaenzung**: „fuenf sinnlose" ist ein Einwand gegen die
/// *automatische* Auswahl — dieselbe Liste zeigt der Finder, und dort ist sie
/// brauchbar, **weil der Anwender greift und nicht die Maschine**. Rauschen
/// stoert beim Raten, nicht beim Waehlen. Und „Terminal.app fehlt" betrifft das
/// Oeffnen von *Ordnern*; fuer eine Datei ist es belanglos.
///
/// Gemeldet wurde: *„bei manchen Dateien muss man das Programm auswaehlen um
/// oeffnen zu koennen."* Das Untermenue steht seit v2.1.1 im Datei-Kontextmenue
/// (``OpenWithMenu``) — **neben** den beiden Plaetzen, nicht an ihrer Stelle.
enum ExternalAppService {
    /// Kandidaten fuer den Platz „Editor" – **Reihenfolge = Vorrang** bei der
    /// Erkennung. Die Liste dient nur der Vorbelegung; jedes andere Programm
    /// laesst sich in den Einstellungen waehlen.
    static let editorCandidates = [
        "com.microsoft.VSCode",             // Visual Studio Code
        "com.todesktop.230313mzl4w4u92",    // Cursor
        "com.visualstudio.code.oss",        // VSCodium / Code – OSS
        "dev.zed.Zed",                      // Zed
        "com.sublimetext.4",
        "com.jetbrains.intellij",
        "com.barebones.bbedit",
        "com.apple.dt.Xcode",
    ]

    /// Kandidaten fuer den Platz „Terminal".
    ///
    /// ``Terminal.app`` steht bewusst am Ende: Sie ist auf jedem Mac vorhanden
    /// und wuerde sonst jede bewusst installierte Alternative verdecken.
    static let terminalCandidates = [
        "com.googlecode.iterm2",            // iTerm2
        "com.mitchellh.ghostty",            // Ghostty
        "dev.warp.Warp-Stable",             // Warp
        "co.zeit.hyper",                    // Hyper
        "net.kovidgoyal.kitty",
        "com.apple.Terminal",
    ]

    /// Loest eine Bundle-ID in ein installiertes Programm auf.
    ///
    /// **Bundle-ID statt Pfad** ist der Grund, warum diese Umleitung noetig ist:
    /// Ein gespeicherter Pfad zeigt ins Leere, sobald das Programm verschoben
    /// oder umbenannt wird; die Bundle-ID ueberlebt das.
    static func app(bundleID: String) -> ExternalApp? {
        guard !bundleID.isEmpty,
              let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
        else { return nil }
        return app(at: url)
    }

    /// Liest Name und Bundle-ID eines Programms an einem Pfad (Auswahldialog).
    ///
    /// **⚠️ Nicht ``CFBundleDisplayName``.** Der klingt richtig, ist es aber
    /// nicht: Visual Studio Code traegt dort schlicht `Code` – im Menue stand
    /// daraufhin „In Code öffnen", was auf Deutsch wie eine Programmiersprache
    /// klingt und nicht wie ein Programmname. Genommen wird deshalb der Name,
    /// den der Anwender **im Finder und im Dock sieht**: der lokalisierte
    /// Dateiname ohne die Endung `.app`.
    static func app(at url: URL) -> ExternalApp? {
        guard let id = Bundle(url: url)?.bundleIdentifier else { return nil }
        let shown = FileManager.default.displayName(atPath: url.path)
        var name = shown.hasSuffix(".app") ? String(shown.dropLast(4)) : shown
        if name.isEmpty { name = url.deletingPathExtension().lastPathComponent }
        return ExternalApp(bundleID: id, name: name, url: url)
    }

    /// Das erste **tatsaechlich installierte** Programm aus einer Kandidatenliste.
    static func firstInstalled(of bundleIDs: [String]) -> ExternalApp? {
        for id in bundleIDs {
            if let found = app(bundleID: id) { return found }
        }
        return nil
    }

    /// Alle installierten Kandidaten – Grundmenge der Auswahl in den Einstellungen.
    static func installed(among bundleIDs: [String]) -> [ExternalApp] {
        bundleIDs.compactMap { app(bundleID: $0) }
    }

    /// Alle Programme, die **jede** der uebergebenen Dateien oeffnen koennen –
    /// die Vorlage fuer „Oeffnen mit" (PR-71).
    ///
    /// **⚠️ Die Kennung ist der Pfad, nicht die Bundle-ID.** Drei Fassungen von
    /// IDLE teilen sich eine Bundle-ID; nach ihr entdoppelt blieben zwei auf der
    /// Strecke. Begruendung an ``OpenWithMenu/Candidate/id``.
    ///
    /// **⚠️ Die Version wird hier gelesen, aber erst im Kern verwendet** – und
    /// zwar nur dort, wo ein Name mehrfach vorkommt. Sie hier schon anzuhaengen
    /// hiesse, die Regel in die Abfrage zu schmuggeln.
    static func candidates(toOpen urls: [URL]) -> [OpenWithMenu.Candidate] {
        OpenWithMenu.common(urls.map { url in
            NSWorkspace.shared.urlsForApplications(toOpen: url).compactMap(candidate(at:))
        })
    }

    /// Das Standardprogramm einer Datei – der erste Eintrag des Untermenues.
    static func defaultCandidate(toOpen url: URL) -> OpenWithMenu.Candidate? {
        NSWorkspace.shared.urlForApplication(toOpen: url).flatMap(candidate(at:))
    }

    /// Ein Programmbuendel als Kandidat: Pfad, Anzeigename, Kurzversion.
    ///
    /// Der Name kommt aus ``app(at:)`` und damit aus derselben Quelle wie in den
    /// Einstellungen – nicht aus ``CFBundleDisplayName``, siehe dort.
    private static func candidate(at url: URL) -> OpenWithMenu.Candidate? {
        guard let app = app(at: url) else { return nil }
        let version = Bundle(url: url)?
            .object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        return OpenWithMenu.Candidate(id: url.path, name: app.name, version: version)
    }

    /// Ein Kandidat zurueck zum startbaren Programm.
    static func app(candidate: OpenWithMenu.Entry) -> ExternalApp? {
        app(at: URL(fileURLWithPath: candidate.id))
    }

    /// Oeffnet die Objekte im angegebenen Programm.
    ///
    /// **Warum ``open(_:withApplicationAt:configuration:)`` und nicht
    /// ``NSWorkspace/open(_:)``?** Letzteres folgt der Typzuordnung und landete
    /// bei einem Ordner immer im Finder. Diese Fassung entspricht `open -a` und
    /// uebergeht den Typ-Abgleich – **noetig**, weil Terminal.app sich gar nicht
    /// als Ordner-Oeffner registriert.
    ///
    /// - Parameter onFailure: Wird auf dem Hauptstrang mit einer lesbaren
    ///   Begruendung aufgerufen. Ein stiller Rueckfall auf den Finder waere
    ///   schlimmer als gar nichts: Der Anwender haelt den Handgriff fuer
    ///   erledigt und sucht das Fenster im falschen Programm.
    static func open(
        _ urls: [URL],
        with app: ExternalApp,
        onFailure: @escaping (String) -> Void
    ) {
        guard !urls.isEmpty else { return }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.open(urls, withApplicationAt: app.url, configuration: configuration) { _, error in
            guard let error else { return }
            let reason = error.localizedDescription
            DispatchQueue.main.async {
                onFailure("„\(app.name)“ konnte nicht geöffnet werden: \(reason)")
            }
        }
    }
}
