import Foundation

/// Sortierkriterium für Ordner- und Dateizeilen.
public enum SortField: String, Sendable, CaseIterable {
    /// Nach Zeitstempel.
    case date
    /// Nach Namen (Groß-/Kleinschreibung egal, natürliche Zahlenfolge).
    case name
    /// Nach Dateityp. Bei **Ordnern** ist das die *vorherrschende* Endung –
    /// ein Ordner hat selbst keinen Typ.
    case type
    /// Nach Dateigroesse.
    ///
    /// **⚠️ Ordnet ausschliesslich Dateien** – innerhalb ihres Ordners. Ordner
    /// behalten ihre Reihenfolge nach Datum.
    ///
    /// Das ist eine bewusste Einschraenkung, keine Luecke: Ein Ordner hat in
    /// dieser App keine Groesse. Die naheliegende Summe waere die der
    /// *sichtbaren* Dateien – bei „Letzte 7 Tage" also ein Bruchteil dessen,
    /// was jeder neben einem Ordnernamen lesen wuerde. Ordner nach einer Zahl
    /// zu sortieren, die man nicht sieht und die etwas anderes bedeutet, als
    /// sie verspricht, waere die schlechteste der drei Moeglichkeiten:
    /// „Warum steht der Ordner oben?" bliebe unbeantwortbar.
    case size

    public var label: String {
        switch self {
        case .date: "Datum"
        case .name: "Name"
        case .type: "Typ"
        case .size: "Größe"
        }
    }

    /// Ob dieses Kriterium **Ordnerzeilen** ordnet.
    public var sortsFolders: Bool { self != .size }

    /// Beschriftung im Menue – mit dem Zusatz, wo einer noetig ist.
    ///
    /// **⚠️ Die Einschraenkung gehoert an den Ort der Entscheidung**, nicht in
    /// einen Hilfetext. Wer erst nach dem Klick merkt, dass sich die Ordner
    /// nicht bewegt haben, haelt es fuer einen Fehler.
    public var menuLabel: String {
        sortsFolders ? label : "\(label) (nur Dateien)"
    }
}

/// Sortiervorgabe: Kriterium plus Richtung.
public struct FolderSort: Sendable, Equatable {
    public var field: SortField
    public var ascending: Bool

    public init(field: SortField = .date, ascending: Bool = false) {
        self.field = field
        self.ascending = ascending
    }

    /// Vorgabe der App: neueste zuerst.
    public static let byNewest = FolderSort(field: .date, ascending: false)

    /// Die Richtung in Worten – „aufsteigend" · „absteigend".
    public var directionLabel: String { ascending ? "aufsteigend" : "absteigend" }

    /// Die wirkende Sortierung in Worten – „Datum, absteigend".
    ///
    /// **⚠️ Der Satz gehoert in den Kern, obwohl ihn nur die Oberflaeche zeigt.**
    /// Er wurde bis v2.0.18 an **drei** Stellen aus denselben zwei Feldern neu
    /// zusammengesetzt – im Kurzhinweis der Werkzeugleiste, in ihrem
    /// Bedienhilfen-Wert und (fehlend) im Menue. Drei Gelegenheiten, sich zu
    /// widersprechen, fuer eine Aussage. Derselbe Grundsatz wie bei
    /// ``FileVisibility/typeFilterSummary``: *Wer filtert oder ordnet, sagt es –
    /// und sagt es ueberall gleich.*
    ///
    /// Der Wortlaut ist bewusst **nicht** „Datum ↓". Ein Pfeil ist bei Datumsangaben
    /// mehrdeutig – niemand kann sagen, ob „↓" neueste oder aelteste zuerst meint.
    public var summary: String { "\(field.label), \(directionLabel)" }
}

/// Sortierung von Ordner- und Dateizeilen.
///
/// Bewusst im Kern und **rein** (keine Zustände, keine Oberfläche), damit die
/// Reihenfolge in ``CoreChecks`` nachprüfbar bleibt.
///
/// **Wichtig:** Sortiert wird immer **innerhalb der Zeitabschnitte**, nie über
/// sie hinweg. Die Gruppierung nach „Heute", „Diese Woche" … ist der Kern der
/// Darstellung; eine globale Namenssortierung würde sie zerstören.
public enum RowSorting {
    /// Sortiert Ordner-Einträge.
    ///
    /// - Parameter dominantType: liefert die vorherrschende Endung eines Ordners
    ///   (nur für ``SortField/type`` nötig). Ordner ohne Typ landen am Ende.
    public static func folders(
        _ entries: [FolderEntry],
        by sort: FolderSort,
        dominantType: (URL) -> String? = { _ in nil }
    ) -> [FolderEntry] {
        entries.sorted { first, second in
            switch sort.field {
            case .date:
                if first.newestDate != second.newestDate {
                    return sort.ascending
                        ? first.newestDate < second.newestDate
                        : first.newestDate > second.newestDate
                }
            case .name:
                let a = first.folder.lastPathComponent
                let b = second.folder.lastPathComponent
                let order = a.localizedStandardCompare(b)
                if order != .orderedSame {
                    return sort.ascending ? order == .orderedAscending : order == .orderedDescending
                }
            case .type:
                // Ordner ohne erkennbaren Typ ans Ende, unabhaengig von der Richtung.
                let a = dominantType(first.folder)
                let b = dominantType(second.folder)
                if a != b {
                    guard let a else { return false }
                    guard let b else { return true }
                    return sort.ascending ? a < b : a > b
                }
            case .size:
                // Ordner haben keine Groesse – siehe ``SortField/size``. Es
                // bleibt bei der Reihenfolge, die unten als Gleichstandsregel
                // ohnehin gilt: juengste zuerst.
                break
            }
            // Gleichstand: stets neueste zuerst, danach der Pfad – so bleibt die
            // Reihenfolge bei gleichen Schluesseln stabil und nachvollziehbar.
            if first.newestDate != second.newestDate {
                return first.newestDate > second.newestDate
            }
            return first.folder.path > second.folder.path
        }
    }

    /// Sortiert **Geschwister** im Ordnerbaum.
    ///
    /// Bewusst eine eigene Fassung neben ``folders(_:by:dominantType:)`` – sie
    /// unterscheidet sich in genau einem, aber entscheidenden Punkt:
    ///
    /// **⚠️ Der Datumsschluessel ist ``FolderNode/subtreeNewestDate``, nicht das
    /// eigene Datum.** Ein Ordner mit alten eigenen Dateien, dessen Kind heute
    /// bearbeitet wurde, gehoert nach oben – sonst sortierte sich das Elternteil
    /// unter Geschwister, die aelter sind als sein eigener Inhalt, und der
    /// Anwender fände das Neueste ganz unten. Durchgangsknoten haben ueberhaupt
    /// kein eigenes Datum; für sie ist der Teilbaum die einzige Auskunft.
    ///
    /// Die Tie-Break-Regel ist absichtlich dieselbe wie in der flachen Liste
    /// (juengste zuerst, dann Pfad), damit beide Ansichten bei Gleichstand
    /// dieselbe Reihenfolge zeigen.
    public static func nodes(
        _ nodes: [FolderNode],
        by sort: FolderSort,
        dominantType: (URL) -> String? = { _ in nil }
    ) -> [FolderNode] {
        nodes.sorted { first, second in
            switch sort.field {
            case .date:
                if first.subtreeNewestDate != second.subtreeNewestDate {
                    return sort.ascending
                        ? first.subtreeNewestDate < second.subtreeNewestDate
                        : first.subtreeNewestDate > second.subtreeNewestDate
                }
            case .name:
                // Die **Beschriftung**, nicht der Ordnername: Bei verdichteten
                // Ketten steht dort `ChatGPT/pdf_cleanup` – danach sucht das
                // Auge, also danach wird sortiert.
                let order = first.label.localizedStandardCompare(second.label)
                if order != .orderedSame {
                    return sort.ascending ? order == .orderedAscending : order == .orderedDescending
                }
            case .type:
                let a = dominantType(first.folder)
                let b = dominantType(second.folder)
                if a != b {
                    guard let a else { return false }
                    guard let b else { return true }
                    return sort.ascending ? a < b : a > b
                }
            case .size:
                break
            }
            if first.subtreeNewestDate != second.subtreeNewestDate {
                return first.subtreeNewestDate > second.subtreeNewestDate
            }
            return first.folder.path > second.folder.path
        }
    }

    /// Sortiert die Dateien innerhalb eines Ordners.
    public static func files(_ files: [RelevantFile], by sort: FolderSort) -> [RelevantFile] {
        files.sorted { first, second in
            switch sort.field {
            case .date:
                if first.timestamp != second.timestamp {
                    return sort.ascending
                        ? first.timestamp < second.timestamp
                        : first.timestamp > second.timestamp
                }
            case .name:
                let order = first.url.lastPathComponent
                    .localizedStandardCompare(second.url.lastPathComponent)
                if order != .orderedSame {
                    return sort.ascending ? order == .orderedAscending : order == .orderedDescending
                }
            case .type:
                let a = first.url.pathExtension.lowercased()
                let b = second.url.pathExtension.lowercased()
                if a != b {
                    // Dateien ohne Endung ans Ende.
                    if a.isEmpty { return false }
                    if b.isEmpty { return true }
                    return sort.ascending ? a < b : a > b
                }
            case .size:
                if first.size != second.size {
                    // ⚠️ Unbekannte Groesse ans Ende, unabhaengig von der
                    // Richtung – wie bei Dateien ohne Endung. Sie als 0 zu
                    // behandeln stellte sie zu den echten leeren Dateien.
                    guard let a = first.size else { return false }
                    guard let b = second.size else { return true }
                    return sort.ascending ? a < b : a > b
                }
            }
            if first.timestamp != second.timestamp {
                return first.timestamp > second.timestamp
            }
            return first.url.lastPathComponent
                .localizedStandardCompare(second.url.lastPathComponent) == .orderedAscending
        }
    }
}
