import Foundation

/// Regeln für Ordnernamen – beim Anlegen wie beim Umbenennen.
///
/// **⚠️ Am Rand ablehnen, nicht später reparieren.** Ein Name mit `/` erzeugt
/// keinen Ordner mit Schrägstrich, sondern einen Ordner an einer anderen
/// Stelle. `.` und `..` benennen gar keinen Ordner, sondern eine Bewegung im
/// Baum. Beides schlägt in der Systemschicht mit einer Meldung fehl, die von
/// einem Tippfehler nicht zu unterscheiden ist — deshalb wird hier gefragt,
/// bevor irgendetwas geschieht.
public enum FolderNaming {

    public enum Rejection: Equatable, Sendable {
        case empty
        case containsSeparator
        case reserved
        case alreadyExists

        public var reason: String {
            switch self {
            case .empty: "Der Name darf nicht leer sein."
            case .containsSeparator: "Ein Name darf keinen Schrägstrich enthalten."
            case .reserved: "\u{201E}.\u{201C} und \u{201E}..\u{201C} sind keine Namen."
            case .alreadyExists: "Dieser Name ist hier schon vergeben."
            }
        }
    }

    /// Der Name, wie er tatsächlich angelegt würde.
    ///
    /// **⚠️ Leerzeichen am Rand fallen weg.** Ein Ordner namens `„Archiv "` ist
    /// im Finder von `„Archiv"` nicht zu unterscheiden und sortiert doch
    /// woanders — der häufigste versehentliche Doppelordner überhaupt.
    public static func sanitized(_ eingabe: String) -> String {
        eingabe.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Warum dieser Name nicht geht – ``nil`` heißt: in Ordnung.
    ///
    /// - Parameter existing: Namen, die im Zielordner bereits vergeben sind.
    public static func rejection(for eingabe: String, existing: Set<String>) -> Rejection? {
        let name = sanitized(eingabe)
        if name.isEmpty { return .empty }
        if name.contains("/") { return .containsSeparator }
        if name == "." || name == ".." { return .reserved }
        if existing.contains(name) { return .alreadyExists }
        return nil
    }

    /// **⚠️ Ein Name, der nur die Groß-/Kleinschreibung ändert, ist erlaubt** –
    /// und zugleich der Fall, an dem `FileManager.moveItem` auf einem
    /// nicht unterscheidenden Dateisystem mit „Datei existiert bereits"
    /// scheitert. Die Ausführung braucht dafür den Umweg über einen
    /// Zwischennamen; die **Regel** sagt nur, dass es erlaubt ist.
    public static func isCaseOnlyChange(from alt: String, to neu: String) -> Bool {
        let a = sanitized(alt), n = sanitized(neu)
        return a != n && a.lowercased() == n.lowercased()
    }
}
