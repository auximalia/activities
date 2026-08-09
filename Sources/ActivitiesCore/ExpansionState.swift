import Foundation

/// Der Aufklappzustand **je Wurzelordner**.
///
/// **⚠️ Warum ein Woerterbuch unter einem Schluessel und nicht ein Schluessel je
/// Wurzel.** Naheliegend waere `expandedFolders:/Users/x/Projekte` gewesen –
/// ein Schluessel je Ordner. Das haette funktioniert und einen stillen Mangel
/// gehabt: Jeder je geoeffnete Ordner liesse einen Eintrag in den
/// Voreinstellungen zurueck, fuer immer. Nach einem Jahr Gebrauch steht dort
/// Datenmuell zu Ordnern, die es nicht mehr gibt, und niemand kaeme je auf die
/// Idee, dort aufzuraeumen.
///
/// Mit **einem** Woerterbuch ist Aufraeumen dagegen ein Einzeiler
/// (``pruned(_:keeping:)``) – und es passiert bei jedem Speichern, ohne dass
/// jemand daran denken muss.
public enum ExpansionState {
    /// Zuordnung Wurzelpfad -> aufgeklappte Ordnerpfade.
    public typealias Map = [String: [String]]

    /// Setzt den Zustand einer Wurzel.
    ///
    /// Sortiert, damit der gespeicherte Wert bei gleichem Inhalt gleich
    /// aussieht – sonst schrieben zwei identische Zustaende verschiedene
    /// Dateien und jeder Vergleich waere Zufall.
    public static func updating(_ map: Map, folders: [String], for root: String) -> Map {
        var result = map
        result[root] = folders.sorted()
        return result
    }

    /// Wirft Wurzeln weg, die nicht mehr bekannt sind.
    ///
    /// „Bekannt" heisst: steht in „Zuletzt benutzt" oder ist der aktuelle
    /// Ordner. Damit ist die Obergrenze dieselbe wie dort – acht – und es gibt
    /// keine zweite Zahl, die jemand pflegen muesste.
    public static func pruned(_ map: Map, keeping roots: Set<String>) -> Map {
        map.filter { roots.contains($0.key) }
    }

    /// Uebernimmt den alten, **globalen** Zustand fuer den aktuellen Ordner.
    ///
    /// **⚠️ Die Zuordnung ist nicht bequem, sondern wahr.** Bis v1.19.27 gab es
    /// genau einen Schluessel fuer alle Wurzelordner. Was darin stand, stammte
    /// zwangslaeufig vom **zuletzt geoeffneten** Ordner – der beim ersten Start
    /// nach dem Update wieder der aktuelle ist. Ihn dort einzuhaengen stellt
    /// also her, was ohnehin gemeint war; ihn zu verwerfen waere ein spuerbarer
    /// Ruecksetzer ohne Gegenwert.
    ///
    /// Greift **nur**, solange fuer diese Wurzel noch nichts Neues gespeichert
    /// ist: Sonst ueberschriebe eine alte Fassung bei jedem Start den frisch
    /// gepflegten Zustand.
    public static func migrated(legacy: [String], currentRoot: String, into map: Map) -> Map {
        guard map[currentRoot] == nil, !legacy.isEmpty else { return map }
        return updating(map, folders: legacy, for: currentRoot)
    }

    /// Der gespeicherte Zustand einer Wurzel – `nil`, wenn es keinen gibt.
    ///
    /// **⚠️ `nil` und `[]` sind zwei verschiedene Dinge, und der Unterschied
    /// entscheidet ueber das Verhalten.** `nil` heisst „von diesem Ordner ist
    /// nichts bekannt" – dann klappt die App wie gewohnt alles auf. `[]` heisst
    /// „hier ist ausdruecklich nichts aufgeklappt", weil jemand *alles
    /// zugeklappt* hat. Beides gleich zu behandeln hiesse, dem Anwender bei
    /// jedem Ordnerwechsel seine Entscheidung wegzunehmen.
    public static func folders(in map: Map, for root: String) -> [String]? {
        map[root]
    }
}
