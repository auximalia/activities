import AppKit

/// Brueckendienst zum Finder: Ordner/Datei oeffnen bzw. im Finder anzeigen.
enum FinderService {
    /// Oeffnet einen Ordner in einem Finder-Fenster bzw. eine Datei mit ihrer
    /// Standard-App. ``NSWorkspace.open`` waehlt bei Dateien automatisch das
    /// zugeordnete Programm.
    static func open(_ url: URL) {
        NSWorkspace.shared.open(url)
    }

    /// Zeigt den Eintrag im Finder an (waehlt ihn im uebergeordneten Ordner aus).
    static func reveal(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}
