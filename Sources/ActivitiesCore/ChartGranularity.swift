import Foundation

/// Bündelung der Diagramm-Achse.
///
/// **Warum überhaupt bündeln?** Ein Balken je Tag ist nur bei kurzen Zeiträumen
/// lesbar. Bei mehreren Jahren entstünden Tausende Balken – unlesbar und teuer.
/// Bis v1.11.0 half sich die App damit, das Diagramm ab ~4000 Tagen schlicht
/// **leer** zu lassen; wer eine lange Zeitspanne wählte, sah nichts.
public enum ChartGranularity: Sendable, Equatable {
    case day
    case week
    case month

    /// Wählt die Bündelung automatisch nach der Länge des Zeitraums.
    ///
    /// Die Grenzen sind so gesetzt, dass nie mehr als rund 130 Balken entstehen –
    /// darüber wird ein Balken schmaler als ein Pixel und die Darstellung sinnlos.
    public static func automatic(spanDays: Int) -> ChartGranularity {
        if spanDays <= 92 { return .day }        // bis ~3 Monate: Tag
        if spanDays <= 730 { return .week }      // bis ~2 Jahre: Woche (≈104 Balken)
        return .month                            // darüber: Monat
    }

    /// Beginn des Bündels, in das ``date`` fällt.
    public func bucketStart(for date: Date, calendar: Calendar = .current) -> Date {
        switch self {
        case .day:
            return calendar.startOfDay(for: date)
        case .week:
            let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
            return calendar.date(from: components) ?? calendar.startOfDay(for: date)
        case .month:
            let components = calendar.dateComponents([.year, .month], from: date)
            return calendar.date(from: components) ?? calendar.startOfDay(for: date)
        }
    }

    /// Nächstes Bündel nach ``date``.
    public func next(after date: Date, calendar: Calendar = .current) -> Date? {
        switch self {
        case .day:   return calendar.date(byAdding: .day, value: 1, to: date)
        case .week:  return calendar.date(byAdding: .weekOfYear, value: 1, to: date)
        case .month: return calendar.date(byAdding: .month, value: 1, to: date)
        }
    }
}
