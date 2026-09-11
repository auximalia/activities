import Foundation

/// Welche Endungen die Legende einzeln zeigt – und in welcher Reihenfolge.
///
/// **⚠️ Die Legende zeigt nicht nur die häufigsten, sondern auch die
/// ausgeblendeten.** Das ist der Kern dieser Regel und war bis v2.1.6 anders.
/// Vorher galt allein „die zehn häufigsten"; wer eine seltene Endung ausblendete
/// und danach den Zeitraum oder den Office-Schalter änderte, verlor ihr
/// Plättchen – der Filter wirkte weiter, wurde in der Kopfzone auch angesagt
/// („3 Typen ausgeblendet"), aber die Ansage zeigte auf nichts Bedienbares.
/// Zurückzunehmen war er nur noch im Ganzen, mit ⌥⌘R.
///
/// Aus der Praxis gemeldet, und die Deutung sagt alles: *„jetzt ist .pptx, .txt
/// und .docx wieder ausgeblendet – das war ich nicht."* Ein unerreichbarer
/// Zustand sieht nicht aus wie ein vergessener eigener Handgriff, sondern wie
/// ein Programm, das eigenmächtig filtert. Die anderen wirkenden Filter dieses
/// Programms halten die Regel längst: Der Namensfilter bietet „Löschen" neben
/// seiner Ansage, der Rauschfilter „öffnen", der Office-Schalter ist sein
/// eigener Rückweg. **Wer filtert, sagt es – und zeigt, wie es zurückgeht.**
///
/// **⚠️ Auch mit Anzahl 0.** Wer `.swift` ausblendet und danach Office
/// einschaltet, hält einen Filter, der gerade nichts zurückhält. Ein
/// durchgestrichenes `.swift 0` sieht schräg aus; die Alternative – gar kein
/// Plättchen – ist aber genau das Loch von oben, nur an anderer Stelle. Sichtbar
/// und schräg schlägt unsichtbar.
///
/// **⚠️ Das Ergebnis ist ein Schnappschuss, keine laufende Rechnung.** Es
/// entsteht nur beim Neuberechnen der Legende, nicht bei jedem Klick auf ein
/// Plättchen (``ReportViewModel/toggleExtension(_:)`` ruft die Neuberechnung
/// bewusst nicht). Sonst verschwände ein wieder eingeblendetes Plättchen im
/// selben Moment unter dem Mauszeiger – genau das Wegspringen, gegen das die
/// Legende ``FileVisibility/hiddenExtensions`` von jeher nicht liest.
public struct LegendKeys: Equatable, Sendable {

    /// Die häufigsten Endungen, absteigend – die Legende im alten Sinn.
    public let ranked: [String]

    /// Die zusätzlich gezeigten, **weil** sie ausgeblendet sind.
    ///
    /// ⚠️ Getrennt gehalten und nicht bloß hinten angehängt: Die Farbvergabe
    /// braucht den Unterschied. ``TypePalette`` hat zehn Farben; die gezeigten
    /// Typen bekommen sie zuerst, damit ein ausgeblendetes Plättchen die Farben
    /// im Diagramm nicht verschiebt.
    public let alsoHidden: [String]

    /// Alle Schlüssel in Anzeigereihenfolge: erst die häufigsten, dann die
    /// ausgeblendeten.
    public var all: [String] { ranked + alsoHidden }

    /// Wie viele Endungen die Legende nach Häufigkeit einzeln zeigt.
    ///
    /// Der Rest fällt in das Sammel-Plättchen „Sonstige"
    /// (``FileVisibility/otherKey``).
    public static let topCount = 10

    /// - Parameters:
    ///   - counts: Anzahl je Endung im **gerade gezeigten** Material.
    ///   - hidden: Die ausgeblendeten Endungen; darf ``FileVisibility/otherKey``
    ///     enthalten – der hat sein eigenes Plättchen und bleibt hier außen vor.
    ///   - topCount: Wie viele nach Häufigkeit.
    public static func make(counts: [String: Int],
                            hidden: Set<String>,
                            topCount: Int = topCount) -> LegendKeys {
        // Häufigste zuerst; bei Gleichstand alphabetisch, damit die Reihenfolge
        // zwischen zwei Durchläufen nicht wackelt.
        func rang(_ a: String, _ b: String) -> Bool {
            let za = counts[a] ?? 0, zb = counts[b] ?? 0
            return za != zb ? za > zb : a < b
        }

        let top = Array(counts.keys.sorted(by: rang).prefix(topCount))
        // ⚠️ `otherKey` ist keine Endung, sondern der Sammelbegriff fuer alles
        // ausserhalb dieser Liste. Er haette hier kein Plaettchen, sondern waere
        // eins – siehe ``FileVisibility/otherKey``.
        let angehaengt = hidden
            .subtracting(top)
            .subtracting([FileVisibility.otherKey])
            .sorted(by: rang)

        return LegendKeys(ranked: top, alsoHidden: angehaengt)
    }
}
