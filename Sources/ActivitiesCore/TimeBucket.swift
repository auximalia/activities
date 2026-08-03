import Foundation

/// Ordnet einem Datum einen Zeitabschnitt relativ zu ``now`` zu.
///
/// Gruppierung nach Kalendertagen: Heute, Gestern, Diese Woche (bis 6 Tage) und
/// darueber hinaus wochenweise (Vor 1 Woche, Vor 2 Wochen ...). Portierung von
/// ``bucket_label`` aus ``html_report.py``.
public enum TimeBucket {
    public static func label(
        for date: Date,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> String {
        let startOfDate = calendar.startOfDay(for: date)
        let startOfToday = calendar.startOfDay(for: now)
        let daysAgo = calendar.dateComponents([.day], from: startOfDate, to: startOfToday).day ?? 0

        if daysAgo <= 0 { return "Heute" }
        if daysAgo == 1 { return "Gestern" }
        if daysAgo < 7 { return "Diese Woche" }
        let weeksAgo = daysAgo / 7
        return weeksAgo == 1 ? "Vor 1 Woche" : "Vor \(weeksAgo) Wochen"
    }

    /// Fasst bereits (nach Datum absteigend) sortierte Ordnereintraege in
    /// aufeinanderfolgende Zeitabschnitte zusammen; die Reihenfolge bleibt erhalten.
    public static func group(
        _ entries: [FolderEntry],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [BucketedEntries] {
        var buckets: [BucketedEntries] = []
        for entry in entries {
            let label = label(for: entry.newestDate, now: now, calendar: calendar)
            if var last = buckets.last, last.label == label {
                last.entries.append(entry)
                buckets[buckets.count - 1] = last
            } else {
                buckets.append(BucketedEntries(label: label, entries: [entry]))
            }
        }
        return buckets
    }
}

/// Ein Zeitabschnitt mit den zugehoerigen Ordnereintraegen.
public struct BucketedEntries: Identifiable, Sendable {
    public var id: String { label }
    public let label: String
    public var entries: [FolderEntry]

    public init(label: String, entries: [FolderEntry]) {
        self.label = label
        self.entries = entries
    }
}
