import SwiftUI
import ActivitiesCore

/// Wandelt die kategoriale Palette aus ``ActivitiesCore`` in SwiftUI-Farben um.
///
/// Die Palette selbst liegt bewusst im Kern (plattformunabhaengig, dadurch in
/// ``CoreChecks`` auf Unterscheidbarkeit pruefbar); hier findet nur die
/// Umwandlung fuer die Oberflaeche statt.
///
/// **Aufgabenteilung in der Legende:** Das Datei-Icon traegt die *Identitaet*
/// eines Typs, die Palettenfarbe traegt die *Unterscheidung*. Deshalb bleibt das
/// Icon im Chip erhalten, obwohl die Farbe nicht mehr daraus abgeleitet wird.
enum FileTypeColor {
    /// Farbe des Sammel-Eintrags „Sonstige" – das einzige Grau der Datenschicht.
    static let other = color(TypePalette.neutral)

    static func color(_ paletteColor: PaletteColor) -> Color {
        Color(
            hue: paletteColor.hue,
            saturation: paletteColor.saturation,
            brightness: paletteColor.brightness
        )
    }

    /// Farbe einer Endung gemaess der aktuellen Zuordnung.
    /// Unbekannte Endungen fallen auf das Neutralgrau zurueck.
    static func color(forExtension ext: String, assignment: [String: Int]) -> Color {
        guard let index = assignment[ext.lowercased()] else { return other }
        return color(TypePalette.color(at: index))
    }
}
