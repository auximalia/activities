import SwiftUI
import UniformTypeIdentifiers

/// Steuerleiste: Ordnerwahl (mit zuletzt genutzten), Zeitraum-Presets, Filter,
/// Auto-Refresh und "Aktualisieren".
struct ControlsView: View {
    @Bindable var model: ReportViewModel
    @State private var showImporter = false
    @FocusState private var filterFocused: Bool

    var body: some View {
        HStack(spacing: 12) {
            folderMenu

            Divider().frame(height: 18)

            Picker("", selection: Binding(
                get: { model.days },
                set: { model.days = $0 }
            )) {
                Text("7").tag(7)
                Text("30").tag(30)
                Text("90").tag(90)
            }
            .pickerStyle(.segmented)
            .fixedSize()
            .help("Zeitraum in Tagen")

            Stepper(value: $model.days, in: 1...3650) {
                Text("\(model.days) Tage").monospacedDigit()
            }
            .fixedSize()

            TextField("Filter, z. B. *Studium*.xls*", text: $model.namePattern)
                .textFieldStyle(.roundedBorder)
                .frame(minWidth: 180, maxWidth: 300)
                .focused($filterFocused)
                .onSubmit { model.rescan() }

            Button {
                model.rescan()
            } label: {
                Label("Aktualisieren", systemImage: "arrow.clockwise")
            }
            .keyboardShortcut("r", modifiers: .command)

            Toggle(isOn: Binding(
                get: { model.allExpanded },
                set: { model.setAllExpanded($0) }
            )) {
                Image(systemName: "chevron.up.chevron.down")
            }
            .toggleStyle(.switch)
            .controlSize(.mini)
            .help("Alle Ordner auf- oder zuklappen")

            Toggle(isOn: Binding(
                get: { model.autoRefresh },
                set: { model.setAutoRefresh($0) }
            )) {
                Image(systemName: "arrow.triangle.2.circlepath")
            }
            .toggleStyle(.switch)
            .controlSize(.mini)
            .help("Automatisch aktualisieren, wenn sich der Ordner aendert")

            if model.isScanning {
                ProgressView().controlSize(.small)
            }

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 1) {
                Text("designed by matthias.riedel.dresden")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Text(BuildInfo.short)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .help(BuildInfo.details)
            }
        }
        .padding(10)
        .onChange(of: model.days) { _, _ in model.rescan() }
        .onChange(of: model.filterFocusToken) { _, _ in filterFocused = true }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                model.setRoot(url)
            }
        }
    }

    private var folderMenu: some View {
        Menu {
            Button("Ordner wählen …") { showImporter = true }
            if !model.recentFolders.isEmpty {
                Divider()
                Section("Zuletzt genutzt") {
                    ForEach(model.recentFolders, id: \.self) { url in
                        Button(url.lastPathComponent) { model.setRoot(url) }
                            .help(url.path)
                    }
                }
            }
        } label: {
            Label(model.rootURL.lastPathComponent, systemImage: "folder")
                .lineLimit(1)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help(model.rootURL.path)
    }
}
