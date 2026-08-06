import Foundation

/// Regeln zum Ausschluss von Ordnern und Dateien.
///
/// **Zweck:** Die App soll melden, woran **Menschen** gearbeitet haben. Ohne
/// Ausschlüsse meldet sie Dateisystem-Ereignisse – darunter Erzeugnisse von
/// Übersetzern, Paketverwaltungen und Sicherungen, die Zeitstempel setzen, ohne
/// dass jemand etwas getan hat.
///
/// Versteckte Objekte (Dotfiles, System-Attribut „versteckt") überspringt der
/// Scanner ohnehin und müssen hier nicht gelistet werden.
public struct ExclusionRules: Sendable, Equatable {
    /// Ordnernamen, die nicht betreten werden.
    public let folders: Set<String>
    /// Dateinamen bzw. Glob-Muster (z. B. ``~$*``), die ignoriert werden.
    public let filePatterns: [String]
    /// Vollständige Pfade, die der Anwender ausdrücklich ausgeblendet hat.
    ///
    /// Bewusst **pfadgenau** und nicht namensbasiert: „Diesen Ordner nicht mehr
    /// zeigen" soll genau diesen einen Ordner betreffen – nicht ungefragt alle
    /// gleichnamigen anderswo.
    public let excludedPaths: Set<String>

    public init(
        folders: Set<String>,
        filePatterns: [String],
        excludedPaths: Set<String> = []
    ) {
        self.folders = folders
        self.filePatterns = filePatterns
        // **Pfade vereinheitlichen.** Dieselbe Stelle hat auf macOS zwei
        // Schreibweisen: `/var/...` (Symlink) und `/private/var/...`. Der
        // Verzeichnis-Enumerator liefert die aufgeloeste Fassung, eine
        // gespeicherte Regel meist die kurze – ohne Vereinheitlichung greift
        // der Ausschluss schlicht nicht.
        self.excludedPaths = Set(excludedPaths.map(Self.normalize))
    }

    /// Vereinheitlicht einen Pfad (Symlinks aufgeloest, ohne Schrägstrich am Ende).
    public static func normalize(_ path: String) -> String {
        URL(fileURLWithPath: path).resolvingSymlinksInPath().standardizedFileURL.path
    }

    // MARK: - Vorgaben

    /// Ordner, deren Name **eindeutig** auf Werkzeug-Erzeugnisse hinweist.
    /// Diese werden immer ausgeschlossen – ein Anwender legt keinen eigenen
    /// Ordner namens `node_modules` oder `DerivedData` an.
    public static let unambiguousBuildFolders: Set<String> = [
        ".git", ".svn", ".hg",
        "node_modules", "__pycache__", ".venv", "venv",
        ".build", "DerivedData", "Pods", ".gradle", ".next", ".nuxt",
        ".pytest_cache", ".mypy_cache", ".tox", ".parcel-cache", ".turbo",
        "Library", "$RECYCLE.BIN", "System Volume Information",
    ]

    /// Ordnernamen, die **auch** legitime Projektordner sein können.
    ///
    /// Standardmäßig **nicht** ausgeschlossen: Wer einen echten Ordner namens
    /// „build" oder „dist" führt, würde ihn sonst stillschweigend verlieren.
    /// Zuschaltbar in den Einstellungen.
    public static let ambiguousBuildFolders: Set<String> = [
        "build", "dist", "out", "target", "vendor", "bin", "obj",
    ]

    /// Dateiendungen, die ein Verzeichnis zu einem **Dokument** machen.
    ///
    /// Rückfall, falls ``URLResourceKey.isPackageKey`` nicht zur Verfügung steht
    /// (Portabilität, siehe Konzept 10.2).
    public static let packageExtensions: Set<String> = [
        "app", "bundle", "framework", "plugin", "kext", "xpc",
        "photoslibrary", "musiclibrary", "tvlibrary", "rtfd",
        "xcodeproj", "xcworkspace", "playground", "pages", "numbers", "key",
        "scptd", "download", "sparsebundle",
    ]

    public static let `default` = ExclusionRules(
        folders: unambiguousBuildFolders,
        filePatterns: [".DS_Store", "Thumbs.db", "desktop.ini", "~$*"]
    )

    /// Alle Ordnernamen, die zur Auswahl stehen – die Grundmenge der Liste in
    /// den Einstellungen.
    public static var knownFolderRules: [String] {
        (unambiguousBuildFolders.union(ambiguousBuildFolders)).sorted()
    }

    /// Baut Regeln aus einer **einzigen** Liste aktiver Ordnernamen.
    ///
    /// Die Unterscheidung „eindeutig/mehrdeutig" ist damit nur noch eine
    /// **Voreinstellung**, keine zweite Sorte Regel: In der Oberfläche steht
    /// eine Liste, in der die mehrdeutigen Namen lediglich nicht vorangekreuzt
    /// sind.
    public static func with(activeFolders: Set<String>, excludedPaths: Set<String>) -> ExclusionRules {
        ExclusionRules(
            folders: activeFolders,
            filePatterns: ExclusionRules.default.filePatterns,
            excludedPaths: excludedPaths
        )
    }

    // MARK: - Prüfungen

    public func isExcludedFolder(_ name: String) -> Bool {
        folders.contains(name)
    }

    /// Ob dieser konkrete Pfad ausgeblendet wurde (samt allem darunter).
    public func isExcludedPath(_ path: String) -> Bool {
        guard !excludedPaths.isEmpty else { return false }
        let candidate = Self.normalize(path)
        if excludedPaths.contains(candidate) { return true }
        return excludedPaths.contains { candidate.hasPrefix($0 + "/") }
    }

    /// Ob ein Verzeichnis als **Dokument** zu werten ist (App-Bündel und
    /// Ähnliches). Solche Verzeichnisse werden nicht betreten, sondern als eine
    /// Einheit gezählt – sonst meldete die App deren Innereien als Arbeit.
    public static func isPackage(extension ext: String) -> Bool {
        packageExtensions.contains(ext.lowercased())
    }

    /// Prueft einen Dateinamen gegen die Ausschlussmuster (inkl. Glob wie ``~$*``).
    public func isExcludedFile(_ name: String) -> Bool {
        for pattern in filePatterns where GlobMatcher.matches(name, pattern: pattern) {
            return true
        }
        return false
    }
}
