import SwiftUI
import ActivitiesCore

/// Übersetzt den Kürzelkatalog aus ``ActivitiesCore`` in SwiftUI-Begriffe.
///
/// **Die Übersetzung ist bewusst dünn.** Sie enthält keine Entscheidung – wer
/// wissen will, welches Kürzel ein Befehl trägt, liest ``Shortcuts``, nicht
/// diese Datei. Genau darum geht es: Es soll **eine** Stelle geben, an der ein
/// Kürzel steht (UX-39).
extension EventModifiers {
    init(_ modifiers: ShortcutModifiers) {
        var result: EventModifiers = []
        if modifiers.contains(.command) { result.insert(.command) }
        if modifiers.contains(.shift)   { result.insert(.shift) }
        if modifiers.contains(.option)  { result.insert(.option) }
        if modifiers.contains(.control) { result.insert(.control) }
        self = result
    }
}

extension KeyEquivalent {
    init?(_ key: ShortcutKey) {
        switch key {
        case .character(let character): self = KeyEquivalent(character)
        case .upArrow:                  self = .upArrow
        case .space:                    self = .space
        case .return:                   self = .return
        case .escape:                   self = .escape
        }
    }
}

extension View {
    /// Bindet einen Katalogeintrag als Tastenkürzel.
    ///
    /// Einträge ohne Taste (⌘-Klick, die Pfeiltasten der Liste) stehen im
    /// Katalog, damit die Hilfe vollständig ist – ein Menükürzel werden sie
    /// hier nicht. `nil` ist ebenso erlaubt, damit ein Aufrufer nicht mit einem
    /// Platzhalter-Eintrag hantieren muss.
    @ViewBuilder
    func keyboardShortcut(_ entry: ShortcutEntry?) -> some View {
        if let entry, let key = entry.key, let equivalent = KeyEquivalent(key) {
            self.keyboardShortcut(equivalent, modifiers: EventModifiers(entry.modifiers))
        } else {
            self
        }
    }
}
