import SwiftUI
import ActivitiesCore

/// Eine Dateizeile in der Detailansicht. Klick oeffnet die Datei mit der
/// Standard-App und markiert die Zeile.
struct FileRowView: View {
    let file: RelevantFile
    @Bindable var model: ReportViewModel

    private var isSelected: Bool { model.selectedFile == file.url }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "doc")
                .foregroundStyle(isSelected ? Color.white : Color.secondary)
            Text(file.url.lastPathComponent)
                .font(.callout)
                .lineLimit(1)
                .truncationMode(.middle)
                .foregroundStyle(isSelected ? Color.white : Color.primary)
            Spacer()
            Text(DateFormatting.dateTime(file.timestamp))
                .font(.system(.callout, design: .monospaced))
                .foregroundStyle(isSelected ? Color.white.opacity(0.9) : Color.secondary)
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(isSelected ? Color.accentColor : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            model.selectedFile = file.url
            FinderService.open(file.url)
        }
        .contextMenu {
            Button("Oeffnen") { FinderService.open(file.url) }
            Button("Im Finder anzeigen") { FinderService.reveal(file.url) }
            Button("Pfad kopieren") { ClipboardService.copy(file.url.path) }
        }
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}
