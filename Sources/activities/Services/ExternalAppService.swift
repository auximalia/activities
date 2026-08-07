import AppKit

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
/// **Warum kein Untermenue „Oeffnen mit …"?** Der naheliegende Weg waere
/// ``NSWorkspace/urlsForApplications(toOpen:)``. Gemessen an einem echten
/// Benutzerordner liefert das neun Programme, davon fuenf sinnlose (QuickTime,
/// Archivierungsprogramm, Books, VLC …) – und **Terminal.app fehlt darin ganz**,
/// weil sie sich bei LaunchServices nicht als Ordner-Oeffner meldet. Ein Menue,
/// in dem man den einen brauchbaren Eintrag zwischen Rauschen sucht und den
/// wichtigsten gar nicht findet, ist keine Hilfe.
///
/// Stattdessen **zwei benannte Plaetze**: „Editor" und „Terminal". Das sind zwei
/// verschiedene Handgriffe (Code ansehen · hier arbeiten), keine zwei Eintraege
/// einer Liste.
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
