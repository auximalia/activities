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

        let today = calendar.startOfDay(for: now)
        let day = calendar.startOfDay(for: date)
        let daysApart = calendar.dateComponents([.day], from: day, to: today).day ?? 0
        let weekday = weekdaySymbols[safe: calendar.component(.weekday, from: date)] ?? ""
        if (0...6).contains(daysApart) {
            return "\(weekday)., \(dayMonthFormatter.string(from: date)) \(time)"
        }
        return "\(dayFormatter.string(from: date)), \(time)"
    }

    static func day(_ date: Date) -> String {
        dayFormatter.string(from: date)
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
