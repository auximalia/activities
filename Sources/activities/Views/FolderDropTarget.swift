import SwiftUI
import AppKit
import UniformTypeIdentifiers
import ActivitiesCore

/// Macht eine Ordnerzeile zum Ablegeziel für Dateien aus der Liste.
///
/// **⚠️ `onDrop(of:delegate:)` statt `dropDestination(for:)` — und der Grund ist
/// der Anhänger am Mauszeiger.** `dropDestination` nimmt entgegen und schweigt;
/// welche Operation gemeint ist, lässt sich nicht sagen. Das System zeichnet das
/// grüne Plus aber genau dann, wenn das **Ziel** `.copy` meldet — es ist keine
/// Verzierung, sondern die Antwort des Ziels, sichtbar gemacht. Ohne
/// ``DropDelegate/dropUpdated(info:)`` gibt es keine Antwort und damit auch
/// keinen Anhänger.
///
/// **⚠️ Seit v2.0.0 auch Fremdes — und damit ist die Zweideutigkeit da.** Ein
/// aus dem Finder gezogener **Ordner** bedeutete bisher „Quelle hinzufügen"
/// (Fensterziel) und bedeutet jetzt zusätzlich „hierhin verschieben"
/// (Zeilenziel): dieselbe Geste auf demselben Fenster.
///
/// **Entschieden (E1): die Zeile schlägt das Fenster.** Auf einer Ordnerzeile
/// wird verschoben oder kopiert, überall sonst wird der Ordner zur Quelle.
///
/// **⚠️ Das verlangt Zielgenauigkeit, und genau dagegen argumentiert der
/// Bestand:** `RootView` begründet sein großes Fensterziel mit *„beim Ziehen
/// zielt man nicht genau."* Der Satz bleibt wahr — er wird nicht widerlegt,
/// sondern **abgefedert**, und das ist die Bedingung, unter der E1 trägt:
/// **Die beiden Hervorhebungen schließen einander aus.** Solange der Zeiger über
/// einer Zeile steht, meldet ``ReportViewModel/isRowDropTargeted`` das dem
/// Fenster, und dessen Rahmen bleibt aus. Zwei Rahmen zugleich hießen zwei
/// mögliche Ausgänge.
struct FolderDropTarget: ViewModifier {
    @Bindable var model: ReportViewModel
    let folder: URL

    @State private var istZiel = false

    func body(content: Content) -> some View {
        content
            .overlay {
                if istZiel {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(Color.accentColor, lineWidth: 2)
                        .allowsHitTesting(false)
                }
            }
            .onDrop(of: [.fileURL], delegate: FolderDropDelegate(
                model: model, folder: folder, istZiel: $istZiel
            ))
            .onChange(of: istZiel) { _, neu in
                model.isRowDropTargeted = neu
            }
    }
}

/// Beantwortet für eine Ordnerzeile: annehmen? welche Operation? und dann tun.
private struct FolderDropDelegate: DropDelegate {
    let model: ReportViewModel
    let folder: URL
    @Binding var istZiel: Bool

    func validateDrop(info: DropInfo) -> Bool {
        info.hasItemsConforming(to: [.fileURL])
    }

    func dropEntered(info: DropInfo) { istZiel = true }
    func dropExited(info: DropInfo) { istZiel = false }

    /// **⚠️ Hier entsteht der Anhänger am Mauszeiger.**
    ///
    /// Die Regel selbst steht in ``DragOperation`` im Kern — sie ist die des
    /// Finders, und das ist der Punkt: Wer ⌥ drückt, hat diese Erwartung nicht
    /// in dieser App gelernt.
    ///
    /// **⚠️ Die Tasten werden bei JEDER Bewegung neu gelesen**, nicht einmal
    /// beim Eintreten. Im Finder wechselt der Anhänger, während man die Taste
    /// mitten in der Bewegung drückt; ein Zustand, der nur beim Betreten
    /// ermittelt wird, bliebe stehen und wäre dann falsch.
    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: art() == .copy ? .copy : .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        istZiel = false
        model.isRowDropTargeted = false
        let art = art()
        let anbieter = info.itemProviders(for: [.fileURL])
        guard !anbieter.isEmpty else { return false }

        // ⚠️ Die Anbieter liefern asynchron. Gesammelt wird ueber eine Gruppe,
        // damit ALLE Dateien in EINEM Vorgang landen – sonst entstuenden fuenf
        // einzelne Verschiebungen, fuenf Rueckfragen und fuenf Widerruf-Schritte
        // fuer eine Bewegung.
        let gruppe = DispatchGroup()
        let sperre = NSLock()
        var gesammelt: [URL] = []

        for anbieter in anbieter {
            gruppe.enter()
            _ = anbieter.loadObject(ofClass: URL.self) { url, _ in
                if let url {
                    sperre.lock()
                    gesammelt.append(url)
                    sperre.unlock()
                }
                gruppe.leave()
            }
        }

        gruppe.notify(queue: .main) {
            guard !gesammelt.isEmpty else { return }
            model.requestTransfer(gesammelt, to: folder, kind: art)
        }
        return true
    }

    private func art() -> TransferKind {
        let flags = NSEvent.modifierFlags
        return DragOperation.kind(
            sameVolume: VolumeInfo.sameVolume(folder, as: model.dragOriginFolder),
            optionDown: flags.contains(.option),
            commandDown: flags.contains(.command)
        )
    }
}

/// Liegen zwei Pfade auf demselben Datenträger?
///
/// **⚠️ Gefragt wird das Dateisystem, nicht der Pfad.** Ein Vergleich der
/// ersten Pfadbestandteile läge bei `/Volumes/…` richtig und bei einem
/// eingehängten Netzlaufwerk oder einem Firmlink falsch — und die Folge wäre
/// nicht kosmetisch: Über Volume-Grenzen ist ein Verschieben kein Umhängen,
/// sondern Kopieren und Löschen.
enum VolumeInfo {
    static func sameVolume(_ a: URL, as b: URL?) -> Bool {
        guard let b else { return true }
        let idA = try? a.resourceValues(forKeys: [.volumeIdentifierKey]).volumeIdentifier
        let idB = try? b.resourceValues(forKeys: [.volumeIdentifierKey]).volumeIdentifier
        guard let idA, let idB else { return true }
        return idA.isEqual(idB)
    }
}

extension View {
    /// Ordnerzeile als Ablegeziel – siehe ``FolderDropTarget``.
    func folderDropTarget(model: ReportViewModel, folder: URL) -> some View {
        modifier(FolderDropTarget(model: model, folder: folder))
    }
}
