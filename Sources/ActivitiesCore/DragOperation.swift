import Foundation

/// Verschieben oder Kopieren – und welches von beidem eine Ziehbewegung meint.
public enum TransferKind: String, Sendable, Hashable, CaseIterable {
    case move
    case copy

    public var label: String {
        switch self {
        case .move: "Verschieben"
        case .copy: "Kopieren"
        }
    }

    /// Verb für die Rückfrage: „… nach X verschieben?" / „… kopieren?"
    public var verb: String {
        switch self {
        case .move: "verschieben"
        case .copy: "kopieren"
        }
    }
}

/// Welche Operation eine Ziehbewegung bedeutet.
///
/// **⚠️ Die Regel ist die des Finders, und das ist der Punkt.** Sie wurde nicht
/// gewählt, weil sie die beste denkbare wäre, sondern weil jeder sie schon
/// kennt: Wer ⌥ drückt und einen anderen Anhänger am Zeiger erwartet, hat das
/// nicht in dieser App gelernt. Eine eigene Belegung wäre hier keine
/// Verbesserung, sondern eine zweite Wahrheit neben einer, die im ganzen System
/// gilt.
///
/// | | gleiches Volume | anderes Volume |
/// |---|---|---|
/// | ohne Taste | verschieben | **kopieren** |
/// | ⌥ | kopieren | kopieren |
/// | ⌘ | verschieben | **verschieben** |
///
/// **⚠️ Über Volume-Grenzen wird ohne Taste kopiert**, nicht verschoben. Ein
/// Verschieben zwischen zwei Datenträgern ist kein Umhängen, sondern Kopieren
/// und Löschen – nicht unterbrechungsfrei, und bei einem Abbruch in der Mitte
/// liegt die Datei doppelt. Der Finder macht deshalb dasselbe.
public enum DragOperation {

    /// - Parameters:
    ///   - sameVolume: Liegen Quelle und Ziel auf demselben Datenträger?
    ///   - optionDown: ⌥ – erzwingt Kopieren.
    ///   - commandDown: ⌘ – erzwingt Verschieben.
    public static func kind(sameVolume: Bool,
                            optionDown: Bool,
                            commandDown: Bool) -> TransferKind {
        // ⚠️ ⌘ gewinnt gegen ⌥. Beide zugleich bedeutet im Finder „Alias
        // anlegen" – das kann diese App nicht, und stillschweigend zu kopieren
        // waere die schlechtere der beiden Antworten: Verschieben ist das, was
        // ⌘ allein bedeutet, und der Anhaenger am Zeiger sagt es an.
        if commandDown { return .move }
        if optionDown { return .copy }
        return sameVolume ? .move : .copy
    }

    /// Was die Ziehquelle einem Ziel überhaupt **anbietet**.
    ///
    /// Die Quelle sagt, was erlaubt ist; welches davon gilt, wählt das Ziel –
    /// und genau daraus entsteht der Anhänger am Mauszeiger. Meldet das Ziel
    /// `.copy`, zeichnet das System das grüne Plus; meldet es `.move`, zeichnet
    /// es nichts.
    ///
    /// **⚠️ Nach draußen wird nur Kopieren angeboten, und das ist keine
    /// Beschränkung aus Vorsicht.** Ein Verschieben nach draußen wäre die
    /// einzige Dateioperation dieses Programms ohne alles, was hier zu einer
    /// Dateioperation gehört: kein ⌘Z (``rememberUndo``), keine Rückfrage ab
    /// zehn Objekten, kein Nachziehen der Liste. Der Finder führt sie selbst
    /// aus, die App erfährt nichts davon – die Datei ist weg, die Zeile bleibt
    /// stehen, und zurückholen lässt sich nichts.
    ///
    /// **⚠️ Genau das war v2.1.6 ausgeliefert.** Bis v1.19.77 stand hier
    /// `context == .outsideApplication ? [.copy] : []`; der Defekt war die
    /// **zweite** Hälfte – innerhalb der App war damit gar nichts erlaubt, und
    /// ein Zug auf eine Ordnerzeile wurde abgewiesen. In v1.19.78 fiel die
    /// Fallunterscheidung ganz weg statt nur ihre falsche Hälfte, und damit kam
    /// `.move` nach draußen. Aus der Praxis gemeldet: *„das grüne +-Symbol
    /// erscheint nicht und die Datei wird verschoben statt kopiert."* Der
    /// Finder verschiebt bei erlaubtem `.move` auf demselben Datenträger von
    /// sich aus – mit ⌥ dagegen anzukommen ist ein Wettlauf, kein Bedienen.
    ///
    /// **⚠️ Die Regel steht hier und nicht in der Ansicht**, obwohl sie nur
    /// dort gebraucht wird. Sie hat sich bereits einmal unbemerkt verkehrt,
    /// weil `NSDragOperation` in der App-Schicht liegt, die ``CoreChecks`` nicht
    /// erreicht. Als ``TransferKind``-Menge ist sie prüfbar; die Ansicht
    /// übersetzt sie nur noch.
    ///
    /// - Parameter outsideApplication: Liegt das Ziel in einem **anderen**
    ///   Programm?
    public static func allowed(outsideApplication: Bool) -> Set<TransferKind> {
        outsideApplication ? [.copy] : [.copy, .move]
    }
}
