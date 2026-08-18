import Foundation
import AppKit
import ActivitiesCore

/// Führt eine geplante Verschiebung aus – die **einzige** Stelle, an der dieses
/// Programm Dateien bewegt.
///
/// **⚠️ Das ist die erste schreibende Handlung der App.** Bis v1.19.76 hat sie
/// ausschließlich gelesen; `backlog.md` schloss Dateiverwaltung ausdrücklich
/// aus. Die Grenze verschiebt sich um **eine** Handlung, nicht um eine
/// Kategorie – und deshalb steht hier genau eine Operation und nicht ein
/// Werkzeugkasten.
///
/// **⚠️ Beim Ersetzen wandert das Vorhandene in den Papierkorb, es wird nicht
/// gelöscht.** Der Finder löscht an dieser Stelle endgültig. Diese App darf das
/// nicht, weil sie ⌘Z verspricht: Wären zwei Verschiebungen äußerlich gleich
/// und nur eine davon umkehrbar, wäre die Zusage „rückgängig" nur manchmal wahr
/// – und das ist schlimmer als keine.
enum FileMoveService {

    /// Was ein Durchgang hinterlassen hat.
    struct Report {
        /// Ausgeführte Paare, für das Widerrufen.
        var moved: [(from: URL, to: URL)] = []
        /// Was nicht ging, mit Grund – je Datei ein Satz.
        var failures: [String] = []
        /// Übersprungene Dateien.
        var skipped = 0

        var isEmpty: Bool { moved.isEmpty && failures.isEmpty && skipped == 0 }
    }

    /// Die Namen, die im Zielordner bereits vergeben sind.
    ///
    /// **⚠️ Einschließlich unsichtbarer Dateien.** Ein `.DS_Store` kollidiert
    /// nicht, aber eine versteckte gleichnamige Datei sehr wohl – und der
    /// Vorgang scheiterte dann mit einer Systemmeldung statt mit einer Frage.
    static func existingNames(in folder: URL) -> Set<String> {
        let inhalt = try? FileManager.default.contentsOfDirectory(
            at: folder, includingPropertiesForKeys: nil, options: []
        )
        return Set((inhalt ?? []).map(\.lastPathComponent))
    }

    /// Führt die Schritte aus.
    ///
    /// **⚠️ Es wird weitergemacht und am Ende berichtet, nicht abgebrochen.**
    /// Ein Abbruch bei Datei drei von fünf hinterlässt einen Zustand, den
    /// niemand überblickt – dieselbe Regel wie beim Massenöffnen.
    ///
    /// **⚠️ Der Konflikt wird hier ERNEUT geprüft, nicht nur im Plan.** Zwischen
    /// Planen und Ausführen liegt ein Dialog; in dieser Zeit kann ein anderes
    /// Programm die Zieldatei angelegt haben. Ein Plan ist eine Absicht, keine
    /// Zusicherung über die Platte.
    static func execute(_ steps: [MoveStep]) -> Report {
        var report = Report()
        let fm = FileManager.default

        for step in steps {
            if step.resolution == .skip {
                report.skipped += 1
                continue
            }

            do {
                if fm.fileExists(atPath: step.destination.path) {
                    switch step.resolution {
                    case .replace:
                        // Papierkorb statt Loeschen – siehe Typkommentar.
                        try fm.trashItem(at: step.destination, resultingItemURL: nil)
                    default:
                        // Der Name war beim Planen frei und ist es nicht mehr.
                        // Nicht raten, sondern melden.
                        report.failures.append(
                            "„\(step.source.lastPathComponent)“: inzwischen liegt am Ziel eine "
                            + "Datei dieses Namens."
                        )
                        continue
                    }
                }
                try fm.moveItem(at: step.source, to: step.destination)
                report.moved.append((from: step.source, to: step.destination))
            } catch {
                report.failures.append(
                    "„\(step.source.lastPathComponent)“: \(error.localizedDescription)"
                )
            }
        }
        return report
    }

    /// Macht eine Verschiebung rückgängig.
    ///
    /// **⚠️ Die ersetzte Datei kommt dabei NICHT aus dem Papierkorb zurück.**
    /// Sie liegt dort und lässt sich im Finder mit „Zurücklegen" holen; das
    /// programmatisch zu tun, hieße den Papierkorb zu durchsuchen und zu raten,
    /// welcher Eintrag gemeint ist. Der Bericht sagt das, statt es zu
    /// verschweigen.
    static func undo(_ pairs: [(from: URL, to: URL)]) -> Report {
        // Rueckwaerts, damit eine Kette (a→b, b→c) sich sauber aufloest.
        execute(pairs.reversed().map {
            MoveStep(source: $0.to, destination: $0.from, hadConflict: false, resolution: nil)
        })
    }
}
