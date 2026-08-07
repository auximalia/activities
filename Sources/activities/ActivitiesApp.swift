import SwiftUI
import AppKit
import ActivitiesCore

/// Zugriff auf das Hauptfenster.
///
/// **Warum eigens geregelt:** Seit dem Menueleisten-Symbol (9.6) lebt die App
/// weiter, wenn man das Fenster schliesst. „App aufrufen" traf dann auf einen
/// laufenden Prozess **ohne** Fenster – und es passierte scheinbar nichts.
/// Deshalb wird ein Fenster notfalls **neu erzeugt**, nicht nur nach vorn geholt.
enum MainWindow {
    static let id = "main"

    /// Das Fenster, das ``RootView`` traegt.
    ///
    /// **Warum gemeldet statt gesucht?** In `NSApp.windows` stehen auch das
    /// Ueber-, Hilfe- und Einstellungsfenster; sie sind von aussen nicht
    /// zuverlaessig zu unterscheiden (`canBecomeMain` trifft auf alle zu).
    /// Wer das Fenster von innen meldet, kann sich nicht irren.
    ///
    /// **Warum schwach?** Wird das Fenster geschlossen, soll die Referenz
    /// zerfallen – sonst hielten wir ein totes Fenster am Leben.
    private(set) static weak var window: NSWindow?

    /// Meldet das eigene Fenster an (siehe ``WindowReader``).
    static func adopt(_ window: NSWindow) {
        guard Self.window !== window else { return }
        Self.window = window
    }

    /// Holt das Hauptfenster nach vorn – und erzeugt es, wenn keines mehr da ist.
    static func show(_ openWindow: OpenWindowAction) {
        NSApp.activate(ignoringOtherApps: true)
        // Ein im Dock **abgelegtes** Fenster meldet `isVisible == false`. Ohne
        // die Abfrage auf `isMiniaturized` entstuende daneben ein zweites
        // Fenster, statt das vorhandene zurueckzuholen.
        if let window, window.isVisible || window.isMiniaturized {
            window.deminiaturize(nil)
            window.makeKeyAndOrderFront(nil)
        } else {
            openWindow(id: id)
        }
    }
}

/// Meldet das `NSWindow`, in dem diese Ansicht haengt, an ``MainWindow``.
///
/// Wird als `background` eingehaengt und zeichnet nichts – die Ansicht dient
/// allein dazu, an ihr Fenster zu kommen.
private struct WindowReader: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        // Beim Erzeugen haengt die Ansicht noch in keinem Fenster; erst im
        // naechsten Durchlauf ist `view.window` gesetzt.
        DispatchQueue.main.async { report(view) }
        return view
    }

    /// Zweite Gelegenheit: Traegt das Fenster nach, falls es beim Erzeugen noch
    /// fehlte oder die Ansicht spaeter in ein anderes Fenster gewandert ist.
    func updateNSView(_ view: NSView, context: Context) {
        report(view)
    }

    private func report(_ view: NSView) {
        if let window = view.window { MainWindow.adopt(window) }
    }
}

/// Leitet eine Standardaktion an den First Responder weiter (Zwischenablage).
private func sendToResponder(_ selector: String) {
    NSApp.sendAction(NSSelectorFromString(selector), to: nil, from: nil)
}

/// Einstiegspunkt der App: Hauptfenster, Menuebefehle und Ueber-Fenster.
@main
struct ActivitiesApp: App {
    @State private var model = ReportViewModel()
    @State private var updates = UpdateChecker()

    var body: some Scene {
        // **`Window`, nicht `WindowGroup`:** Alle Ansichten teilen sich *ein*
        // ``ReportViewModel``. Ein zweites Fenster waere daher kein zweites
        // Dokument, sondern ein **Spiegel** – gemessen: ein Umschalten im einen
        // Fenster aenderte sofort auch das andere. Zwei Fenster, die sich nicht
        // unabhaengig bedienen lassen, sind kein Merkmal, sondern eine Falle.
        // Nebenwirkung war ausserdem, dass ⌥⌘A nach dem Schliessen des zuletzt
        // gemeldeten von zwei Fenstern ein **drittes** oeffnete.
        Window("activities", id: MainWindow.id) {
            MainWindowHost(model: model, updates: updates)
        }
        .defaultSize(width: 1280, height: 780)
        // Kompakte Titelleiste: spart Hoehe gegenueber dem Standardstil, ohne
        // Bedienelemente zu verlieren.
        .windowToolbarStyle(.unifiedCompact)
        .commands {
            // ⌘W fehlte bisher ganz: SwiftUI stellt „Schließen" nur zusammen mit
            // „Neues Fenster" bereit, und beides entfaellt beim Einzelfenster.
            // Ein Fenster, das sich nur ueber den roten Knopf schliessen laesst,
            // ist auf dem Mac ein Fremdkoerper. Ueber die Responder-Kette, damit
            // ⌘W auch das Ueber-, Hilfe- und Einstellungsfenster schliesst –
            // dort ist es sogar der einzige gewohnte Weg.
            CommandGroup(after: .newItem) {
                Button("Schließen") { sendToResponder("performClose:") }
                    .keyboardShortcut("w", modifiers: .command)
            }
            CommandGroup(replacing: .appInfo) {
                AboutMenuButton()
                Divider()
                Button("Nach Updates suchen …") {
                    Task { await updates.check(manual: true) }
                }
                .disabled(updates.isChecking)
                Button("Update installieren") { updates.installUpdate() }
                    .disabled(!updates.showsUpdateBadge)
            }
            CommandGroup(after: .toolbar) {
                Button("Aktualisieren") { model.rescan() }
                    .keyboardShortcut("r", modifiers: .command)
                Button("Filter fokussieren") { model.filterFocusToken += 1 }
                    .keyboardShortcut("f", modifiers: .command)
                Button("Typ-Filter zurücksetzen") { model.resetTypeFilters() }
                    .keyboardShortcut("r", modifiers: [.command, .option])
                    .disabled(!model.hasTypeFilter)
                Button("An den Anfang") { model.scrollToTopToken += 1 }
                    .keyboardShortcut(.upArrow, modifiers: .command)
                Divider()
                // Auch als Menuebefehl: Die Gliederung ist die Grundentscheidung
                // der Ansicht und muss ohne Maus erreichbar sein.
                Picker("Gliederung", selection: Binding(
                    get: { model.viewMode },
                    set: { model.setViewMode($0) }
                )) {
                    ForEach(ViewMode.allCases, id: \.self) { mode in
                        Text(mode.longLabel).tag(mode)
                    }
                }
                Divider()
                // Auswahl in einem anderen Programm oeffnen. Ohne eingerichteten
                // Platz erscheint der Befehl gar nicht – ein Menuepunkt „In
                // (nichts) oeffnen" waere Ratlosigkeit in Menueform.
                if let editor = model.editorApp {
                    Button("In \(editor.name) öffnen") { model.openInEditor(model.commandTargets) }
                        .keyboardShortcut("e", modifiers: [.command, .shift])
                        .disabled(model.commandTargets.isEmpty)
                }
                if let terminal = model.terminalApp {
                    Button("In \(terminal.name) öffnen") { model.openInTerminal(model.commandTargets) }
                        .keyboardShortcut("t", modifiers: [.command, .shift])
                        .disabled(model.commandTargets.isEmpty)
                }
                Divider()
                Button("Nach Datum sortieren") { model.setSortField(.date) }
                    .keyboardShortcut("1", modifiers: [.command, .option])
                Button("Nach Name sortieren") { model.setSortField(.name) }
                    .keyboardShortcut("2", modifiers: [.command, .option])
                Button("Nach Typ sortieren") { model.setSortField(.type) }
                    .keyboardShortcut("3", modifiers: [.command, .option])
                Divider()
                Toggle("Dateien außerhalb des Zeitraums zeigen", isOn: Binding(
                    get: { model.showOutOfWindowFiles },
                    set: { model.setShowOutOfWindowFiles($0) }
                ))
                // Auch im Menue, weil der Schalter in der Titelleiste bei
                // schmalem Fenster ins Ueberlaufmenue wandert. Ein Zustand, den
                // man nur ueber „»" erreicht, ist beinahe ein verborgener.
                Toggle("Automatisch aktualisieren", isOn: Binding(
                    get: { model.autoRefresh },
                    set: { model.setAutoRefresh($0) }
                ))
            }
            // Export gehoert ins Menue „Ablage" – dort sucht man ihn.
            CommandGroup(replacing: .saveItem) {
                Button("Als CSV exportieren …") { ExportService.exportCSV(model.displayBuckets) }
                    .keyboardShortcut("e", modifiers: .command)
                // **⌥⌘E statt ⌘⇧E.** Das naheliegende ⌘⇧E ging an „In <Editor>
                // oeffnen": Ein Ordner im Editor ist ein taeglicher Handgriff,
                // ein HTML-Bericht eine Ausnahme – das leichter erreichbare
                // Kuerzel gehoert dem haeufigeren Befehl. ⌘E/⌥⌘E bleiben als
                // Paar beieinander.
                Button("Als HTML exportieren …") { ExportService.exportHTML(model.displayBuckets) }
                    .keyboardShortcut("e", modifiers: [.command, .option])
            }
            // Die Zwischenablage-Gruppe wird **ersetzt**, nicht ergaenzt:
            // macOS' eigenes „Select All" verarbeitet ⌘A im Menue, bevor die
            // Ansicht den Tastendruck sieht – ein zusaetzlicher Eintrag bliebe
            // wirkungslos. Ausschneiden/Kopieren/Einsetzen muessen deshalb selbst
            // bereitgestellt werden, sonst funktionierten sie im Suchfeld nicht.
            CommandGroup(replacing: .pasteboard) {
                Button("Ausschneiden") { sendToResponder("cut:") }
                    .keyboardShortcut("x", modifiers: .command)
                Button("Kopieren") { sendToResponder("copy:") }
                    .keyboardShortcut("c", modifiers: .command)
                Button("Einsetzen") { sendToResponder("paste:") }
                    .keyboardShortcut("v", modifiers: .command)
                Divider()
                Button("Alles auswählen") {
                    // Im Textfeld weiterhin den Text auswaehlen, sonst die Dateien.
                    if NSApp.keyWindow?.firstResponder is NSText {
                        sendToResponder("selectAll:")
                    } else {
                        model.selectAllVisibleFiles()
                    }
                }
                .keyboardShortcut("a", modifiers: .command)
                Button("Auswahl aufheben") { model.clearSelection() }
                    .keyboardShortcut("a", modifiers: [.command, .shift])
                    .disabled(model.selectedFiles.isEmpty)
            }
            CommandGroup(replacing: .help) {
                HelpMenuButton()
            }
        }

        // Kurzansicht in der Menueleiste – der Kern von „taeglicher Begleiter":
        // Die haeufigste Frage („woran habe ich zuletzt gearbeitet?") soll ohne
        // Fensterwechsel beantwortet sein.
        MenuBarExtra("activities", systemImage: "clock.badge.checkmark") {
            MenuBarHost(model: model)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(model: model)
        }

        Window("Über activities", id: "about") {
            AboutView()
        }
        .windowResizability(.contentSize)

        Window("activities Hilfe", id: "help") {
            HelpView()
        }
        .defaultSize(width: 560, height: 680)
    }
}

/// Inhalt des Hauptfensters.
///
/// **Warum eine eigene Ansicht und nicht direkt in ``ActivitiesApp``?**
/// `@Environment` ist im `App`-Typ nur fuer wenige Werte zugesichert;
/// `openWindow` gehoert nicht dazu. In einer echten Ansicht ist der Wert
/// garantiert vorhanden. Zugleich meldet die Ansicht hier ihr Fenster an
/// ``MainWindow`` – dort, wo es zweifelsfrei bekannt ist.
private struct MainWindowHost: View {
    @Bindable var model: ReportViewModel
    var updates: UpdateChecker
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        RootView(model: model, updates: updates)
            .frame(minWidth: 820, minHeight: 560)
            .background(WindowReader())
            .onAppear {
                AppPresence.setDockIconVisible(model.showsDockIcon)
                GlobalHotKey.register { MainWindow.show(openWindow) }
            }
    }
}

/// Inhalt der Menueleisten-Kurzansicht.
///
/// Reicht ``MenuBarView`` die Fensteraktion herein, statt sie dort aus dem
/// Environment zu holen – aus demselben Grund wie ``MainWindowHost``, und damit
/// ``MenuBarView`` selbst nichts ueber Fenster wissen muss.
private struct MenuBarHost: View {
    @Bindable var model: ReportViewModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        MenuBarView(model: model, openMainWindow: { MainWindow.show(openWindow) })
    }
}

/// Menuepunkt „activities Hilfe" (oeffnet das Hilfe-Fenster).
private struct HelpMenuButton: View {
    @Environment(\.openWindow) private var openWindow
    var body: some View {
        Button("activities Hilfe") { openWindow(id: "help") }
            .keyboardShortcut("?", modifiers: .command)
    }
}

/// Menuepunkt „Über activities" (oeffnet das Ueber-Fenster).
private struct AboutMenuButton: View {
    @Environment(\.openWindow) private var openWindow
    var body: some View {
        Button("Über activities") { openWindow(id: "about") }
    }
}

/// Ueber-Fenster mit Versions- und Build-Informationen.
struct AboutView: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.tint)
            Text("activities")
                .font(.title2).bold()
            Text(BuildInfo.short)
                .font(.callout)
                .textSelection(.enabled)
            Text(BuildInfo.details)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .textSelection(.enabled)
            Button("Version kopieren") { ClipboardService.copy(BuildInfo.details) }
                .padding(.top, 2)
            Text("designed by matthias.riedel.dresden")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .padding(.top, 4)
        }
        .padding(24)
        .frame(width: 340)
    }
}
