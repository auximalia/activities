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
}
