import Foundation

/// Ein **Arbeitstag** in einem Ordner: alle Dateien, die an einem Kalendertag
/// entstanden oder geaendert wurden.
public struct WorkDay: Identifiable, Sendable, Hashable {
    /// Tagesbeginn – zugleich die Identitaet des Eintrags.
    public let day: Date
    /// Die Dateien dieses Tages, in der Reihenfolge der Vorlage.
    public let files: [URL]

    public var id: Date { day }
    public var count: Int { files.count }

    public init(day: Date, files: [URL]) {
        self.day = day
        self.files = files
    }
}

/// Gruppierung der Dateien eines Ordners nach **Kalendertag** – die Grundlage
/// von „Arbeit fortsetzen" (PR-11).
public enum WorkDays {
    /// Wie viele Tage hoechstens angeboten werden.
    ///
    /// **⚠️ Eine Obergrenze ist noetig, und zwar aus zwei Gruenden.** Erstens
    /// kann ein Ordner im „Alle"-Modus Dateien aus hunderten von Tagen
    /// enthalten – ein Menue mit 200 Eintraegen ist kein Menue, sondern eine
    /// Liste, durch die man scrollt. Zweitens ist der Zweck des Befehls, *dort
    /// weiterzumachen, wo man aufgehoert hat*; was drei Monate zurueckliegt,
    /// setzt niemand „fort". Acht Eintraege decken zwei Arbeitswochen ab und
    /// passen ohne Rollpfeile ins Menue.
    public static let maxDays = 8

    /// Gruppiert Dateien nach Kalendertag, **jüngster Tag zuerst**.
    ///
    /// **⚠️ Kalendertag, nicht Diagramm-Buendel.** Das Diagramm fasst bei
    /// langen Zeitraeumen zu Wochen oder Monaten zusammen (UX-30). Fuer „an
    /// diesem Tag gearbeitet" waere das falsch: Der Tag ist eine **menschliche**
    /// Einheit, keine Darstellungsentscheidung. Sonst oeffnete derselbe Befehl
    /// je nach eingestelltem Zeitraum eine andere Dateimenge – und der Anwender
    /// haette keine Chance zu bemerken, warum.
    ///
    /// - Parameters:
    ///   - files: bereits gefilterte Dateien des Ordners (Typ, Name, Zeitraum).
    ///   - limit: hoechstens so viele Tage; `0` oder kleiner liefert nichts.
    public static func group(
        _ files: [RelevantFile],
        calendar: Calendar = .current,
        limit: Int = maxDays
    ) -> [WorkDay] {
        guard limit > 0 else { return [] }

        var order: [Date] = []
        var byDay: [Date: [URL]] = [:]
        for file in files {
            let day = calendar.startOfDay(for: file.timestamp)
            if byDay[day] == nil { order.append(day) }
            byDay[day, default: []].append(file.url)
        }

        // ⚠️ Nach dem TAG sortieren, nicht auf die Vorlage vertrauen. Die
        // Dateiliste kommt zwar meist nach Datum absteigend herein, aber sie
        // folgt der eingestellten Sortierung (Name, Typ) – und dann stuenden
        // die Tage in einer Reihenfolge, die niemand erklaeren kann.
        return order
            .sorted(by: >)
            .prefix(limit)
            .map { WorkDay(day: $0, files: byDay[$0] ?? []) }
    }

    /// Beschriftung eines Tages im Menue – „Heute (4)" · „Mi., 05.08.2025 (7)".
    ///
    /// **Warum die Anzahl vorab dasteht:** Ohne sie ist der Befehl eine
    /// Wundertuete – man erfaehrt erst nach dem Klick, ob drei oder sechzig
    /// Programme starten. Die Zahl liegt bereits vor und kostet nichts.
    public static func menuLabel(
        for workDay: WorkDay,
        calendar: Calendar = .current,
        now: Date = Date()
    ) -> String {
        let day = DateFormatting.dayLabel(workDay.day, calendar: calendar, now: now)
        return "\(day) (\(workDay.count))"
    }

    /// Beschriftung, wenn es nur **einen** Tag gibt und das Untermenue entfaellt.
    ///
    /// Ein Untermenue mit einem einzigen Eintrag ist ein Klick, der nichts
    /// entscheidet. Dann nennt der Befehl die Menge gleich selbst.
    public static func singleDayLabel(for workDay: WorkDay) -> String {
        let files = workDay.count == 1 ? "1 Datei" : "\(workDay.count) Dateien"
        return "Arbeit fortsetzen (\(files))"
    }
}
