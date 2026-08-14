import Foundation

/// Welche Aussage die Statuszeile über den **Stand der Daten** trägt.
///
/// **⚠️ Warum diese Regel im Kern liegt und nicht in der `View`.** Ihr Fehler
/// ist die unsichtbarste Art, die es gibt: Eine Warnung, die nicht mehr
/// erscheint, meldet sich nicht. Wäre die Bedingung eine `if`-Zeile in einem
/// `TimelineView`, könnte sie jahrelang falsch sein, ohne dass jemand es
/// bemerkt – denn niemand vermisst etwas, das er nie gesehen hat. Genau so ist
/// die Zeitstempel-Formatierung vor PR-32 auseinandergelaufen (Lehre 4).
///
/// **⚠️ Bis v1.19.69 war „veraltet" überwiegend falsch, und das ist der Anlass
/// dieses Typs.** Die Bedingung lautete allein *letzte Plattenlesung älter als
/// eine Stunde*. `lastScanAt` rückt aber nur bei einem echten Suchlauf vor, und
/// der `FolderWatcher` löst **ausschließlich bei einer Dateisystem-Änderung**
/// aus – es gibt nirgends einen Takt, der ohne Anlass nachliest. Ändert sich
/// also eine Stunde lang nichts, meldete die App „veraltet", obwohl die Anzeige
/// stimmte. Sie tat es, während zwei Zentimeter weiter rechts „Auto" stand:
/// *das Programm behauptete gleichzeitig, es beobachte die Ordner, und es wisse
/// nicht, was darin steht.* Aus der Praxis gemeldet, mit Bild.
///
/// **⚠️ Deshalb sind es zwei Aussagen und nicht eine Schwelle.** Bei aktivem
/// Beobachter ist „aktuell" keine Vermutung über das Alter, sondern eine
/// Zusicherung des Systems – die Zeile sagt, **dass** beobachtet wird, und
/// altert nicht. Ohne Beobachter gibt es niemanden, der es merken würde, und
/// dann ist das Alter die einzige Auskunft, die es gibt.
///
/// *Das Restrisiko ist benannt und abgesichert: Stirbt der FSEvent-Strom im
/// Ruhezustand, warnte niemand mehr. Der Beobachter wird deshalb beim Aufwachen
/// erneuert (`ReportViewModel.updateWatcher`, `NSWorkspace.didWakeNotification`).*
public enum ScanFreshness: Equatable, Sendable {

    /// Noch nie von der Platte gelesen.
    case never

    /// Ein Beobachter läuft – Änderungen kämen von selbst an.
    case watched

    /// Kein Beobachter, Lesung noch frisch.
    case idle

    /// Kein Beobachter, und die Lesung ist zu alt, um ihr zu glauben.
    case stale

    /// Ab wann eine unbeobachtete Lesung nicht mehr glaubwürdig ist.
    ///
    /// **⚠️ Eine Stunde, unverändert seit der ersten Fassung** – geändert hat
    /// sich nur, *wann* die Frist überhaupt gilt. Wer sie anfasst, ändert damit
    /// nicht mehr, wie oft die Warnung erscheint (das entscheidet der
    /// Beobachter), sondern nur noch, wie geduldig die App ohne ihn ist.
    public static let stalenessLimit: TimeInterval = 3600

    /// Die Aussage der Zeile.
    ///
    /// - Parameters:
    ///   - lastScanAt: Zeitpunkt der letzten Plattenlesung, ``nil`` = noch keine.
    ///   - isWatching: Läuft ein Beobachter über den aktiven Quellen?
    ///   - now: Bezugszeitpunkt (in der App die Uhr des `TimelineView`).
    public static func state(lastScanAt: Date?,
                             isWatching: Bool,
                             now: Date,
                             limit: TimeInterval = stalenessLimit) -> ScanFreshness {
        guard let lastScanAt else { return .never }
        // ⚠️ Die Beobachtung wird VOR dem Alter geprueft. Andersherum waere die
        // Reihenfolge egal gewesen, solange sie stimmt - und genau das war der
        // Fehler: Das Alter stand allein da und wusste vom Beobachter nichts.
        if isWatching { return .watched }
        return now.timeIntervalSince(lastScanAt) >= limit ? .stale : .idle
    }

    /// Ob die Zeile warnt – Farbe, Fettdruck und der Reparaturweg hängen daran.
    public var isWarning: Bool { self == .stale }

    /// Ob ein Weg zurück angeboten werden muss.
    ///
    /// **⚠️ Deckungsgleich mit ``isWarning``, und das ist die eigentliche
    /// Zusicherung.** Eine Meldung, die ein Problem benennt und die Reparatur
    /// verschweigt, ist der Defekt, den dieses Haus zweimal aufgeschrieben hat
    /// (UX-57, PR-58). Bis v1.19.69 stand der Ausweg hier **nur im Tooltip** –
    /// und ein Tooltip existiert für Vorleseprogramme nicht.
    public var offersRescan: Bool { isWarning }

    /// Der Zusatz hinter dem Zeitstempel – ``nil`` heißt: kein Zusatz.
    ///
    /// **⚠️ Die Aussage steht im Wort, nicht nur in der Farbe** (UX-34). Ein
    /// Zustand, den allein ein Farbton trägt, existiert für Farbfehlsichtige und
    /// für Vorleseprogramme nicht.
    public var suffix: String? {
        switch self {
        case .never, .idle: nil
        case .watched: "wird überwacht"
        case .stale: "veraltet"
        }
    }
}
