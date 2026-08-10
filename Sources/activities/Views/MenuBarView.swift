import SwiftUI
import ActivitiesCore

/// Kurzansicht in der Menüleiste: die zuletzt bearbeiteten Ordner auf einen Blick.
///
/// **Zweck:** Die Hürde senken von „App öffnen" auf „hinsehen". Der häufigste
/// Fall – *woran habe ich zuletzt gearbeitet?* – soll ohne Fensterwechsel
/// beantwortet sein.
///
/// Die Liste stammt aus ``ReportViewModel/mostRecentFolders(limit:)`` und
/// unterliegt damit denselben Filtern wie das Fenster. Eine Kurzansicht, die
/// etwas anderes zeigt als die Hauptansicht, wäre schlimmer als keine.
struct MenuBarView: View {
    @Bindable var model: ReportViewModel
    var openMainWindow: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            Divider()

            if model.isScanning && !model.hasScanResults {
                label("Suche läuft …")
            } else {
                let folders = model.mostRecentFolders()
                if folders.isEmpty {
                    label("Im gewählten Zeitraum wurde nichts bearbeitet.")
                } else {
                    ForEach(folders) { entry in
                        Button {
                            FinderService.open(entry.folder)
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "folder.fill")
                                    .foregroundStyle(.tint)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(entry.folder.lastPathComponent)
                                        .lineLimit(1)
                                    Text(DateFormatting.dateTimeCompact(entry.newestDate))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 8)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .help("Im Finder öffnen: \(entry.folder.path)")
                    }
                }
            }

            Divider()

            Button("Fenster öffnen", action: openMainWindow)
                .buttonStyle(.plain)
                .padding(.horizontal, 12).padding(.vertical, 6)
            Button("Aktualisieren") { model.rescan() }
                .buttonStyle(.plain)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .disabled(model.isScanning)
            Divider()
            Button("activities beenden") { NSApplication.shared.terminate(nil) }
                .buttonStyle(.plain)
                .padding(.horizontal, 12).padding(.vertical, 6)
        }
        .padding(.vertical, 6)
        .frame(width: 300)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(model.sourcesLabel)
                .font(.headline)
                .lineLimit(1)
            Text("Zuletzt bearbeitet")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 6)
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .font(.callout)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .fixedSize(horizontal: false, vertical: true)
    }
}
