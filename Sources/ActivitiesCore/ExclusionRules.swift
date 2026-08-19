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
        // **⚠️ `.build-x86` ist kein Sonderfall dieses Projekts, sondern der
        // Regelfall von SwiftPM.** `swift build --scratch-path` legt beliebig
        // benannte Streuordner an; `Packaging/build_app.sh` benutzt genau
        // diesen für den Intel-Teil des universellen Programms. Gemessen, als
        // versteckte Ordner erstmals gelesen wurden: **375 der 607 neu
        // erreichbaren Dateien** kamen allein von hier — der größte Einzelposten
        // und reines Bauwerk. Er steht in der `.gitignore` dieses Projekts.
        ".build-x86",
        ".pytest_cache", ".mypy_cache", ".tox", ".parcel-cache", ".turbo",
        "Library", "$RECYCLE.BIN", "System Volume Information",
        // **⚠️ Ablagen des Betriebssystems, seit v2.0.17 nötig.** Vorher hielt
        // `.skipsHiddenFiles` sie fern; seit versteckte Dateien gelesen werden,
        // müssen sie hier stehen. In keiner davon hat je ein Mensch gearbeitet.
        //
        // ⚠️ **Schlüsselspeicher wie `.ssh`, `.gnupg` und `.aws` stehen
        // ausdrücklich NICHT hier** – Festlegung des Eigentümers gegen meinen
        // Vorschlag. Mein Einwand war der weitergegebene HTML-Bericht; sein
        // Argument ist das bessere und ist die Leitlinie dieses Programms:
        // *„Die Sorgfaltspflicht liegt beim Nutzer, nicht beim Tool."* Wer dort
        // Zugangsdaten pflegt, will auch sehen, wann zuletzt.
        ".Trash", ".Spotlight-V100", ".fseventsd", ".TemporaryItems",
        ".DocumentRevisions-V100",
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
    static let packageExtensions: Set<String> = [
        "app", "bundle", "framework", "plugin", "kext", "xpc",
        "photoslibrary", "musiclibrary", "tvlibrary", "rtfd",
        "xcodeproj", "xcworkspace", "playground", "pages", "numbers", "key",
        "scptd", "download", "sparsebundle",
    ]

    public static let `default` = ExclusionRules(
        folders: unambiguousBuildFolders,
        // **⚠️ `._*` und `.localized` kamen mit v2.0.17 dazu.** Seit versteckte
        // Dateien gelesen werden, tauchen sie sonst auf: `._name` ist die
        // AppleDouble-Hälfte einer Datei auf Fremddateisystemen – sie trägt den
        // Zeitstempel ihrer Partnerdatei und stünde als **zweite** Zeile
        // daneben. `.localized` ist eine leere Marke des Finders.
        //
        // `.DS_Store` stand schon vorher hier und trägt jetzt die Hauptlast:
        // gemessen **167 von 223** versteckten Dateien im Bestand des Anwenders.
        filePatterns: [".DS_Store", "Thumbs.db", "desktop.ini", "~$*", "._*", ".localized"]
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

    func isExcludedFolder(_ name: String) -> Bool {
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
    static func isPackage(extension ext: String) -> Bool {
        packageExtensions.contains(ext.lowercased())
    }

    /// Prueft einen Dateinamen gegen die Ausschlussmuster (inkl. Glob wie ``~$*``).
    public func isExcludedFile(_ name: String) -> Bool {
        for pattern in filePatterns where GlobMatcher.matches(name, pattern: pattern) {
            return true
        }
        return false
    }

    /// Was der Suchlauf uebersprungen hat, in einem Satz – oder ``nil``, wenn
    /// nichts uebersprungen wurde.
    ///
    /// **⚠️ „davon" ist der ganze Zweck dieser Funktion.** Bis v1.19.65 stand in
    /// der Kopfzone „35 Ordner samt Inhalt uebersprungen · 2 von dir
    /// ausgeblendet", und beide Zahlen kamen aus verschiedenen Welten: Die erste
    /// zaehlte uebersprungene Ordner **einschliesslich** der eigenen, die zweite
    /// zaehlte **Regeln**. Wer das las, konnte nicht wissen, ob es 35 oder 37
    /// sind – und die Zeile hat keinen anderen Zweck als diese Auskunft. Jetzt
    /// ist die erste Zahl die Summe, die zweite eine Teilmenge davon, und das
    /// Wort „davon" sagt es.
    ///
    /// **⚠️ Es wird in EINEM Satz gerechnet, nicht in zwei Bausteinen.** Zwei
    /// Teile, mit „·" zusammengesetzt, waren genau die alte Bauweise: Jeder Teil
    /// fuer sich richtig, das Ganze mehrdeutig. Ein Verhaeltnis laesst sich nicht
    /// aus Teilen zusammensetzen, die es nicht kennen.
    public static func skippedSummary(byRule: Int, byHiddenPath: Int) -> String? {
        let total = byRule + byHiddenPath
        guard total > 0 else { return nil }
        // Nur eigene Ausblendungen: Ein „davon 2 von 2" waere Buchhaltung.
        if byRule == 0 {
            let wort = byHiddenPath == 1 ? "ausgeblendeter Ordner" : "ausgeblendete Ordner"
            return "\(byHiddenPath) von dir \(wort) samt Inhalt übersprungen"
        }
        // „samt Inhalt": Die Zahl nennt die uebersprungenen EINSTIEGE – darunter
        // liegen meist deutlich mehr Ordner (46 Einstiege ≙ 168 Ordner gemessen).
        let kopf = "\(total) Ordner samt Inhalt übersprungen"
        guard byHiddenPath > 0 else { return kopf }
        return kopf + " · davon \(byHiddenPath) von dir ausgeblendet"
    }
}
