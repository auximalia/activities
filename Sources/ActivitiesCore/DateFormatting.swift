import Foundation

/// Zentrale Datumsformatierung fuer die Oberflaeche.
///
/// **Warum in ActivitiesCore und nicht bei den Views?** Die Regeln hier sind
/// reine Funktionen ueber Datum und Kalender – ohne SwiftUI, ohne Zustand.
/// Solange sie im App-Ziel lagen, waren sie nicht pruefbar, und genau das ist
/// ihnen zum Verhaengnis geworden: Die Formatierung war ueber die Zeit in
/// mehrere Varianten zerfallen, ohne dass etwas Alarm geschlagen haette.
public enum DateFormatting {
    /// Deutsche Wochentagskuerzel (Mo=1 ... So=7 gemaess Calendar-Standard? -> eigene Zuordnung).
    private static let weekdaySymbols = ["", "So", "Mo", "Di", "Mi", "Do", "Fr", "Sa"]

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
    /// „Heute, 22:59" · „Gestern, 14:32" · „Mi., 05.08.2025 14:32".
    ///
    /// **⚠️ Genau zwei Formen, keine dritte.** „Heute"/„Gestern" bleiben als
    /// Ausnahme, weil sie eine andere Frage beantworten (ist das noch frisch?)
    /// und weil jeder sie ohne Rechnen versteht. Alles Aeltere bekommt **immer**
    /// dieselbe Form – **mit Jahr, auch im laufenden Jahr**.
    ///
    /// Vorher wurde das Jahr im laufenden Jahr weggelassen, um Rauschen zu
    /// sparen. Das kostete mehr, als es einbrachte: Sobald eine Liste ueber den
    /// Jahreswechsel reicht – und das ist der Normalfall, die Zeitabschnitte
    /// gehen bis „Vor N Jahren" –, stehen „Mi., 05.08. 14:32" und
    /// „Do., 12.12.2024 09:10" untereinander. Die Spalte franst aus, und der
    /// Leser muss an jeder Zeile erst pruefen, *welche* der beiden Formen er
    /// gerade vor sich hat. Eine gleich lange Angabe laesst sich senkrecht
    /// ueberfliegen; das ist mehr wert als die vier gesparten Zeichen.
    ///
    /// Wochentag **immer** voranstellen (ausser Heute/Gestern): Ein blosses
    /// Datum in der Vergangenheit sagt nichts darueber, ob es ein Arbeitstag
    /// oder ein Wochenende war.
    ///
    /// ``now`` ist einspeisbar (und wird tatsaechlich benutzt, statt
    /// `isDateInToday`), damit die Regel ohne Abhaengigkeit von der Systemuhr
    /// pruefbar bleibt – wie bei ``TimeBucket/label(for:now:calendar:)``.
    public static func dateTime(_ date: Date, calendar: Calendar = .current, now: Date = Date()) -> String {
        let time = timeFormatter.string(from: date)
        if let relative = relativeDayLabel(date, calendar: calendar, now: now) {
            return "\(relative), \(time)"
        }
        let weekday = weekdaySymbols[safe: calendar.component(.weekday, from: date)] ?? ""
        return "\(weekday)., \(dayFormatter.string(from: date)) \(time)"
    }

    /// Kurzfassung fuer das Kompakt-Layout – „Heute, 14:45" · „Mi. 03.08.25 09:12".
    ///
    /// Das lange Format bricht in der schmalen Datumsspalte auf zwei Zeilen um
    /// und macht die Zeile hoch. Gespart wird deshalb am **Trennkomma und an
    /// den Jahrhundertziffern**, nicht am Jahr selbst: Sonst haette das
    /// Kompakt-Layout wieder zwei Formen, und die Vereinheitlichung waere nur
    /// bei breitem Fenster wirksam.
    public static func dateTimeCompact(_ date: Date, calendar: Calendar = .current, now: Date = Date()) -> String {
        let time = timeFormatter.string(from: date)
        if let relative = relativeDayLabel(date, calendar: calendar, now: now) {
            return "\(relative), \(time)"
        }
        let weekday = weekdaySymbols[safe: calendar.component(.weekday, from: date)] ?? ""
        return "\(weekday). \(shortYearFormatter.string(from: date)) \(time)"
    }

    /// „Heute" bzw. „Gestern" – oder `nil`, wenn der Tag weiter zurueckliegt.
    ///
    /// Die einzige Stelle, an der die beiden Ausnahmen entschieden werden:
    /// Lang- und Kurzform sollen sich hier nie unterscheiden koennen.
    private static func relativeDayLabel(_ date: Date, calendar: Calendar, now: Date) -> String? {
        if calendar.isDate(date, inSameDayAs: now) { return "Heute" }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
           calendar.isDate(date, inSameDayAs: yesterday) {
            return "Gestern"
        }
        return nil
    }

    /// Ein **Tag** ohne Uhrzeit – „Heute" · „Gestern" · „Mi., 05.08.2025".
    ///
    /// Dieselben zwei Formen wie bei ``dateTime(_:calendar:now:)``, nur ohne
    /// Zeitanteil: Wo ein ganzer Kalendertag gemeint ist (PR-11), waere eine
    /// Uhrzeit eine falsche Genauigkeit.
    public static func dayLabel(_ date: Date, calendar: Calendar = .current, now: Date = Date()) -> String {
        if let relative = relativeDayLabel(date, calendar: calendar, now: now) { return relative }
        return weekdayDate(date, calendar: calendar)
    }

    private static let shortYearFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateFormat = "dd.MM.yy"
        return formatter
    }()

    public static func day(_ date: Date) -> String {
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
    public static func relative(_ date: Date, now: Date = Date()) -> String {
        relativeFormatter.localizedString(for: date, relativeTo: now)
    }

    /// Wochentagskuerzel, z. B. "Mo".
    public static func weekdayShort(_ date: Date, calendar: Calendar = .current) -> String {
        let weekday = calendar.component(.weekday, from: date)
        return weekdaySymbols[safe: weekday] ?? ""
    }

    /// Wochentag + volles Datum, z. B. "Fr., 12.06.2026".
    public static func weekdayDate(_ date: Date, calendar: Calendar = .current) -> String {
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
    public static func monthShort(_ date: Date) -> String {
        monthShortFormatter.string(from: date)
    }

    /// Monat und Jahr, z. B. "August 2026".
    public static func monthYear(_ date: Date) -> String {
        monthYearFormatter.string(from: date)
    }

    /// Kurzes Datum ohne Jahr, z. B. "06.07.".
    public static func dayMonth(_ date: Date) -> String {
        dayMonthFormatter.string(from: date)
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
