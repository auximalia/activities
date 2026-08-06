import AppKit
import ServiceManagement

/// Steuert, wie die App im System auftritt: Dock-Symbol und Anmeldestart.
///
/// Beides sind Systemeinstellungen, keine Fensterzustände – deshalb hier
/// gebündelt und nicht im ``ReportViewModel``.
enum AppPresence {
    /// Blendet das Dock-Symbol aus bzw. ein.
    ///
    /// `.accessory` lässt die App nur in der Menüleiste leben; `.regular` ist
    /// das gewohnte Verhalten mit Dock-Symbol und Menüleiste des Programms.
    static func setDockIconVisible(_ visible: Bool) {
        NSApp.setActivationPolicy(visible ? .regular : .accessory)
        if visible {
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    // MARK: - Anmeldestart

    /// Ob die App beim Anmelden startet.
    static var launchesAtLogin: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// Schaltet den Anmeldestart um.
    ///
    /// - Returns: Fehlermeldung, falls das System die Änderung ablehnt
    ///   (z. B. weil die App nicht in `/Applications` liegt).
    @discardableResult
    static func setLaunchesAtLogin(_ enabled: Bool) -> String? {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            return nil
        } catch {
            return error.localizedDescription
        }
    }
}
