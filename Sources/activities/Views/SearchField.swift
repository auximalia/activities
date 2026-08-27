import SwiftUI
import AppKit

/// Echtes `NSSearchField` für die Toolbar.
///
/// **Warum nicht `.searchable`?** Dessen Platzierung bestimmt SwiftUI – das Feld
/// landet zwingend ganz rechts. Für den Arbeitsablauf
/// *Ort → Suche → Zeitraum → Anpassungen* muss es an die zweite Stelle. Das
/// eingebettete `NSSearchField` liefert die native Optik (Lupe, Löschen-Knopf,
/// runde Form) bei freier Platzierung.
///
/// **⚠️ Die Suche läuft erst bei Enter** – hier stand bis v2.1.1 noch
/// „entprellt im Modell, ~250 ms". Die Entprellung ist seit v1.19.52 entfernt
/// (Begründung in ``ReportViewModel/namePatternDidChange()``); der Löschen-Knopf
/// wirkt weiterhin sofort. Prosa, die etwas anderes sagt als der Code, wird
/// geglaubt – deshalb die ausdrückliche Berichtigung statt einer stillen Änderung.
struct SearchField: NSViewRepresentable {
    @Binding var text: String
    var prompt: String
    var width: CGFloat = 220
    /// Wird bei jeder Eingabe gerufen – das Modell entscheidet, ob etwas zu tun
    /// ist (bei nicht-leerem Feld: nichts).
    var onChange: () -> Void
    /// Wird bei Enter und beim Löschen-Knopf gerufen – ohne Verzögerung.
    var onSubmit: () -> Void

    func makeNSView(context: Context) -> NSSearchField {
        let field = NSSearchField()
        field.placeholderString = prompt
        field.delegate = context.coordinator
        field.target = context.coordinator
        field.action = #selector(Coordinator.submit(_:))
        field.sendsWholeSearchString = true
        field.sendsSearchStringImmediately = false
        field.controlSize = .regular
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return field
    }

    func updateNSView(_ field: NSSearchField, context: Context) {
        context.coordinator.parent = self
        // Nur schreiben, wenn sich der Wert wirklich unterscheidet – sonst
        // springt die Einfuegemarke bei jedem Redraw ans Ende.
        if field.stringValue != text {
            field.stringValue = text
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, NSSearchFieldDelegate {
        var parent: SearchField

        init(_ parent: SearchField) {
            self.parent = parent
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSSearchField else { return }
            parent.text = field.stringValue
            parent.onChange()
        }

        /// Enter **oder** Klick auf den Löschen-Knopf.
        @objc func submit(_ sender: NSSearchField) {
            parent.text = sender.stringValue
            parent.onSubmit()
        }
    }
}
