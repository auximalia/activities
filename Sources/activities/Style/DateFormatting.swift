import Foundation

/// Zentrale Datumsformatierung fuer die Oberflaeche.
enum DateFormatting {
    /// Deutsche Wochentagskuerzel (Mo=1 ... So=7 gemaess Calendar-Standard? -> eigene Zuordnung).
    private static let weekdaySymbols = ["", "So", "Mo", "Di", "Mi", "Do", "Fr", "Sa"]

    private static let dayTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateFormat = "dd.MM.yyyy HH:mm"
        return formatter
    }()

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateFormat = "dd.MM.yyyy"
        return formatter
    }()

    private static let dayMonthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateFormat = "dd.MM."
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    /// Zeitstempel **relativ zum heutigen Tag**, wie in Finder und Mail:
    /// „Heute, 22:59" · „Gestern, 14:32" · „Mi., 05.08., 14:32" · „05.08.2025, 14:32".
    ///
    /// Das volle Datum an jeder Zeile zu wiederholen ist Rauschen – erst recht
    /// unter einer Ueberschrift, die bereits „Heute" sagt. Kuerzere Angaben
    /// sparen zugleich Breite fuer den Dateinamen.
    static func dateTime(_ date: Date, calendar: Calendar = .current, now: Date = Date()) -> String {
        let time = timeFormatter.string(from: date)
        if calendar.isDateInToday(date) { return "Heute, \(time)" }
        if calendar.isDateInYesterday(date) { return "Gestern, \(time)" }

        // Wochentag **immer** voranstellen (ausser Heute/Gestern): Ein blosses
        // Datum in der Vergangenheit sagt nichts darueber, ob es ein Arbeitstag
        // oder ein Wochenende war.
        let weekday = weekdaySymbols[safe: calendar.component(.weekday, from: date)] ?? ""
        let sameYear = calendar.component(.year, from: date) == calendar.component(.year, from: now)
        let datePart = sameYear
            ? dayMonthFormatter.string(from: date)
            : dayFormatter.string(from: date)
        return "\(weekday)., \(datePart) \(time)"
    }

    /// Kurzfassung fuer das Kompakt-Layout: ohne Wochentag, Jahr nur bei
    /// aelteren Eintraegen – „Heute, 14:45" · „03.08. 22:38" · „03.08.25 09:12".
    ///
    /// Das lange Format bricht in der schmalen Datumsspalte auf zwei Zeilen um
    /// und macht die Zeile hoch.
    static func dateTimeCompact(_ date: Date, calendar: Calendar = .current, now: Date = Date()) -> String {
        let time = timeFormatter.string(from: date)
        if calendar.isDateInToday(date) { return "Heute, \(time)" }
        if calendar.isDateInYesterday(date) { return "Gestern, \(time)" }
        let weekday = weekdaySymbols[safe: calendar.component(.weekday, from: date)] ?? ""
        let sameYear = calendar.component(.year, from: date) == calendar.component(.year, from: now)
        return sameYear
            ? "\(weekday). \(dayMonthFormatter.string(from: date)) \(time)"
            : "\(weekday). \(shortYearFormatter.string(from: date)) \(time)"
    }

    private static let shortYearFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateFormat = "dd.MM.yy"
        return formatter
    }()

    static func day(_ date: Date) -> String {
        dayFormatter.string(from: date)
    }

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.unitsStyle = .full
        return formatter
    }()

    /// Abstand zu ``now`` in Worten, z. B. „vor 13 Stunden".
    ///
    /// Ergaenzt ``dateTime`` dort, wo nicht der Zeitpunkt zaehlt, sondern das
    /// **Alter**: „Gestern, 23:09" beantwortet die Frage „ist das noch aktuell?"
    /// deutlich schlechter als „vor 13 Stunden".
    static func relative(_ date: Date, now: Date = Date()) -> String {
        relativeFormatter.localizedString(for: date, relativeTo: now)
    }

    /// Wochentagskuerzel, z. B. "Mo".
    static func weekdayShort(_ date: Date, calendar: Calendar = .current) -> String {
        let weekday = calendar.component(.weekday, from: date)
        return weekdaySymbols[safe: weekday] ?? ""
    }

    /// Wochentag + volles Datum, z. B. "Fr., 12.06.2026".
    static func weekdayDate(_ date: Date, calendar: Calendar = .current) -> String {
        "\(weekdayShort(date, calendar: calendar))., \(day(date))"
    }

    private static let monthYearFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateFormat = "LLLL yyyy"
        return formatter
    }()

    private static let monthShortFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateFormat = "LLL yy"
        return formatter
    }()

    /// Kurzer Monat mit Jahr, z. B. "Aug 26".
    static func monthShort(_ date: Date) -> String {
        monthShortFormatter.string(from: date)
    }

    /// Monat und Jahr, z. B. "August 2026".
    static func monthYear(_ date: Date) -> String {
        monthYearFormatter.string(from: date)
    }

    /// Kurzes Datum ohne Jahr, z. B. "06.07.".
    static func dayMonth(_ date: Date) -> String {
        dayMonthFormatter.string(from: date)
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
