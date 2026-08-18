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

        /// Ob diese Ablehnung eine **Meldung** wert ist.
        ///
        /// **⚠️ Nicht jede Ablehnung ist ein Befund.** Wer einen Ordner auf sich
        /// selbst oder auf den Ordner zieht, in dem er ohnehin liegt, hat
        /// nichts verhindert bekommen — es war nie eine Änderung geplant. Eine
        /// Meldung sagt ihm dann etwas, das er sieht.
        ///
        /// *Aus der Praxis gemeldet, zusammen mit der fehlenden Ziehschwelle:
        /// Ein Klick zum Auf- und Zuklappen erzeugte durch Zittern eine
        /// Ziehsitzung, die auf derselben Zeile endete — und darauf ein Blatt
        /// „Das ist derselbe Ordner". Die Schwelle behebt die Ursache; dies
        /// behebt, dass der Fall überhaupt laut war.*
        ///
        /// ``intoItself`` **bleibt laut**: Dort hat der Anwender auf etwas
        /// anderes gezielt, und der Grund ist ihm nicht anzusehen.
        public var isWorthReporting: Bool { self == .intoItself }

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
    public static func isSelfOrDescendant(_ target: URL, of root: URL) -> Bool {
        let z = normalize(target)
        let w = normalize(root)
        if z == w { return true }
        return z.hasPrefix(w + "/")
    }

    /// Darf `ordner` nach `ziel` verschoben werden?
    public static func rejection(moving folder: URL, into target: URL) -> Rejection? {
        let o = normalize(folder)
        let z = normalize(target)
        if o == z { return .sameFolder }
        // ⚠️ Diese Pruefung kommt VOR `alreadyThere`: Zieht jemand `/a/b` auf
        // `/a/b/c`, ist der Elternordner von `/a/b` nicht `/a/b/c` – die
        // Reihenfolge entschiede sonst nichts, aber die Meldung waere die
        // falsche und damit unbrauchbar.
        if isSelfOrDescendant(target, of: folder) { return .intoItself }
        if normalize(folder.deletingLastPathComponent()) == z { return .alreadyThere }
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
        var path = url.standardizedFileURL.resolvingSymlinksInPath().path
        while path.count > 1 && path.hasSuffix("/") { path.removeLast() }
        return path
    }
}
