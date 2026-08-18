import Foundation

/// Ob ein **leerer** Ordner unter den aktuellen Filtern in der Liste stehen darf.
///
/// **⚠️ Der Kern des Problems: Die Filter prüfen Dateien, nicht Ordner.** Ein
/// Ordner erscheint in dieser Liste, weil eine seiner Dateien durchkommt. Ein
/// Ordner **ohne** Dateien hat nichts, was durchkommen könnte — er kann einen
/// aktiven Filter also nicht erfüllen, sondern nur an ihm vorbeigeschmuggelt
/// werden.
///
/// **⚠️ Genau das tat v2.0.0.** Ein selbst angelegter Ordner wurde in die Liste
/// gehängt, ohne dass irgendetwas geprüft wurde — bei aktivem Namensfilter
/// „Erinnerung" stand dann `Neuer Ordner` mitten in den Treffern. Entscheidung
/// des Eigentümers vom 2026-08-16: **„Filter schlägt neuen Ordner."** Er wird
/// angelegt, aber nicht gezeigt — und der Anwender erfährt vorher, dass er
/// verschwindet.
///
/// *Das ist dieselbe Leitlinie wie überall hier: Die App hindert nicht am
/// Anlegen, sie sagt, was geschehen wird.*
public enum EmptyFolderVisibility {

    /// Warum ein leerer Ordner nicht erscheint – ``nil`` heißt: er erscheint.
    public enum HiddenReason: Equatable, Sendable {
        /// Ein Namensfilter ist aktiv; ein Ordner ohne Dateien hat keinen Treffer.
        case nameFilter(String)
        /// Office-Filter oder ausgeblendete Endungen sind aktiv.
        case typeFilter
        /// Der gewählte Zeitraum reicht nicht bis heute.
        case outsideWindow

        /// Der Satz, den der Anwender liest.
        ///
        /// **⚠️ Er nennt die Ursache, nicht die Regel.** „Der Ordner erfüllt das
        /// Filterkriterium nicht" wäre wahr und unbrauchbar; wer den Filter
        /// gerade selbst gesetzt hat, will wissen **welcher** ihn wegnimmt.
        public var text: String {
            switch self {
            case .nameFilter(let muster):
                "Der Ordner wird angelegt, erscheint aber nicht in der Liste: Der Namensfilter "
                + "\u{201E}\(muster)\u{201C} ist aktiv, und ein leerer Ordner hat keinen Treffer."
            case .typeFilter:
                "Der Ordner wird angelegt, erscheint aber nicht in der Liste: Ein Typ-Filter ist "
                + "aktiv, und ein leerer Ordner hat keine Datei, die durchkäme."
            case .outsideWindow:
                "Der Ordner wird angelegt, erscheint aber nicht in der Liste: Der gewählte "
                + "Zeitraum reicht nicht bis heute."
            }
        }
    }

    /// - Parameters:
    ///   - namePattern: das angewandte Suchmuster, leer = keiner.
    ///   - hasTypeFilter: Office-Filter oder ausgeblendete Endungen aktiv?
    ///   - nowInWindow: Liegt **heute** im gewählten Zeitfenster?
    ///
    /// **⚠️ Die Reihenfolge der Prüfungen ist festgelegt, nicht beliebig.**
    /// Treffen mehrere zu, wird der genannt, den der Anwender **zuletzt selbst
    /// gesetzt** hat — und das ist in der Praxis der Namensfilter, danach der
    /// Typ-Filter. Der Zeitraum steht zuletzt, weil er selten der Grund ist und
    /// am ehesten als gegeben hingenommen wird.
    public static func hiddenReason(namePattern: String,
                                    hasTypeFilter: Bool,
                                    nowInWindow: Bool) -> HiddenReason? {
        let muster = namePattern.trimmingCharacters(in: .whitespacesAndNewlines)
        if !muster.isEmpty { return .nameFilter(muster) }
        if hasTypeFilter { return .typeFilter }
        if !nowInWindow { return .outsideWindow }
        return nil
    }
}
