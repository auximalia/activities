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
    static func execute(_ steps: [MoveStep], kind: TransferKind = .move) -> Report {
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
                switch kind {
                case .move: try fm.moveItem(at: step.source, to: step.destination)
                case .copy: try fm.copyItem(at: step.source, to: step.destination)
                }
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
    static func undo(_ pairs: [(from: URL, to: URL)], kind: TransferKind) -> Report {
        switch kind {
        case .move:
            // Rueckwaerts, damit eine Kette (a→b, b→c) sich sauber aufloest.
            return execute(pairs.reversed().map {
                MoveStep(source: $0.to, destination: $0.from, hadConflict: false, resolution: nil)
            }, kind: .move)

        case .copy:
            // **⚠️ Eine Kopie wird nicht zurueckgeschoben, sie wird
            // weggeraeumt** – und zwar in den **Papierkorb**, nicht geloescht.
            // Das Original liegt unveraendert an seinem Platz; die Kopie
            // zurueckzuschieben hiesse, sie ueber das Original zu legen.
            var report = Report()
            for paar in pairs.reversed() {
                do {
                    try FileManager.default.trashItem(at: paar.to, resultingItemURL: nil)
                } catch {
                    report.failures.append(
                        "\u{201E}\(paar.to.lastPathComponent)\u{201C}: \(error.localizedDescription)"
                    )
                }
            }
            return report
        }
    }
}

// MARK: - Ordner-Handgriffe (Sprint 19)

extension FileMoveService {

    /// Die Einträge eines Ordners, in der Form, die ``FolderEmptiness`` erwartet.
    static func contents(of folder: URL) -> [(name: String, isFolder: Bool)] {
        let fm = FileManager.default
        guard let inhalt = try? fm.contentsOfDirectory(
            at: folder, includingPropertiesForKeys: [.isDirectoryKey], options: []
        ) else { return [] }
        return inhalt.map { url in
            let ordner = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            return (name: url.lastPathComponent, isFolder: ordner)
        }
    }

    /// Ob dieser Ordner **auf der Platte** leer ist – rekursiv, Artefakte ausgenommen.
    ///
    /// **⚠️ Geprüft im Moment des Ausführens, nicht beim Aufbau des Menüs.**
    /// Zwischen beidem liegt beliebig viel Zeit, und ein Ordner, der beim
    /// Anzeigen leer war, kann es beim Klicken nicht mehr sein.
    static func isEmptyOnDisk(_ folder: URL) -> Bool {
        FolderEmptiness.isEmpty(folder, contents: contents(of:))
    }

    /// Wie viele Dateien unter diesem Ordner liegen.
    ///
    /// **⚠️ Mit Obergrenze und abbrechbar.** Ein Ordner mit 8.412 Dateien zu
    /// zählen kostet Zeit; eine Rückfrage darf davon nicht hängen. Wird die
    /// Grenze überschritten, meldet die Zählung ``nil`` – der Text sagt dann
    /// „mehr als N" statt einer erfundenen Genauigkeit.
    static func fileCount(under folder: URL, limit: Int = 5000) -> Int? {
        let fm = FileManager.default
        guard let lauf = fm.enumerator(at: folder, includingPropertiesForKeys: [.isDirectoryKey],
                                       options: [.skipsPackageDescendants]) else { return 0 }
        var n = 0
        for fall in lauf {
            guard let url = fall as? URL else { continue }
            let ordner = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            if !ordner {
                n += 1
                if n > limit { return nil }
            }
        }
        return n
    }

    /// Legt einen Ordner an.
    static func createFolder(named name: String, in parent: URL) -> (url: URL?, failure: String?) {
        let ziel = parent.appendingPathComponent(FolderNaming.sanitized(name), isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: ziel, withIntermediateDirectories: false)
            return (ziel, nil)
        } catch {
            return (nil, error.localizedDescription)
        }
    }

    /// Benennt eine Datei oder einen Ordner um.
    ///
    /// **⚠️ Der Umweg über einen Zwischennamen ist kein Übereifer.** Ändert der
    /// neue Name nur die Groß-/Kleinschreibung, scheitert `moveItem` auf einem
    /// nicht unterscheidenden Dateisystem – und macOS ist das üblicherweise –
    /// mit „Datei existiert bereits". Aus `Projekt` würde nie `projekt`, und die
    /// Meldung sagte etwas, das nicht stimmt.
    static func rename(_ url: URL, to name: String) -> (url: URL?, failure: String?) {
        let sauber = FolderNaming.sanitized(name)
        let ziel = url.deletingLastPathComponent().appendingPathComponent(sauber)
        let fm = FileManager.default
        do {
            if FolderNaming.isCaseOnlyChange(from: url.lastPathComponent, to: sauber) {
                let zwischen = url.deletingLastPathComponent()
                    .appendingPathComponent(".\(UUID().uuidString)")
                try fm.moveItem(at: url, to: zwischen)
                try fm.moveItem(at: zwischen, to: ziel)
            } else {
                try fm.moveItem(at: url, to: ziel)
            }
            return (ziel, nil)
        } catch {
            return (nil, error.localizedDescription)
        }
    }

    /// Legt Objekte in den Papierkorb.
    ///
    /// **⚠️ Papierkorb, nicht löschen** – wie überall in diesem Programm. Was
    /// dort liegt, holt der Finder mit „Zurücklegen" zurück; ⌘Z macht dasselbe
    /// für den letzten Handgriff.
    static func trash(_ urls: [URL]) -> Report {
        var report = Report()
        for url in urls {
            do {
                var neu: NSURL?
                try FileManager.default.trashItem(at: url, resultingItemURL: &neu)
                if let ziel = neu as URL? {
                    report.moved.append((from: url, to: ziel))
                }
            } catch {
                report.failures.append(
                    "\u{201E}\(url.lastPathComponent)\u{201C}: \(error.localizedDescription)"
                )
            }
        }
        return report
    }
}
