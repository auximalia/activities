import Foundation

/// Welche Dateien als **Arbeitsdateien** gelten.
///
/// Grundlage des Schalters „Nur Arbeitsdateien" unter dem Diagramm: an heisst,
/// es erscheint nur, was hier erlaubt ist; aus heisst, es aendert sich nichts.
///
/// **⚠️ Diese Liste ist absichtlich eine zweite, obwohl sie
/// ``WorkDays/resumableCategories`` heute fast gleicht.** Die andere entscheidet,
/// was ein Klick **oeffnet** – also ausfuehrt. Diese entscheidet, was man
/// **sieht**. Die Folgen sind ungleich:
///
/// - Die Ausfuehrungsliste muss **eng** bleiben. Ihr schlimmster Fall ist „es
///   ist etwas gestartet" (siehe PR-35, v1.19.27).
/// - Die Sichtbarkeitsliste darf **grosszuegig** wachsen. Ihr schlimmster Fall
///   ist „ich sehe zu viel".
///
/// Wer sie je zusammenlegt, gibt die engere auf – und merkt es nicht, weil das
/// Zusammenlegen sich wie Aufraeumen anfuehlt.
///
/// **⚠️ Deshalb wird ``FileCategory/extensionMap`` hier auch nicht erweitert.**
/// `bpmn` und `graph` gehoeren zu den Arbeitsdateien, aber sie nach `documents`
/// zu schieben haette sie zugleich fuer „Arbeit fortsetzen" oeffenbar gemacht.
/// Der Schluesselraum ist stattdessen **erweitert**: erlaubte Kategorien *plus*
/// zusaetzlich erlaubte Endungen.
public enum WorkFileFilter {
    /// Kategorien, die als Arbeitsdateien gelten.
    ///
    /// Dokumente, PDF, Tabellen und Praesentationen – Dinge, an denen man
    /// *arbeitet*. Nicht dabei: Code, Archive, Medien, Bilder und der Eimer
    /// „Sonstige", in dem auch `.app` und `.dmg` liegen.
    public static let categories: Set<FileCategory> = [
        .documents, .pdf, .spreadsheets, .presentations
    ]

    /// Endungen, die ``FileCategory`` nicht kennt und die trotzdem Arbeit sind.
    ///
    /// Modellierungs- und Diagrammdateien. Sie liegen in ``FileCategory/other``
    /// und muessen dort auch bleiben – siehe die Warnung am Typ.
    public static let extraExtensions: Set<String> = ["bpmn", "graph"]

    /// Ob eine Datei als Arbeitsdatei gilt.
    ///
    /// **Dateien ohne Endung sind keine.** `pathExtension` ist dann `""`, die
    /// Kategorie `other` – und ueber die Legende waren sie bisher ueberhaupt
    /// nicht auszublenden, weil sie dort nie als Chip erscheinen. Der Schalter
    /// erledigt das nebenbei, weil er von der anderen Seite denkt.
    public static func isWorkFile(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        if extraExtensions.contains(ext) { return true }
        return categories.contains(FileCategory.category(for: url))
    }
}
