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
}
