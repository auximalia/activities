import SwiftUI
import AppKit

/// Zieht **mehrere** Dateien in ein anderes Programm.
///
/// **⚠️ Warum das nicht mit SwiftUI geht.** `onDrag` hat die Signatur
/// `onDrag(_ data: () -> NSItemProvider)` – **Einzahl**. Ein `NSItemProvider`
/// trägt genau ein Objekt; die mehreren Repräsentationen darin sind
/// alternative Kodierungen **desselben** Objekts, keine zweite Datei. Der
/// Kommentar an der alten Aufrufstelle behauptete seit jeher, es würden „ALLE
/// ausgewählten Dateien gezogen", und der Code darunter stellte die Auswahl her
/// und übergab dann **eine** – aus der Praxis gemeldet: *„wenn ich 2 Dateien
/// markiere und auf ein Finder-Fenster ziehe, kommt immer nur die erste an"*.
///
/// **⚠️ Und SwiftUIs eigene Antwort ist unerreichbar.** `dragContainer(for:)`
/// und `draggable(containerItemID:)` tragen `@available(macOS 26.0, *)`; das
/// Ziel dieses Programms ist macOS 14. Der Weg führt also über AppKit.
///
/// **⚠️ Kein vierter Gestenerkenner in der Dateizeile.** Dort liegen bereits
/// `onDrag`, die Sofort-Markierung und der Doppelklick, und die Quelle hält
/// zwei Regressionen fest, die genau aus ihrem Zusammenspiel entstanden:
/// erst verschluckte die `DragGesture(minimumDistance: 0)` das Ziehen, dann
/// verschluckten beide zusammen den Doppelklick. Deshalb dieselbe Bauform wie
/// beim Mausrad: eine `NSView`, die aus `hitTest` **`nil`** zurückgibt und für
/// jedes andere Ereignis nicht vorhanden ist, plus ein **lokaler**
/// Ereignisbeobachter. Er sieht das Ziehen, bevor SwiftUI es tut, und startet
/// eine echte `NSDraggingSession` mit **einem `NSDraggingItem` je Datei**.
struct MultiFileDragSource: NSViewRepresentable {

    /// Die Dateien, die diese Zeile beim Ziehen mitnimmt – nach der
    /// Finder-Regel bereits aufgelöst.
    let targets: () -> [URL]
    /// Stellt die Auswahl her, bevor gezogen wird.
    let prepare: () -> Void

    func makeNSView(context: Context) -> DragCatcherView {
        let view = DragCatcherView()
        view.targets = targets
        view.prepare = prepare
        return view
    }

    func updateNSView(_ nsView: DragCatcherView, context: Context) {
        nsView.targets = targets
        nsView.prepare = prepare
    }

    final class DragCatcherView: NSView, NSDraggingSource {
        var targets: (() -> [URL])?
        var prepare: (() -> Void)?
        private var monitor: Any?

        /// **Für alles außer dem Beobachter unsichtbar.**
        override func hitTest(_ point: NSPoint) -> NSView? { nil }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if window == nil { entfernen() } else { einrichten() }
        }

        deinit {
            if let monitor { NSEvent.removeMonitor(monitor) }
        }

        private func einrichten() {
            guard monitor == nil else { return }
            // ⚠️ `.leftMouseDragged`, nicht `.leftMouseDown`. Beim Druck ist
            // noch nicht entschieden, ob es ein Klick oder ein Ziehen wird –
            // dort zu starten machte jeden Klick zum Ziehen.
            monitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDragged) { [weak self] event in
                guard let self, self.trifft(event) else { return event }
                return self.starte(event) ? nil : event
            }
        }

        private func entfernen() {
            if let monitor { NSEvent.removeMonitor(monitor) }
            monitor = nil
        }

        private func trifft(_ event: NSEvent) -> Bool {
            guard let window, event.window === window else { return false }
            return bounds.contains(convert(event.locationInWindow, from: nil))
        }

        /// Startet die Ziehsitzung – oder überlässt das Ereignis SwiftUI.
        ///
        /// **⚠️ Bei **einer** Datei wird nichts übernommen.** Dann leistet
        /// SwiftUIs `onDrag` dasselbe, samt eigener Vorschau, und ein zweiter
        /// Weg für denselben Fall wäre die Sorte Verdopplung, die später
        /// auseinanderläuft. Übernommen wird nur, was SwiftUI **nicht kann**.
        private func starte(_ event: NSEvent) -> Bool {
            prepare?()
            let urls = targets?() ?? []
            guard urls.count > 1 else { return false }

            let items: [NSDraggingItem] = urls.enumerated().map { index, url in
                let item = NSDraggingItem(pasteboardWriter: url as NSURL)
                // Die Bilder leicht versetzt stapeln – so sieht man, dass es
                // mehrere sind, ohne dass eine Zahl nötig wäre.
                let versatz = CGFloat(min(index, 4)) * 4
                let bild = NSWorkspace.shared.icon(forFile: url.path)
                bild.size = NSSize(width: 32, height: 32)
                let ort = convert(event.locationInWindow, from: nil)
                item.setDraggingFrame(
                    NSRect(x: ort.x - 16 + versatz, y: ort.y - 16 - versatz, width: 32, height: 32),
                    contents: bild
                )
                return item
            }
            beginDraggingSession(with: items, event: event, source: self)
            return true
        }

        // MARK: - NSDraggingSource

        func draggingSession(_ session: NSDraggingSession,
                             sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
            // ⚠️ `.copy`, nicht `.move`. Dieses Programm **liest** nur; ein
            // Ziehen, das die Datei am Ursprung entfernt, widerspräche der
            // Zusage „findet, verwaltet nicht" (`backlog.md`).
            context == .outsideApplication ? [.copy] : []
        }
    }
}
