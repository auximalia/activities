import Foundation

/// Gruppiert relevante Dateien zu ihren beinhaltenden Ordnern und zaehlt sie je Tag.
public enum FolderAggregator {
    /// Bildet Ordner-Eintraege aus den Detaildateien je Ordner.
    ///
    /// Beruecksichtigt werden nur Dateien, die ``isVisible`` erfuellen (Typ-Filter).
    /// Das **Ordner-Datum** ist die juengste sichtbare Datei **im Intervall**
    /// ``[start, end)``; ein Ordner erscheint nur, wenn es eine solche Datei gibt.
    ///
    /// ``fileCount`` entspricht den **tatsaechlich gezeigten** Detailzeilen:
    /// - ``countOnlyInWindow == false``: alle sichtbaren Dateien des Ordners
    ///   (auch ausserhalb des Intervalls),
    /// - ``countOnlyInWindow == true``: nur die Dateien im Intervall.
    ///
    /// Ergebnis absteigend nach Datum (sekundaer Pfad absteigend).
    public static func folderEntries(
        from filesByFolder: [URL: [RelevantFile]],
        start: Date,
        end: Date,
        countOnlyInWindow: Bool = false,
        isVisible: (URL) -> Bool
    ) -> [FolderEntry] {
        var entries: [FolderEntry] = []
        for (folder, files) in filesByFolder {
            let visible = files.filter { isVisible($0.url) }
            let inRange = visible.filter { $0.timestamp >= start && $0.timestamp < end }
            guard let newest = inRange.map(\.timestamp).max() else { continue }
            let count = countOnlyInWindow ? inRange.count : visible.count
            entries.append(FolderEntry(folder: folder, newestDate: newest, fileCount: count))
        }
        entries.sort { first, second in
            if first.newestDate != second.newestDate {
                return first.newestDate > second.newestDate
            }
            return first.folder.path > second.folder.path
        }
        return entries
    }

    /// Zaehlt je Tag, aufgeschluesselt nach Dateityp – mit optionalem Sammel-Eintrag.
    ///
    /// Das Tagesfenster ist ``[startDay, endDay]`` (beide Tagesbeginn, inklusive).
    /// - ``individual``: Endungen, die einzeln unter ihrem Schluessel gezaehlt werden.
    /// - ``otherKey``: Sammelschluessel fuer alle uebrigen Dateien (``nil`` = ignorieren).
    /// - ``ignored``: Endungen, die komplett weggelassen werden (z. B. ausgeblendete).
    public static func countFilesPerDayByType(
        _ files: [RelevantFile],
        startDay: Date,
        endDay: Date,
        individual: Set<String>,
        otherKey: String?,
        ignored: Set<String> = [],
        granularity: ChartGranularity = .day,
        calendar: Calendar = .current
    ) -> [DayExtensionCount] {
        let start = granularity.bucketStart(for: startDay, calendar: calendar)
        let end = granularity.bucketStart(for: endDay, calendar: calendar)
        guard start <= end else { return [] }

        var counts: [Date: [String: Int]] = [:]
        for file in files {
            let ext = file.url.pathExtension.lowercased()
            if ignored.contains(ext) { continue }
            let key: String
            if individual.contains(ext) {
                key = ext
            } else if let otherKey {
                key = otherKey
            } else {
                continue
            }
            let day = granularity.bucketStart(for: file.timestamp, calendar: calendar)
            if day >= start && day <= end {
                counts[day, default: [:]][key, default: 0] += 1
            }
        }

        var result: [DayExtensionCount] = []
        var day = start
        while day <= end {
            result.append(DayExtensionCount(day: day, counts: counts[day] ?? [:]))
            guard let next = granularity.next(after: day, calendar: calendar) else { break }
            day = next
        }
        return result
    }
}

/// Anzahl bearbeiteter Dateien an einem Kalendertag, aufgeschluesselt nach Endung.
public struct DayExtensionCount: Identifiable, Sendable {
    public var id: Date { day }
    public let day: Date
    public let counts: [String: Int]

    public init(day: Date, counts: [String: Int]) {
        self.day = day
        self.counts = counts
    }

    public var total: Int { counts.values.reduce(0, +) }
}
