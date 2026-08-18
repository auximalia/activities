import Foundation

/// Was beim Verschieben mit **einer** Datei geschehen soll.
public enum MoveResolution: String, Sendable, Hashable, CaseIterable {
    /// Vorhandene Datei am Ziel weicht – sie wandert in den Papierkorb.
    case replace
    /// Daneben ablegen, Name wird hochgezählt.
    case keepBoth
    /// Diese Datei bleibt, wo sie ist.
    case skip

    /// Beschriftung der Schaltfläche im Konfliktdialog.
    public var label: String {
        switch self {
        case .replace: "Ersetzen"
        case .keepBoth: "Daneben ablegen"
        case .skip: "Überspringen"
        }
    }
}

/// Ein geplanter Vorgang: von wo nach wo, und was am Ziel schon liegt.
public struct MoveStep: Sendable, Hashable {
    public let source: URL
    /// Der Zielpfad, **nachdem** die Auflösung angewandt wurde.
    public let destination: URL
    /// Lag am ursprünglichen Zielnamen bereits etwas?
    public let hadConflict: Bool
    /// Was mit dem Vorhandenen geschieht – ``nil``, wenn es keinen Konflikt gab.
    public let resolution: MoveResolution?

    public init(source: URL, destination: URL, hadConflict: Bool, resolution: MoveResolution?) {
        self.source = source
        self.destination = destination
        self.hadConflict = hadConflict
        self.resolution = resolution
    }
}

/// Der Plan einer Verschiebung – **ohne** die Platte anzufassen.
///
/// **⚠️ Warum der Plan vom Ausführen getrennt ist.** Ein Fehler hier ist
/// still: Ein Plan, der eine Datei doppelt nennt, sieht beim Ausführen richtig
/// aus, und ein Plan, der eine auslässt, fällt erst auf, wenn man sie sucht.
/// Getrennt ist er reine Rechnung und damit von ``CoreChecks`` erreichbar; das
/// Ausführen bleibt in der App-Schicht, wo `FileManager` lebt.
public enum MovePlan {

    /// Was **vor** dem Fragen feststeht: welche Dateien überhaupt kollidieren.
    ///
    /// - Parameters:
    ///   - sources: die zu verschiebenden Dateien.
    ///   - folder: der Zielordner.
    ///   - existing: die Namen, die im Zielordner bereits vergeben sind.
    /// - Returns: die Namen der kollidierenden Quellen, in Eingangsreihenfolge.
    public static func conflicts(sources: [URL], into folder: URL, existing: Set<String>) -> [URL] {
        sources.filter { source in
            source.deletingLastPathComponent().standardizedFileURL != folder.standardizedFileURL
                && existing.contains(source.lastPathComponent)
        }
    }

    /// Baut die auszuführenden Schritte.
    ///
    /// **⚠️ Dateien, die schon im Zielordner liegen, fallen heraus.** Sie auf
    /// sich selbst zu verschieben wäre je nach Auflösung ein Nichts, ein
    /// Hochzählen ohne Anlass oder – bei „Ersetzen" – ein Verschieben der Datei
    /// in den Papierkorb **und** an ihren eigenen Platz. Das ist kein
    /// Sonderfall, den man abfangen muss, sondern einer, den es nicht geben
    /// darf.
    ///
    /// **⚠️ Der Vorrat der belegten Namen wächst mit.** Werden zwei Dateien
    /// gleichen Namens aus zwei Ordnern zugleich verschoben, darf die zweite
    /// nicht denselben freien Namen bekommen wie die erste — sonst überschriebe
    /// der Vorgang sich selbst.
    ///
    /// - Parameter resolution: Antwort je Quelle; fehlt sie, gilt ``MoveResolution/keepBoth``.
    public static func steps(sources: [URL],
                             into folder: URL,
                             existing: Set<String>,
                             resolution: (URL) -> MoveResolution?) -> [MoveStep] {
        var belegt = existing
        var result: [MoveStep] = []

        for source in sources {
            guard source.deletingLastPathComponent().standardizedFileURL != folder.standardizedFileURL
            else { continue }

            let name = source.lastPathComponent
            guard belegt.contains(name) else {
                belegt.insert(name)
                result.append(MoveStep(source: source,
                                       destination: folder.appendingPathComponent(name),
                                       hadConflict: false,
                                       resolution: nil))
                continue
            }

            switch resolution(source) ?? .keepBoth {
            case .skip:
                result.append(MoveStep(source: source,
                                       destination: folder.appendingPathComponent(name),
                                       hadConflict: true,
                                       resolution: .skip))
            case .replace:
                result.append(MoveStep(source: source,
                                       destination: folder.appendingPathComponent(name),
                                       hadConflict: true,
                                       resolution: .replace))
            case .keepBoth:
                let frei = FileNaming.uniqueName(for: name, existing: belegt)
                belegt.insert(frei)
                result.append(MoveStep(source: source,
                                       destination: folder.appendingPathComponent(frei),
                                       hadConflict: true,
                                       resolution: .keepBoth))
            }
        }
        return result
    }

    /// Die Schritte, die wirklich etwas bewegen.
    public static func executable(_ steps: [MoveStep]) -> [MoveStep] {
        steps.filter { $0.resolution != .skip }
    }
}
