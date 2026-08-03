import SwiftUI
import UniformTypeIdentifiers

/// Steuerleiste: Ordnerwahl, Zeitraum, Namensfilter und "Aktualisieren".
struct ControlsView: View {
    @Bindable var model: ReportViewModel
    @State private var showImporter = false

    var body: some View {
        HStack(spacing: 12) {
            Button {
                showImporter = true
            } label: {
                Label(model.rootURL.lastPathComponent, systemImage: "folder")
                    .lineLimit(1)
            }
            .help(model.rootURL.path)

            Divider().frame(height: 18)

            Stepper(value: $model.days, in: 1...3650) {
                Text("\(model.days) Tage").monospacedDigit()
            }
            .fixedSize()
            .onChange(of: model.days) { _, _ in model.rescan() }

            TextField("Filter, z. B. *Studium*.xls*", text: $model.namePattern)
                .textFieldStyle(.roundedBorder)
                .frame(minWidth: 200, maxWidth: 320)
                .onSubmit { model.rescan() }

            Button {
                model.rescan()
            } label: {
                Label("Aktualisieren", systemImage: "arrow.clockwise")
            }
            .keyboardShortcut("r", modifiers: .command)

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
}
