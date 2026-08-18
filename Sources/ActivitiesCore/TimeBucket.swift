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

        // Nach oben gedeckelt: Ohne Begrenzung entstuenden bei unbegrenztem
        // Zeitraum Bezeichnungen wie "Vor 260 Wochen" statt "Vor 5 Jahren".
        let weeksAgo = daysAgo / 7
        if weeksAgo < 5 {
            return weeksAgo == 1 ? "Vor 1 Woche" : "Vor \(weeksAgo) Wochen"
        }
        let monthsAgo = daysAgo / 30
        if monthsAgo < 12 {
            return monthsAgo <= 1 ? "Vor 1 Monat" : "Vor \(monthsAgo) Monaten"
        }
        let yearsAgo = daysAgo / 365
        return yearsAgo <= 1 ? "Vor 1 Jahr" : "Vor \(yearsAgo) Jahren"
    }

    /// Fasst bereits (nach Datum absteigend) sortierte Ordnereintraege in
    /// aufeinanderfolgende Zeitabschnitte zusammen; die Reihenfolge bleibt erhalten.
    /// - Parameter sort: Reihenfolge **innerhalb** jedes Zeitabschnitts. Die
    ///   Abschnitte selbst bleiben immer chronologisch – eine globale
    ///   Namenssortierung wuerde die Zeitgliederung zerstoeren, die den Kern der
    ///   Darstellung ausmacht.
    /// - Parameter dominantType: vorherrschende Endung eines Ordners (nur fuer
    ///   ``SortField/type``).
    ///
    /// Erwartet ``entries`` nach Datum **absteigend** – nur so entstehen
    /// zusammenhaengende Abschnitte.
    /// **⚠️ Vorbedingung: ``entries`` ist nach Datum absteigend sortiert**
    /// (``FolderAggregator/byNewestFirst(_:_:)``). Diese Funktion vergleicht
    /// jeden Eintrag nur mit dem **letzten** Abschnitt — sie bildet die
    /// Abschnitte in der Reihenfolge des Eingangs und sortiert nichts um.
    ///
    /// Wird sie verletzt, geschieht **zweierlei**, und beides sieht nicht nach
    /// einem Fehler aus: Die Abschnitte stehen in der falschen Reihenfolge, und
    /// derselbe Abschnittsname kann **mehrfach** entstehen. In v2.0.0 wurde ein
    /// neu angelegter Ordner an die sortierte Liste angehängt; „Heute" erschien
    /// darauf ganz unten.
    ///
    /// *Hier wird nicht defensiv sortiert. Die Reihenfolge ist die Entscheidung
    /// des Aufrufers — er kennt das Kriterium (``FolderSort``), diese Funktion
    /// nicht. Sortierte sie selbst, gäbe es zwei Stellen, die darüber
    /// bestimmen, und eine davon läge falsch.*
    public static func group(
        _ entries: [FolderEntry],
        sort: FolderSort = .byNewest,
        dominantType: (URL) -> String? = { _ in nil },
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
        guard sort != .byNewest else { return buckets }
        return buckets.map {
            BucketedEntries(
                label: $0.label,
                entries: RowSorting.folders($0.entries, by: sort, dominantType: dominantType)
            )
        }
    }
}

/// Ein Zeitabschnitt mit den zugehoerigen Ordnereintraegen.
public struct BucketedEntries: Identifiable, Sendable {
    public var id: String { label }
    public let label: String
    public var entries: [FolderEntry]
    /// Ob dieser Abschnitt die **angehefteten** Ordner traegt.
    ///
    /// **⚠️ Ein Merkmal, kein Namensvergleich.** Der Abschnitt ist von anderer
    /// Art als die Zeitabschnitte: „Heute" ist eine *Beobachtung*, „Angeheftet"
    /// eine *Entscheidung des Anwenders*. Die Oberflaeche muss das unterscheiden
    /// koennen – aber nicht, indem sie auf die Beschriftung „Angeheftet" prueft.
    /// Ein Anzeigetext ist kein Datenmerkmal; er aendert sich mit der Sprache.
    public let isPinned: Bool

    public init(label: String, entries: [FolderEntry], isPinned: Bool = false) {
        self.label = label
        self.entries = entries
        self.isPinned = isPinned
    }
}
