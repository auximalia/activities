import SwiftUI
import AppKit

/// Fängt das Mausrad über einer SwiftUI-Fläche ab, **ohne** deren übrige Gesten
/// anzutasten.
///
/// **⚠️ Der naheliegende Weg zerbricht das Diagramm.** Eine `NSView`, die
/// `scrollWheel(with:)` überschreibt, muss anklickbar sein, damit AppKit ihr das
/// Ereignis überhaupt zustellt – und verschluckt damit Klick, Ziehen und
/// Überfahren. Genau diese drei Gesten hat die Diagrammfläche bereits
/// (`HistoryChartView`: Ziehen wählt eine Spanne, Klick springt zum Tag,
/// Überfahren zeigt die Kurzinfo). Der Kommentar dort hält außerdem fest, dass
/// laufende Zustandsänderungen eine Ziehgeste **abbrechen** – ein vierter
/// Erkenner in derselben Fläche wäre die dritte Regression dieser Art.
///
/// **Deshalb ein lokaler Ereignisbeobachter statt eines Erkenners.** Die
/// eingebettete `NSView` gibt aus `hitTest` grundsätzlich `nil` zurück und ist
/// damit für jedes andere Ereignis nicht vorhanden; sie dient nur dazu, das
/// Rechteck der Fläche im Fenster zu kennen. Der Beobachter prüft bei jedem
/// Rad-Ereignis, ob der Zeiger darin liegt.
///
/// **⚠️ Lokal, nicht global.** Ein globaler Beobachter verlangt die Freigabe der
/// Bedienhilfen – dieselbe Unterscheidung, die ``GlobalHotKey`` schon einmal
/// aufgeschrieben hat (dort fiel die Wahl aus genau diesem Grund auf Carbon).
///
/// **⚠️ Abgemeldet wird beim Verlassen des Fensters, nicht erst im `deinit`.**
/// Ein prozessweiter Beobachter, der einen geschlossenen Fensterinhalt
/// überlebt, verstellt den Zeitraum, während man über einem ganz anderen
/// Fenster dreht. Das ist der Fehler, den dieses Muster üblicherweise macht.
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

    final class CatcherView: NSView {
        var onWheel: ((NSEvent) -> Bool)?
        private var monitor: Any?

        /// **Für alles außer dem Beobachter unsichtbar.**
        override func hitTest(_ point: NSPoint) -> NSView? { nil }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if window == nil { remove() } else { install() }
        }

        deinit {
            // ⚠️ `deinit` ist nur das Netz darunter. Der Regelweg ist
            // `viewDidMoveToWindow(nil)`; verlaesst man sich allein auf `deinit`,
            // haengt die Lebensdauer des Beobachters am Aufraeumzeitpunkt von
            // SwiftUI – und der ist nicht zugesichert.
            if let monitor { NSEvent.removeMonitor(monitor) }
        }

        private func install() {
            guard monitor == nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
                guard let self, self.hits(event) else { return event }
                return (self.onWheel?(event) ?? false) ? nil : event
            }
        }

        private func remove() {
            if let monitor { NSEvent.removeMonitor(monitor) }
            monitor = nil
        }

        /// Liegt der Zeiger dieses Ereignisses in unserer Fläche?
        ///
        /// **⚠️ Auch das Fenster wird geprüft, nicht nur der Punkt.** Ein
        /// lokaler Beobachter bekommt die Ereignisse **aller** Fenster dieses
        /// Programms – Einstellungen, Hilfe, Über. Ohne diesen Vergleich träfe
        /// ein Rad an derselben Bildschirmstelle über dem Hilfefenster zu.
        private func hits(_ event: NSEvent) -> Bool {
            guard let window, event.window === window else { return false }
            let punkt = convert(event.locationInWindow, from: nil)
            return bounds.contains(punkt)
        }
    }
}
