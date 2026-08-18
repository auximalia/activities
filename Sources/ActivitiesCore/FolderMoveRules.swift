import Foundation

/// Regeln für das Verschieben von **Ordnern**.
///
/// **⚠️ Warum das eine eigene Regel ist und nicht `FileManager` überlassen
/// bleibt.** `mv a a/b` ist der klassische Weg, einen Baum zu zerstören: Das
/// Ziel liegt im Quellordner, und je nach Dateisystem entsteht dabei eine
/// Schleife, ein Verlust oder ein Fehler mit unklarer Meldung. Wer sich darauf
/// verlässt, dass die Systemschicht das schon abfängt, verlässt sich auf etwas
/// Unzugesichertes — und der Schaden ist nicht rückholbar, weil es kein „Vorher"
/// mehr gibt, in das ⌘Z zurückführen könnte.
public enum FolderMoveRules {

    /// Warum ein Ordner nicht dorthin darf – ``nil`` heißt: erlaubt.
    public enum Rejection: Equatable, Sendable {
        /// Ziel und Quelle sind derselbe Ordner.
        case sameFolder
        /// Der Ordner liegt bereits dort.
        case alreadyThere
        /// Das Ziel liegt **im** Ordner selbst.
        case intoItself

        public var reason: String {
            switch self {
            case .sameFolder: "Das ist derselbe Ordner."
            case .alreadyThere: "Der Ordner liegt bereits dort."
            case .intoItself: "Ein Ordner kann nicht in sich selbst verschoben werden."
            }
        }
    }

    /// Ob `ziel` der Ordner `wurzel` selbst oder einer seiner Nachfahren ist.
    ///
    /// **⚠️ Verglichen wird auf Pfad**grenzen**, nicht als Zeichenkette.** Sonst
    /// gälte `/a/bc` als Nachfahre von `/a/b` — dieselbe Falle, die
    /// ``PathFormatting/withTilde(_:home:)`` schon einmal aufgeschrieben hat
    /// (`/Users/mtri2` ist nicht `/Users/mtri`).
    public static func isSelfOrDescendant(_ ziel: URL, of wurzel: URL) -> Bool {
        let z = normalize(ziel)
        let w = normalize(wurzel)
        if z == w { return true }
        return z.hasPrefix(w + "/")
    }

    /// Darf `ordner` nach `ziel` verschoben werden?
    public static func rejection(moving ordner: URL, into ziel: URL) -> Rejection? {
        let o = normalize(ordner)
        let z = normalize(ziel)
        if o == z { return .sameFolder }
        // ⚠️ Diese Pruefung kommt VOR `alreadyThere`: Zieht jemand `/a/b` auf
        // `/a/b/c`, ist der Elternordner von `/a/b` nicht `/a/b/c` – die
        // Reihenfolge entschiede sonst nichts, aber die Meldung waere die
        // falsche und damit unbrauchbar.
        if isSelfOrDescendant(ziel, of: ordner) { return .intoItself }
        if normalize(ordner.deletingLastPathComponent()) == z { return .alreadyThere }
        return nil
    }

    /// Vergleichsform eines Pfades: aufgelöst, ohne Schrägstrich am Ende.
    ///
    /// **⚠️ Kleinschreibung wird NICHT angewandt.** macOS-Dateisysteme sind
    /// üblicherweise ohne Unterscheidung von Groß- und Kleinschreibung, aber
    /// nicht zwingend — und ein Vergleich, der `A` und `a` gleichsetzt, würde
    /// auf einem unterscheidenden Dateisystem eine erlaubte Verschiebung
    /// ablehnen. Falsch abzulehnen ist hier billiger als falsch zu erlauben,
    /// aber unnötig falsch ist beides.
    static func normalize(_ url: URL) -> String {
        var pfad = url.standardizedFileURL.resolvingSymlinksInPath().path
        while pfad.count > 1 && pfad.hasSuffix("/") { pfad.removeLast() }
        return pfad
    }
}
