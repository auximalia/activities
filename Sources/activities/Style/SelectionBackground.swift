import SwiftUI

/// Dezente, moderne Markierung eines aktiven Listeneintrags (Apple-Stil).
///
/// Weiche Akzent-Toenung mit abgerundeten, fortlaufenden Ecken statt greller
/// Vollflaeche. Text bleibt in normaler Farbe und damit gut lesbar.
///
/// **⚠️ Ohne Animation – entfernt in v1.19.75.** Hier stand
/// `.animation(.easeInOut(duration: 0.2), value: isActive)`. Bei **einer**
/// Zeile ist das hübsch; bei einer Bereichsauswahl mit ⇧-Klick beginnen
/// dutzende Zeilen gleichzeitig ihre **eigene** 200-ms-Animation, und jede
/// davon zieht ihren Zeilenrumpf über rund zwölf Bilder erneut durch die
/// Auswertung. Aus der Praxis gemeldet als *„bei der Auswahl von Dateien gibt
/// es eine Latenz – die stört sehr"*.
///
/// **Und es war auch ohne die Kosten die falsche Antwort:** Weder Finder noch
/// `NSTableView` blenden eine Markierung ein. Eine Auswahl ist die Antwort auf
/// einen Klick und muss **sofort** dastehen; 200 ms Weichzeichnen sind bei
/// einer Rückmeldung auf eine Eingabe keine Eleganz, sondern Verzögerung.
struct SelectionBackground: View {
    var isActive: Bool
    var cornerRadius: CGFloat = 8

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color.accentColor.opacity(isActive ? 0.12 : 0))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.accentColor.opacity(isActive ? 0.30 : 0), lineWidth: 1)
            )
    }
}
