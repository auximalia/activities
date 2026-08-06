import AppKit
import Carbon.HIToolbox

/// Globales Tastenkürzel (⌥⌘A), das die App aus jeder Anwendung nach vorn holt.
///
/// **Warum Carbon und nicht `NSEvent.addGlobalMonitorForEvents`?**
/// Der NSEvent-Weg verlangt die Freigabe für **Bedienungshilfen** – der
/// Anwender müsste die Systemeinstellungen öffnen und der App erlauben,
/// sämtliche Eingaben mitzulesen. Für ein Komfortmerkmal ist das
/// unverhältnismäßig, zumal die App sonst nur Lesezugriff auf Dateien braucht.
/// `RegisterEventHotKey` kommt **ohne jede Freigabe** aus; die API ist alt,
/// aber seit Jahrzehnten unverändert und weiterhin unterstützt.
enum GlobalHotKey {
    private static var hotKeyRef: EventHotKeyRef?
    private static var handler: EventHandlerRef?
    private static var onTrigger: (() -> Void)?

    /// Registriert ⌥⌘A. Mehrfaches Aufrufen ist unschädlich.
    static func register(_ action: @escaping () -> Void) {
        guard hotKeyRef == nil else {
            onTrigger = action
            return
        }
        onTrigger = action

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, _ in
                DispatchQueue.main.async { GlobalHotKey.onTrigger?() }
                return noErr
            },
            1, &eventType, nil, &handler
        )

        let id = EventHotKeyID(signature: OSType(0x4143_5456), id: 1) // "ACTV"
        RegisterEventHotKey(
            UInt32(kVK_ANSI_A),
            UInt32(optionKey | cmdKey),
            id,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
    }

    static func unregister() {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        hotKeyRef = nil
        if let handler { RemoveEventHandler(handler) }
        handler = nil
        onTrigger = nil
    }
}
