import Foundation

/// Die wählbaren Zeiträume als **eine** Aufzählung.
///
/// **⚠️ Warum das im Kern liegt.** Die Zuordnung „welcher Knopf leuchtet bei
/// welchem Modellzustand" ist eine Regel, keine Darstellung: `alle` hat Vorrang
/// vor `Spanne`, und eine Tageszahl, die nicht in der Vorgabeliste steht, ist
/// „eigene Tageszahl" und nicht etwa keine Auswahl. Bis v1.19.33 lebte diese
/// Regel privat in `MainToolbar`; sobald das Menü dieselbe Auswahl anbietet
/// (UX-36), gäbe es zwei Fassungen davon – und die zweite wäre eines Tages
/// anders. Derselbe Fehlertyp wie bei der Zeitstempel-Formatierung vor PR-32.
public enum TimePreset: String, Hashable, Sendable, CaseIterable {
    case today
    case days3
    case days7
    case days30
    case days90
    /// Eine Tageszahl, die nicht unter den Vorgaben steht (1–3650).
    case customDays
    /// Feste Spanne von–bis.
    case range
    /// Ohne Zeitfenster – alles, was der Ordner hergibt.
    case all

    /// Die Tageszahl hinter der Vorgabe; `nil`, wo keine feste dahintersteht.
    public var days: Int? {
        switch self {
        case .today:  return 1
        case .days3:  return 3
        case .days7:  return 7
        case .days30: return 30
        case .days90: return 90
        case .customDays, .range, .all: return nil
        }
    }

    /// Beschriftung im Menü – ausgeschrieben, weil dort Platz ist.
    public var menuLabel: String {
        switch self {
        case .today:      return "Heute"
        case .days3:      return "Letzte 3 Tage"
        case .days7:      return "Letzte 7 Tage"
        case .days30:     return "Letzte 30 Tage"
        case .days90:     return "Letzte 90 Tage"
        case .customDays: return "Eigene Tageszahl …"
        case .range:      return "Feste Spanne …"
        case .all:        return "Alle"
        }
    }

    /// Beschriftung in der Werkzeugleiste – knapp, weil dort keiner ist.
    public var toolbarLabel: String {
        switch self {
        case .today:      return "Heute"
        case .days3:      return "−3"
        case .days7:      return "−7"
        case .days30:     return "−30"
        case .days90:     return "−90"
        case .customDays: return "…"
        case .range:      return "Spanne"
        case .all:        return "Alle"
        }
    }

    /// Die Vorgaben mit fester Tageszahl, in Anzeigereihenfolge.
    public static let rollingPresets: [TimePreset] = [.today, .days3, .days7, .days30, .days90]

    /// Welche Vorgabe ist bei diesem Modellzustand aktiv?
    ///
    /// **⚠️ Die Reihenfolge der Abfragen ist die Regel.** `ignoreTimeWindow`
    /// hat Vorrang vor `useDateRange` – wer beides gesetzt hat, sieht „Alle".
    /// Genau so entscheidet es auch ``ReportViewModel``; stünde es hier anders
    /// herum, leuchtete im Menü ein anderer Punkt als der, der wirkt.
    public static func resolve(ignoreTimeWindow: Bool, useDateRange: Bool, days: Int) -> TimePreset {
        if ignoreTimeWindow { return .all }
        if useDateRange { return .range }
        return rollingPresets.first { $0.days == days } ?? .customDays
    }
}
