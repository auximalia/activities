import SwiftUI

/// Einstiegspunkt der App: Hauptfenster, Menuebefehle und Ueber-Fenster.
@main
struct ActivitiesApp: App {
    @State private var model = ReportViewModel()
    @State private var updates = UpdateChecker()

    var body: some Scene {
        WindowGroup("activities") {
            RootView(model: model, updates: updates)
                .frame(minWidth: 1180, minHeight: 600)
        }
        .defaultSize(width: 1280, height: 780)
        // Kompakte Titelleiste: spart Hoehe gegenueber dem Standardstil, ohne
        // Bedienelemente zu verlieren.
        .windowToolbarStyle(.unifiedCompact)
        .commands {
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
                Toggle("Dateien außerhalb des Zeitraums zeigen", isOn: Binding(
                    get: { model.showOutOfWindowFiles },
                    set: { model.setShowOutOfWindowFiles($0) }
                ))
            }
            // Export gehoert ins Menue „Ablage" – dort sucht man ihn.
            CommandGroup(replacing: .saveItem) {
                Button("Als CSV exportieren …") { ExportService.exportCSV(model.displayBuckets) }
                    .keyboardShortcut("e", modifiers: .command)
                Button("Als HTML exportieren …") { ExportService.exportHTML(model.displayBuckets) }
                    .keyboardShortcut("e", modifiers: [.command, .shift])
            }
            CommandGroup(replacing: .help) {
                HelpMenuButton()
            }
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
