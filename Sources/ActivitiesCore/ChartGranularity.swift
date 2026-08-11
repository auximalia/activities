import Foundation

/// Bündelung der Diagramm-Achse.
///
/// **Warum überhaupt bündeln?** Ein Balken je Tag ist nur bei kurzen Zeiträumen
/// lesbar. Bei mehreren Jahren entstünden Tausende Balken – unlesbar und teuer.
/// Bis v1.11.0 half sich die App damit, das Diagramm ab ~4000 Tagen schlicht
/// **leer** zu lassen; wer eine lange Zeitspanne wählte, sah nichts.
public enum ChartGranularity: Sendable, Equatable, CaseIterable {
    case day
    case week
    case month
    case quarter
    case year

    /// Höchstzahl der Balken, die eine Achse tragen soll.
    ///
    /// Darüber wird ein Balken schmaler als ein Pixel und die Darstellung
    /// sinnlos. **Diese Schranke ist eine Zusicherung und wird geprüft** –
    /// über eine Reihe von Spannen, nicht an einem Beispiel.
    public static let maxBars = 130

    /// Wählt die Bündelung automatisch nach der Länge des Zeitraums.
    ///
    /// **⚠️ Die Stufen Quartal und Jahr fehlten bis v1.19.43, und der
    /// Doc-Kommentar sagte trotzdem „nie mehr als rund 130 Balken".** Die
    /// Zusage brach bei **3.957 Tagen (10,8 Jahren)**: Darüber lieferte `.month`
    /// mehr als 130 Balken, ohne dass eine gröbere Stufe bereitstand. Aus der
    /// Praxis gemeldet mit **25.753 Tagen = 846 Balken** – Faktor 6,5 über der
    /// Zusage, und die Achse lief zu einem schwarzen Streifen zusammen.
    ///
    /// **⚠️ Die Prüfung, die das hätte finden müssen, prüfte ein Beispiel.**
    /// Sie setzte 2.557 Tage an und bestand deshalb – nicht, weil die Schranke
    /// gilt, sondern weil dieser eine Wert darunter liegt. *Wer eine Zusicherung
    /// an einem Beispiel festnagelt, prüft sie nicht.*
    public static func automatic(spanDays: Int) -> ChartGranularity {
        if spanDays <= 92 { return .day }         // bis ~3 Monate: Tag (≤ 92)
        if spanDays <= 730 { return .week }       // bis ~2 Jahre: Woche (≈ 105)
        if spanDays <= 3_950 { return .month }    // bis ~10,8 Jahre: Monat (≤ 130)
        if spanDays <= 11_800 { return .quarter } // bis ~32 Jahre: Quartal (≤ 130)
        return .year                              // darüber: Jahr (130 = 130 Jahre)
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
        case .quarter:
            var components = calendar.dateComponents([.year, .month], from: date)
            // Quartalsanfang: Januar, April, Juli, Oktober.
            components.month = ((components.month ?? 1) - 1) / 3 * 3 + 1
            return calendar.date(from: components) ?? calendar.startOfDay(for: date)
        case .year:
            let components = calendar.dateComponents([.year], from: date)
            return calendar.date(from: components) ?? calendar.startOfDay(for: date)
        }
    }

    /// Nächstes Bündel nach ``date``.
    public func next(after date: Date, calendar: Calendar = .current) -> Date? {
        switch self {
        case .day:   return calendar.date(byAdding: .day, value: 1, to: date)
        case .week:  return calendar.date(byAdding: .weekOfYear, value: 1, to: date)
        case .month: return calendar.date(byAdding: .month, value: 1, to: date)
        case .quarter: return calendar.date(byAdding: .month, value: 3, to: date)
        case .year: return calendar.date(byAdding: .year, value: 1, to: date)
        }
    }

    /// Höchstzahl der **Beschriftungen** an der Achse.
    ///
    /// Bewusst viel kleiner als ``maxBars``: Ein Balken darf ein Pixel breit
    /// sein, eine Beschriftung braucht Platz für Text.
    public static let maxLabels = 14

    /// Welche Balken eine Beschriftung bekommen – als **Positionen**, nicht als
    /// Kalenderregel.
    ///
    /// **⚠️ Genau hier lag der zweite Teil des Fehlers.** Die Vorgängerfassung
    /// stand in der Ansicht und fragte „ist es ein Montag?", „ist es ein
    /// Quartalsanfang?". Eine solche Regel **kann nicht wissen, wie viele
    /// Beschriftungen dabei herauskommen** – bei 846 Monatsbalken waren es 282.
    /// Wer in Kalendereinheiten rechnet, beantwortet eine andere Frage als die
    /// gestellte.
    ///
    /// Erster und letzter Balken sind immer dabei: Sie tragen die Spanne, und
    /// eine Achse ohne Anfang und Ende ist eine Skala ohne Bezug.
    public static func labelPositions(barCount: Int, maximum: Int = maxLabels) -> Set<Int> {
        guard barCount > 0 else { return [] }
        guard barCount > maximum else { return Set(0..<barCount) }
        var positionen: Set<Int> = [0, barCount - 1]
        // **⚠️ Geteilt wird durch `maximum - 1`, nicht durch `maximum`.** Der
        // letzte Balken wird oben zusaetzlich eingefuegt und liegt im Regelfall
        // **nicht** auf dem Raster; mit `maximum` als Teiler ergaeben sich
        // deshalb `maximum + 1` Marken. Die Pruefung ueber eine Reihe von
        // Balkenzahlen hat genau das gefunden – bei 400 und 846 Balken waren es
        // 15 statt 14. *Ein Beispiel haette es nicht gezeigt.*
        //
        // Die Rundung darf nie 0 ergeben, sonst entstuende eine Endlosdichte
        // statt einer Ausduennung.
        let schritt = max(1, (barCount + maximum - 2) / (maximum - 1))
        var i = 0
        while i < barCount {
            positionen.insert(i)
            i += schritt
        }
        return positionen
    }
}
