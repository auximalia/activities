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

    /// Formatiert einen Zeitstempel mit vorangestelltem Wochentagskuerzel,
    /// z. B. "Mo 03.08.2026 15:37".
    static func dateTime(_ date: Date, calendar: Calendar = .current) -> String {
        let weekday = calendar.component(.weekday, from: date)
        let symbol = weekdaySymbols[safe: weekday] ?? ""
        return "\(symbol) \(dayTimeFormatter.string(from: date))"
    }

    static func day(_ date: Date) -> String {
        dayFormatter.string(from: date)
    }

    /// Wochentagskuerzel, z. B. "Mo".
    static func weekdayShort(_ date: Date, calendar: Calendar = .current) -> String {
        let weekday = calendar.component(.weekday, from: date)
        return weekdaySymbols[safe: weekday] ?? ""
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
