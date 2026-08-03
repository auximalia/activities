import SwiftUI
import ActivitiesCore

/// Eine Ordnerzeile mit aufklappbarer Detailansicht.
///
/// Primaerklick auf die Zeile oeffnet den Ordner im Finder und kopiert den Pfad.
/// Der Pfeil links klappt die Detailliste (Dateien des Ordners) auf.
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
                Button {
                    withAnimation { isExpanded.toggle() }
                } label: {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .foregroundStyle(isHighlighted ? Color.white : Color.secondary)
                        .frame(width: 16)
                }
                .buttonStyle(.plain)

                Image(systemName: "folder.fill")
                    .foregroundStyle(isHighlighted ? Color.white : Color.accentColor)

                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.folder.lastPathComponent)
                        .font(.headline)
                        .foregroundStyle(isHighlighted ? Color.white : Color.primary)
                    Text(entry.folder.path)
                        .font(.callout)
                        .foregroundStyle(isHighlighted ? Color.white.opacity(0.9) : Color.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(DateFormatting.dateTime(entry.newestDate))
                        .font(.system(.callout, design: .monospaced))
                        .foregroundStyle(isHighlighted ? Color.white : Color.primary)
                    Text("\(entry.fileCount) \(entry.fileCount == 1 ? "Datei" : "Dateien")")
                        .font(.callout)
                        .foregroundStyle(isHighlighted ? Color.white.opacity(0.9) : Color.secondary)
                }
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isHighlighted ? Color.accentColor : Color.clear)
            )
            .contentShape(Rectangle())
            .onTapGesture {
                FinderService.open(entry.folder)
                ClipboardService.copy(entry.folder.path)
            }
            .contextMenu {
                Button("Im Finder oeffnen") { FinderService.open(entry.folder) }
                Button("Im Finder anzeigen") { FinderService.reveal(entry.folder) }
                Button("Pfad kopieren") { ClipboardService.copy(entry.folder.path) }
            }

            if isExpanded {
                detailList
                    .padding(.leading, 24)
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
