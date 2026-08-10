import Foundation

/// Ein Zwischenspeicher, der sein Ergebnis behält, solange sich die Eingänge
/// nicht geändert haben.
///
/// **⚠️ Warum das hier liegt und nicht als drei Zeilen in der Ansicht.**
/// Gemessen (Sprint 15): Ein vollständiger Neuaufbau der Zeilenliste kostet bei
/// 500.000 Dateien rund **2,5 s** – Sichtbarkeit prüfen, je Ordner sortieren,
/// Baum abflachen. `ReportViewModel.treeRows` war eine *berechnete* Eigenschaft
/// und stand zudem **innerhalb** eines `ForEach`; dieselbe Rechnung lief also
/// bei jedem Neuzeichnen und bei jedem Tastendruck erneut.
///
/// Ein Zwischenspeicher ist die naheliegende Antwort – und die gefährlichste:
/// Ein veraltetes Ergebnis ist schlimmer als ein langsames, weil es *richtig
/// aussieht*. Deshalb liegt die Mechanik hier im Kern, wo ``CoreChecks`` sie
/// prüfen kann, statt verteilt in einer Ansicht, die keine Prüfung erreicht.
///
/// Der Vertrag ist bewusst eng: Der Aufrufer nennt bei jedem Zugriff die
/// **Fassung** seiner Eingänge. Ändert sie sich, wird neu gebaut; sonst nicht.
/// Der Speicher entscheidet nicht selbst, wann er veraltet – er kann es nicht
/// wissen.
public struct Memo<Value>: ~Copyable {
    private var storedGeneration: Int = .min
    private var stored: Value?
    /// Wie oft tatsächlich gebaut wurde – Grundlage der Prüfungen.
    public private(set) var builds = 0

    public init() {}

    /// Liefert den Wert für diese Fassung; baut ihn nur, wenn nötig.
    public mutating func value(at generation: Int, build: () -> Value) -> Value {
        if generation == storedGeneration, let stored {
            return stored
        }
        let fresh = build()
        stored = fresh
        storedGeneration = generation
        builds += 1
        return fresh
    }

    /// Verwirft das Ergebnis, ohne auf eine neue Fassung zu warten.
    ///
    /// Für den Fall, dass sich etwas geändert hat, das die Fassung **nicht**
    /// abbildet. Wer das braucht, sollte zuerst prüfen, ob der Zähler an der
    /// falschen Stelle sitzt.
    public mutating func invalidate() {
        stored = nil
        storedGeneration = .min
    }
}
