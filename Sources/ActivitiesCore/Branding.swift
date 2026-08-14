import Foundation

/// Urheberangabe der App – **eine** Wahrheit fuer alle Stellen, die sie zeigen.
///
/// **⚠️ Warum im Kern und nicht als Zeichenkette an drei Stellen.** Genau das
/// war sie bis v1.19.67: derselbe Satz in `AboutView`, in `HelpView` und
/// nirgends geprueft. Ein Name, der an einer Stelle geaendert wird, laesst die
/// beiden anderen falsch stehen – und *falsch* heisst hier: das Programm nennt
/// zwei verschiedene Urheber, ohne dass irgendetwas rot wird. Das ist Lehre 4
/// in ihrer einfachsten Form, und die Kuerzeltabelle (UX-39) ist der Beleg,
/// dass sie hier auch fuer Prosa gilt.
public enum Branding {

    /// Der Urheber. Alles Uebrige ist daraus gebaut.
    public static let author = "walther.matthias.riedel"

    /// Lange Form fuer die Nebenfenster („Ueber", Hilfe), wo Platz ist.
    public static let credit = "designed by \(author)"

    /// Kurze Form fuer die Statuszeile des Hauptfensters.
    ///
    /// **⚠️ Kuerzer als `credit`, und das ist kein Geschmack, sondern gemessen.**
    /// Die lange Form ist bei 11 pt **186,3 pt** breit, die kurze **134,9 pt**.
    /// Die Statuszeile traegt bei der Fenster-Mindestbreite von 820 pt bereits
    /// so viel, dass der Quellpfad mittig gekuerzt werden muss
    /// (`RootView.swift`, `truncationMode(.middle)`). 51 pt sind dort der
    /// Unterschied zwischen einem lesbaren und einem angeschnittenen Pfad.
    ///
    /// *Wer den Namen aendert, misst nach:*
    /// `swift measure.swift width 11 system "by <name>"`
    public static let creditShort = "by \(author)"
}
