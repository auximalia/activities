import Foundation

/// Gruppiert relevante Dateien zu ihren beinhaltenden Ordnern und zaehlt sie je Tag.
public enum FolderAggregator {
    /// Fasst Dateien nach ihrem direkten Elternordner zusammen.
    ///
    /// ``fileCount`` und ``newestDate`` beziehen sich auf die uebergebenen
    /// (relevanten) Dateien. Ergebnis nach ``newestDate`` absteigend; bei
    /// gleichem Datum sekundaer nach Pfad absteigend fuer stabile Ausgabe.
    public static func groupByFolder(_ files: [RelevantFile]) -> [FolderEntry] {
        var newestByFolder: [URL: Date] = [:]
        var countByFolder: [URL: Int] = [:]

        for file in files {
            countByFolder[file.folder, default: 0] += 1
            if let previous = newestByFolder[file.folder] {
                if file.timestamp > previous { newestByFolder[file.folder] = file.timestamp }
            } else {
                newestByFolder[file.folder] = file.timestamp
            }
        }

        var entries = newestByFolder.map { folder, date in
            FolderEntry(folder: folder, newestDate: date, fileCount: countByFolder[folder] ?? 0)
        }

        entries.sort { first, second in
            if first.newestDate != second.newestDate {
                return first.newestDate > second.newestDate
            }
            return first.folder.path > second.folder.path
        }
        return entries
    }

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

    /// Zaehlt bearbeitete Dateien je Kalendertag, aufgeschluesselt nach Dateityp.
    ///
    /// Der Zeitraum umfasst ``days`` Tage bis einschliesslich ``reference``; Tage
    /// ohne Dateien werden mit leerer Zaehlung aufgefuellt (lueckenloser Verlauf).
    /// Dateien ausserhalb des Fensters werden nicht gezaehlt.
    public static func countFilesPerDay(
        _ files: [RelevantFile],
        days: Int,
        reference: Date = Date(),
        calendar: Calendar = .current
    ) -> [DayCount] {
        guard days > 0 else { return [] }
        let endDay = calendar.startOfDay(for: reference)
        guard let startDay = calendar.date(byAdding: .day, value: -(days - 1), to: endDay) else {
            return []
        }

        var counts: [Date: [FileCategory: Int]] = [:]
        for file in files {
            let day = calendar.startOfDay(for: file.timestamp)
            if day >= startDay && day <= endDay {
                let category = FileCategory.category(for: file.url)
                counts[day, default: [:]][category, default: 0] += 1
            }
        }

        var result: [DayCount] = []
        for offset in 0..<days {
            guard let day = calendar.date(byAdding: .day, value: offset, to: startDay) else { continue }
            result.append(DayCount(day: day, countsByCategory: counts[day] ?? [:]))
        }
        return result
    }

    /// Zaehlt bearbeitete Dateien je Kalendertag, aufgeschluesselt nach Dateiendung.
    ///
    /// Nur Dateien mit einer Endung aus ``extensions`` werden gezaehlt. Aufbau des
    /// Zeitfensters wie bei ``countFilesPerDay``.
    public static func countFilesPerDayByExtension(
        _ files: [RelevantFile],
        days: Int,
        extensions: Set<String>,
        reference: Date = Date(),
        calendar: Calendar = .current
    ) -> [DayExtensionCount] {
        guard days > 0 else { return [] }
        let endDay = calendar.startOfDay(for: reference)
        guard let startDay = calendar.date(byAdding: .day, value: -(days - 1), to: endDay) else {
            return []
        }

        var counts: [Date: [String: Int]] = [:]
        for file in files {
            let ext = file.url.pathExtension.lowercased()
            guard extensions.contains(ext) else { continue }
            let day = calendar.startOfDay(for: file.timestamp)
            if day >= startDay && day <= endDay {
                counts[day, default: [:]][ext, default: 0] += 1
            }
        }

        var result: [DayExtensionCount] = []
        for offset in 0..<days {
            guard let day = calendar.date(byAdding: .day, value: offset, to: startDay) else { continue }
            result.append(DayExtensionCount(day: day, counts: counts[day] ?? [:]))
        }
        return result
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
