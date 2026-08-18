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
    ///
    /// **⚠️ ``isVisible`` bekommt die ganze ``RelevantFile``, nicht nur ihre
    /// URL.** Bis v1.19.41 stand hier `(URL) -> Bool` – und damit war alles
    /// unerreichbar, was nicht im Pfad steht: Groesse, Zeitstempel, spaeter
    /// jedes weitere Feld. Die Datei liegt an der Filterzeile ohnehin
    /// vollstaendig vor; nur die URL weiterzureichen war ein Verlust ohne
    /// Gegenwert. *Der Backlog hatte daraus einen halben Sprint Aufwand fuer
    /// PR-20 geschlossen ("Aenderung der Kern-Signatur und aller Aufrufer") –
    /// tatsaechlich sind es zwei Zeilen und ein produktiver Aufrufer.*
    public static func folderEntries(
        from filesByFolder: [URL: [RelevantFile]],
        start: Date,
        end: Date,
        countOnlyInWindow: Bool = false,
        isVisible: (RelevantFile) -> Bool
    ) -> [FolderEntry] {
        var entries: [FolderEntry] = []
        for (folder, files) in filesByFolder {
            let visible = files.filter { isVisible($0) }

            let inRange = visible.filter { $0.timestamp >= start && $0.timestamp < end }
            guard let newest = inRange.map(\.timestamp).max() else { continue }
            let count = countOnlyInWindow ? inRange.count : visible.count
            entries.append(FolderEntry(folder: folder, newestDate: newest, fileCount: count))
        }
        entries.sort(by: byNewestFirst)
        return entries
    }

    /// Die Reihenfolge, in der Ordner in die Abschnitte laufen.
    ///
    /// **⚠️ Sie ist die Vorbedingung von ``TimeBucket/group(_:sort:dominantType:now:calendar:)``,
    /// und deshalb steht sie hier öffentlich statt als Closure im Rumpf.**
    /// `group` bildet die Abschnitte in der **Reihenfolge des Eingangs**: Es
    /// vergleicht jeden Eintrag nur mit dem **letzten** Abschnitt. Kommt ein
    /// heutiger Eintrag hinter einem jährigen, entsteht ein zweiter Abschnitt
    /// „Heute" — ganz unten, und die Chronologie zerbricht.
    ///
    /// *Genau das ist in v2.0.0 passiert: Ein neu angelegter Ordner wurde an die
    /// bereits sortierte Liste **angehängt**, und aus der Praxis kam „der Rahmen
    /// Heute erscheint ganz unten". Wer die Liste erweitert, sortiert danach —
    /// hiermit, nicht mit einer zweiten Fassung derselben Regel.*
    public static func byNewestFirst(_ first: FolderEntry, _ second: FolderEntry) -> Bool {
        if first.newestDate != second.newestDate {
            return first.newestDate > second.newestDate
        }
        return first.folder.path > second.folder.path
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
