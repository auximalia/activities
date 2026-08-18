import SwiftUI
import AppKit

/// Eine `NSView`, die es für alles außer ihrer eigenen Aufgabe **nicht gibt**.
///
/// **⚠️ Warum das die Grundform ist und nicht ein Gestenerkenner.** Wo SwiftUI
/// nichts anbietet — Mausrad, echte Ziehsitzung, Eingabefokus im Blatt —, muss
/// AppKit ran. Eine `NSView`, die Ereignisse **empfängt**, muss anklickbar sein
/// und verschluckt damit Klick, Ziehen und Überfahren der Ansicht darunter. Die
/// Dateizeile trägt drei Erkenner, und die Quelle hält zwei Regressionen fest,
/// die genau aus deren Zusammenspiel entstanden sind.
///
/// Deshalb: `hitTest` gibt **immer `nil`** zurück. Die Ansicht ist eine
/// Ortsangabe, kein Empfänger.
class InvisibleView: NSView {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    /// Liegt der Zeiger dieses Ereignisses in dieser Fläche?
    ///
    /// **⚠️ Auch das Fenster wird verglichen, nicht nur der Punkt.** Ein lokaler
    /// Beobachter bekommt die Ereignisse **aller** Fenster dieses Programms —
    /// Einstellungen, Hilfe, Über. Ohne diesen Vergleich träfe ein Rad an
    /// derselben Bildschirmstelle über dem Hilfefenster zu.
    func contains(_ event: NSEvent) -> Bool {
        guard let window, event.window === window else { return false }
        return bounds.contains(convert(event.locationInWindow, from: nil))
    }
}

/// Ein lokaler Ereignisbeobachter, der genau so lange lebt wie eine Ansicht.
///
/// **⚠️ Der Lebenszyklus ist der eigentliche Inhalt dieses Typs, nicht die
/// Registrierung.** Er stand bis v2.0.9 **zweimal** im Programm — im
/// `WheelCatcher` und in der `MultiFileDragSource` —, jeweils mit demselben
/// `⚠️`-Kommentar daneben. Zwei Kopien eines heiklen Ablaufs sind eine Kopie zu
/// viel: Eine Korrektur an einer Stelle erreicht die andere nicht.
///
/// **⚠️ Abgemeldet wird beim Verlassen des Fensters, nicht erst im `deinit`.**
/// Ein prozessweiter Beobachter, der einen geschlossenen Fensterinhalt
/// überlebt, wirkt weiter, während man über einem **anderen** Fenster arbeitet.
/// Das ist der Fehler, den dieses Muster üblicherweise macht.
///
/// **⚠️ `deinit` ist nur das Netz darunter.** Der Regelweg ist
/// `viewDidMoveToWindow(nil)`; verlässt man sich allein auf `deinit`, hängt die
/// Lebensdauer am Aufräumzeitpunkt von SwiftUI — und der ist nicht zugesichert.
///
/// **⚠️ Lokal, nicht global.** Ein globaler Beobachter verlangt die Freigabe der
/// Bedienhilfen — dieselbe Unterscheidung, die ``GlobalHotKey`` schon einmal
/// aufgeschrieben hat.
class MonitoringView: InvisibleView {
    /// Welche Ereignisse gemeldet werden. Von der Unterklasse zu setzen.
    var monitoredEvents: NSEvent.EventTypeMask { [] }

    /// Wird für jedes passende Ereignis gerufen.
    /// - Returns: `true`, wenn das Ereignis **verbraucht** ist.
    func handle(_ event: NSEvent) -> Bool { false }

    private var monitor: Any?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil { stopMonitoring() } else { startMonitoring() }
    }

    deinit {
        if let monitor { NSEvent.removeMonitor(monitor) }
    }

    private func startMonitoring() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: monitoredEvents) { [weak self] event in
            guard let self, self.contains(event) else { return event }
            return self.handle(event) ? nil : event
        }
    }

    private func stopMonitoring() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }
}
