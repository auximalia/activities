import Foundation

/// Identitaet einer navigierbaren Zeile: Ordner oder Datei.
public enum RowID: Equatable, Hashable, Sendable {
    case folder(URL)
    case file(URL)
}

/// Reine, testbare Navigationslogik ueber die flache Zeilenliste.
public enum RowNavigation {
    /// Baut die sichtbare Reihenfolge (Ordner, gefolgt von seinen Dateien, falls
    /// aufgeklappt und geladen) in Anzeigereihenfolge.
    public static func flatten(
        buckets: [BucketedEntries],
        expanded: Set<URL>,
        filesByFolder: [URL: [RelevantFile]]
    ) -> [RowID] {
        var rows: [RowID] = []
        for bucket in buckets {
            for entry in bucket.entries {
                rows.append(.folder(entry.folder))
                if expanded.contains(entry.folder), let files = filesByFolder[entry.folder] {
                    for file in files { rows.append(.file(file.url)) }
                }
            }
        }
        return rows
    }

    /// Liefert die neue Auswahl nach Verschieben um ``delta`` (geklemmt an den Rand).
    public static func move(cursor: RowID?, in rows: [RowID], by delta: Int) -> RowID? {
        guard !rows.isEmpty else { return cursor }
        if let current = cursor, let index = rows.firstIndex(of: current) {
            let next = min(max(index + delta, 0), rows.count - 1)
            return rows[next]
        }
        return delta >= 0 ? rows.first : rows.last
    }
}
