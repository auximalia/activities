import Foundation

/// Regeln zum Ausschluss von Ordnern und Dateien.
///
/// Versteckte Objekte (Dotfiles, System-Attribut "versteckt") werden ohnehin
/// vom Scanner uebersprungen und muessen hier nicht gelistet werden. Enthaelt
/// die Standardlisten aus ``config/default.json`` bzw. dem Umsetzungsplan.
public struct ExclusionRules: Sendable {
    /// Ordnernamen, die nicht betreten werden.
    public let folders: Set<String>
    /// Dateinamen bzw. Glob-Muster (z. B. ``~$*``), die ignoriert werden.
    public let filePatterns: [String]

    public init(folders: Set<String>, filePatterns: [String]) {
        self.folders = folders
        self.filePatterns = filePatterns
    }

    public static let `default` = ExclusionRules(
        folders: [
            ".git", "node_modules", "__pycache__", ".venv", "venv",
            "Library", "$RECYCLE.BIN", "System Volume Information",
        ],
        filePatterns: [".DS_Store", "Thumbs.db", "desktop.ini", "~$*"]
    )

    public func isExcludedFolder(_ name: String) -> Bool {
        folders.contains(name)
    }

    /// Prueft einen Dateinamen gegen die Ausschlussmuster (inkl. Glob wie ``~$*``).
    public func isExcludedFile(_ name: String) -> Bool {
        for pattern in filePatterns where GlobMatcher.matches(name, pattern: pattern) {
            return true
        }
        return false
    }
}
