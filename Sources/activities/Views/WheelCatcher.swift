import SwiftUI
import AppKit

/// Fängt das Mausrad über einer SwiftUI-Fläche ab, **ohne** deren übrige Gesten
/// anzutasten.
///
/// **⚠️ Der naheliegende Weg zerbricht das Diagramm.** Eine `NSView`, die
/// `scrollWheel(with:)` überschreibt, muss anklickbar sein, damit AppKit ihr das
/// Ereignis überhaupt zustellt – und verschluckt damit Klick, Ziehen und
/// Überfahren. Genau diese drei Gesten hat die Diagrammfläche bereits.
///
/// Alles Weitere — `hitTest → nil`, der Lebenszyklus des Beobachters, die Frage
/// nach dem richtigen Fenster — steht in ``MonitoringView``; hier bleibt nur,
/// **welches** Ereignis gemeint ist.
struct WheelCatcher: NSViewRepresentable {

    /// Wird für jedes Rad-Ereignis über der Fläche gerufen.
    /// Gibt `true` zurück, wenn das Ereignis verbraucht ist.
    let onWheel: (NSEvent) -> Bool

    func makeNSView(context: Context) -> CatcherView {
        let view = CatcherView()
        view.onWheel = onWheel
        return view
    }

    func updateNSView(_ nsView: CatcherView, context: Context) {
        nsView.onWheel = onWheel
    }

    final class CatcherView: MonitoringView {
        var onWheel: ((NSEvent) -> Bool)?

        override var monitoredEvents: NSEvent.EventTypeMask { .scrollWheel }
        override func handle(_ event: NSEvent) -> Bool { onWheel?(event) ?? false }
    }
}
