import SwiftUI
import ActivitiesCore

/// Eine Dateizeile in der Detailansicht.
///
/// Klick auf die Zeile markiert sie. Ein Klick auf das **Datei-Symbol** oeffnet
/// die Datei mit der Standard-App.
struct FileRowView: View {
    let file: RelevantFile
    @Bindable var model: ReportViewModel

    private var isSelected: Bool { model.selectedFile == file.url }

    var body: some View {
        HStack(spacing: 8) {
            // Datei-Symbol = Aktion: mit Standard-App oeffnen.
            Button {
                model.selectedFile = file.url
                FinderService.open(file.url)
            } label: {
                Image(systemName: "doc")
                    .foregroundStyle(.secondary)
                    .padding(2)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Mit Standard-App öffnen")

            Text(file.url.lastPathComponent)
                .font(.callout)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
            Text(DateFormatting.dateTime(file.timestamp))
                .font(.system(.callout, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 8)
        .background(SelectionBackground(isActive: isSelected, cornerRadius: 6))
        .contentShape(Rectangle())
        .onTapGesture {
            model.selectedFile = file.url
        }
        .contextMenu {
            Button("Öffnen") { FinderService.open(file.url) }
            Button("Im Finder anzeigen") { FinderService.reveal(file.url) }
            Button("Pfad kopieren") { ClipboardService.copy(file.url.path) }
        }
    }
}
