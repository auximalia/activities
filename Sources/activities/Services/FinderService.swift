import AppKit

/// Brueckendienst zum Finder: Ordner/Datei oeffnen bzw. im Finder anzeigen.
enum FinderService {
    /// Oeffnet einen Ordner in einem Finder-Fenster bzw. eine Datei mit ihrer
    /// Standard-App. ``NSWorkspace.open`` waehlt bei Dateien automatisch das
    /// zugeordnete Programm.
    static func open(_ url: URL) {
        NSWorkspace.shared.open(url)
    }

    /// Oeffnet **mehrere** Objekte.
    ///
    /// **⚠️ Warum das eine eigene Methode ist und nicht `forEach` beim
    /// Aufrufer.** Genau so stand es vorher: drei Aufrufstellen mit je einer
    /// eigenen Schleife (`ReportViewModel`, zweimal `FileRowView`). Damit war
    /// „viele auf einmal" kein Begriff, den der Code kennt, sondern ein Zufall
    /// der Aufrufer – und eine Bremse haette an keiner Stelle gewusst, dass sie
    /// Teil einer Serie ist. Erst wenn die Menge eine eigene Methode hat, kann
    /// man ueber sie eine Regel legen (siehe ``BulkAction``).
    ///
    /// Die Schleife bleibt: ``NSWorkspace`` kennt fuer „oeffne diese Objekte
    /// mit ihrem jeweiligen Standardprogramm" keinen Sammelaufruf. Der
    /// Unterschied liegt darin, **wo** sie steht.
    static func open(_ urls: [URL]) {
        urls.forEach { NSWorkspace.shared.open($0) }
    }

    /// Zeigt den Eintrag im Finder an (waehlt ihn im uebergeordneten Ordner aus).
    static func reveal(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    /// Zeigt **mehrere** Objekte im Finder an.
    ///
    /// Hier gibt es den Sammelaufruf tatsaechlich:
    /// ``activateFileViewerSelecting`` nimmt ein Array und oeffnet fuer Objekte
    /// desselben Ordners nur **ein** Fenster. Vorher wurde es je Objekt einzeln
    /// aufgerufen – bei zehn Dateien eines Ordners also zehnmal statt einmal.
    static func reveal(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        NSWorkspace.shared.activateFileViewerSelecting(urls)
    }
}
