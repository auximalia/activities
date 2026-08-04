import SwiftUI

/// Einstiegspunkt der App: Hauptfenster, Menuebefehle und Ueber-Fenster.
@main
struct ActivitiesApp: App {
    @State private var model = ReportViewModel()

    var body: some Scene {
        WindowGroup("activities") {
            RootView(model: model)
                .frame(minWidth: 1000, minHeight: 520)
        }
        .defaultSize(width: 980, height: 720)
        .commands {
            CommandGroup(replacing: .appInfo) {
                AboutMenuButton()
            }
            CommandGroup(after: .toolbar) {
                Button("Aktualisieren") { model.rescan() }
                    .keyboardShortcut("r", modifiers: .command)
                Button("Filter fokussieren") { model.filterFocusToken += 1 }
                    .keyboardShortcut("f", modifiers: .command)
                Divider()
                Button("Als CSV exportieren …") { ExportService.exportCSV(model.displayBuckets) }
                Button("Als HTML exportieren …") { ExportService.exportHTML(model.displayBuckets) }
            }
        }

        Window("Über activities", id: "about") {
            AboutView()
        }
        .windowResizability(.contentSize)
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
