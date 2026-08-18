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

    final class DragCatcherView: MonitoringView, NSDraggingSource {
        var targets: (() -> [URL])?
        var prepare: (() -> Void)?

        /// ⚠️ `.leftMouseDragged`, nicht `.leftMouseDown`. Beim Druck ist noch
        /// nicht entschieden, ob es ein Klick oder ein Ziehen wird – dort zu
        /// starten machte jeden Klick zum Ziehen.
        /// **⚠️ Auch `.leftMouseDown` und `.leftMouseUp`, nicht nur das Ziehen.**
        /// Ohne den Druckpunkt gibt es keine Strecke, die man messen könnte —
        /// und ohne Strecke startet **jedes** Zittern eine Ziehsitzung. Aus der
        /// Praxis gemeldet: *„Fast jeder Klick mit kleinstem Maus-Zeiger-Wackeln
        /// startet eine Verschiebung … Man kann gar nicht mehr entspannt auf-
        /// bzw. zuklappen."*
        override var monitoredEvents: NSEvent.EventTypeMask {
            [.leftMouseDown, .leftMouseDragged, .leftMouseUp]
        }

        /// Wo die Maus gedrückt wurde – ``nil``, solange sie oben ist.
        ///
        /// **⚠️ Er sichert zugleich, dass die Bewegung HIER begonnen hat.**
        /// Vorher genügte ein Ziehen, das über diese Zeile *hinwegging*; die
        /// Sitzung riss dann eine Zeile an sich, die der Anwender nie angefasst
        /// hatte.
        private var pressedAt: NSPoint?

        /// Wie weit die Maus wandern muss, bevor aus dem Klick ein Ziehen wird.
        ///
        /// **⚠️ Gesetzt, nicht gemessen — und das soll man ihr ansehen.** Es
        /// gibt keine öffentliche Systemgröße dafür; AppKit benutzt seit jeher
        /// eine Schwelle in dieser Größenordnung. Vier Punkte liegen über dem
        /// Zittern einer ruhigen Hand und unter dem, was als „ich habe gezogen"
        /// durchgeht. *Wackelt es weiterhin, ist es genau diese Zahl.*
        private static let dragThreshold: CGFloat = 4

        override func handle(_ event: NSEvent) -> Bool {
            switch event.type {
            case .leftMouseDown:
                pressedAt = event.locationInWindow
                return false          // der Klick gehoert weiterhin SwiftUI
            case .leftMouseUp:
                pressedAt = nil
                return false
            case .leftMouseDragged:
                guard let from = pressedAt else { return false }
                let now = event.locationInWindow
                let distance = hypot(now.x - from.x, now.y - from.y)
                guard distance >= Self.dragThreshold else { return false }
                pressedAt = nil       // eine Sitzung je Druck
                return start(event)
            default:
                return false
            }
        }

        /// Startet die Ziehsitzung – oder überlässt das Ereignis SwiftUI.
        ///
        /// **⚠️ Bei **einer** Datei wird nichts übernommen.** Dann leistet
        /// SwiftUIs `onDrag` dasselbe, samt eigener Vorschau, und ein zweiter
        /// Weg für denselben Fall wäre die Sorte Verdopplung, die später
        /// auseinanderläuft. Übernommen wird nur, was SwiftUI **nicht kann**.
        private func start(_ event: NSEvent) -> Bool {
            prepare?()
            let urls = targets?() ?? []
            // ⚠️ Auch der EINZELFALL laeuft hierueber (v1.19.78). Bis dahin war
            // er SwiftUI ueberlassen, und das war die Verdopplung, die prompt
            // auseinanderlief: SwiftUIs `onDrag` bestimmt die erlaubten
            // Operationen selbst, also haette eine Datei nur kopiert und zwei
            // haetten verschoben werden koennen. Ein Weg, ein Verhalten.
            guard !urls.isEmpty else { return false }

            let origin = convert(event.locationInWindow, from: nil)
            let items: [NSDraggingItem] = urls.enumerated().map { index, url in
                let item = NSDraggingItem(pasteboardWriter: url as NSURL)
                if urls.count == 1 {
                    // ⚠️ Bei EINER Datei steht der Name dabei. Die Vorschau kam
                    // bis v1.19.78 von SwiftUIs `onDrag(preview:)`; seit der
                    // Einzelfall ebenfalls hierueber laeuft, muss sie hier
                    // entstehen – sonst haenge nur ein Symbol am Zeiger, und
                    // bei fuenf gleichnamigen Dateien saehe man nicht, welche.
                    let image = Self.preview(for: url)
                    item.setDraggingFrame(
                        NSRect(x: origin.x - 16, y: origin.y - image.size.height / 2,
                               width: image.size.width, height: image.size.height),
                        contents: image
                    )
                } else {
                    // Die Bilder leicht versetzt stapeln – so sieht man, dass es
                    // mehrere sind, ohne dass eine Zahl nötig wäre.
                    let offset = CGFloat(min(index, 4)) * 4
                    let image = NSWorkspace.shared.icon(forFile: url.path)
                    image.size = NSSize(width: 32, height: 32)
                    item.setDraggingFrame(
                        NSRect(x: origin.x - 16 + offset, y: origin.y - 16 - offset,
                               width: 32, height: 32),
                        contents: image
                    )
                }
                return item
            }
            beginDraggingSession(with: items, event: event, source: self)
            return true
        }

        /// Symbol und Name nebeneinander, als Bild fuer den Mauszeiger.
        private static func preview(for url: URL) -> NSImage {
            let icon = NSWorkspace.shared.icon(forFile: url.path)
            icon.size = NSSize(width: 16, height: 16)
            let font = NSFont.systemFont(ofSize: 12)
            let name = url.lastPathComponent as NSString
            let textSize = name.size(withAttributes: [.font: font])
            let width = 16 + 6 + ceil(textSize.width) + 12
            let height: CGFloat = 22

            let image = NSImage(size: NSSize(width: width, height: height))
            image.lockFocus()
            NSColor.windowBackgroundColor.withAlphaComponent(0.95).setFill()
            let frame = NSBezierPath(roundedRect: NSRect(x: 0, y: 0, width: width, height: height),
                                      xRadius: 5, yRadius: 5)
            frame.fill()
            NSColor.separatorColor.setStroke()
            frame.stroke()
            icon.draw(in: NSRect(x: 6, y: (height - 16) / 2, width: 16, height: 16))
            name.draw(at: NSPoint(x: 28, y: (height - textSize.height) / 2),
                      withAttributes: [.font: font, .foregroundColor: NSColor.labelColor])
            image.unlockFocus()
            return image
        }

        // MARK: - NSDraggingSource

        func draggingSession(_ session: NSDraggingSession,
                             sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
            // **⚠️ Hier stand `context == .outsideApplication ? [.copy] : []`,
            // und die zweite Haelfte war ein Defekt.** Innerhalb der App war
            // damit **keine** Operation erlaubt – ein Zug mit mehreren Dateien
            // auf eine Ordnerzeile wurde abgewiesen, waehrend der Einzelzug
            // ueber SwiftUI ankam. Ausgeliefert in v1.19.77, bemerkt beim
            // Nachlesen eine Stunde spaeter.
            //
            // **Die Quelle sagt, was ERLAUBT ist, das Ziel waehlt aus.** Genau
            // daraus entsteht der Anhaenger am Mauszeiger: Meldet das Ziel
            // `.copy`, zeichnet das System das gruene Plus; meldet es `.move`,
            // zeichnet es nichts. Beschraenkt die Quelle auf `.copy`, kann das
            // Ziel nie etwas anderes waehlen – und der Anhaenger lueckenlos
            // falsch stehen.
            [.copy, .move]
        }
    }
}
