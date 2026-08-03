import SwiftUI
import ActivitiesCore

/// Eine Ordnerzeile mit aufklappbarer Detailansicht.
///
/// Klick auf die Zeile klappt die Dateien auf/zu. Ein Klick auf das
/// **Ordner-Symbol** oeffnet den Ordner im Finder (und kopiert den Pfad).
struct FolderRowView: View {
    let entry: FolderEntry
    @Bindable var model: ReportViewModel
    /// Hervorhebung, wenn dieser Ordner das Ziel eines Diagramm-Klicks ist.
    var isHighlighted: Bool = false

    @State private var isExpanded = false
    @State private var files: [RelevantFile] = []
    @State private var didLoad = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 12)

                // Ordner-Symbol = Aktion: im Finder oeffnen (+ Pfad kopieren).
                Button {
                    FinderService.open(entry.folder)
                    ClipboardService.copy(entry.folder.path)
                } label: {
                    Image(systemName: "folder.fill")
                        .foregroundStyle(.tint)
                        .padding(2)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Im Finder öffnen · Pfad kopieren")

                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.folder.lastPathComponent)
                        .font(.headline)
                    Text(entry.folder.path)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(DateFormatting.dateTime(entry.newestDate))
                        .font(.system(.callout, design: .monospaced))
                    Text("\(entry.fileCount) \(entry.fileCount == 1 ? "Datei" : "Dateien")")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 5)
            .padding(.horizontal, 8)
            .background(SelectionBackground(isActive: isHighlighted))
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
            }
            .contextMenu {
                Button("Im Finder öffnen") { FinderService.open(entry.folder) }
                Button("Im Finder anzeigen") { FinderService.reveal(entry.folder) }
                Button("Pfad kopieren") { ClipboardService.copy(entry.folder.path) }
            }

            if isExpanded {
                detailList
                    .padding(.leading, 26)
                    .padding(.top, 2)
            }
        }
        .onChange(of: isExpanded) { _, expanded in
            if expanded && !didLoad { loadFiles() }
        }
        // Ziel eines Diagramm-Klicks: Ordner automatisch aufklappen und Dateien zeigen.
        .onChange(of: isHighlighted, initial: true) { _, highlighted in
            if highlighted && !isExpanded {
                withAnimation { isExpanded = true }
            }
        }
    }

    @ViewBuilder
    private var detailList: some View {
        if !didLoad {
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("Lade Dateien …").font(.caption).foregroundStyle(.secondary)
            }
        } else if files.isEmpty {
            Text("Keine passenden Dateien in diesem Ordner.")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            ForEach(files) { file in
                FileRowView(file: file, model: model)
            }
        }
    }

    private func loadFiles() {
        Task {
            let loaded = await model.loadFiles(for: entry.folder)
            files = loaded
            didLoad = true
        }
    }
}
