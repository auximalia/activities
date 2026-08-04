import SwiftUI
import ActivitiesCore

/// Eine Dateizeile in der Detailansicht.
///
/// Klick auf die Zeile markiert sie. Ein Klick auf das **Datei-Symbol** markiert
/// sie und oeffnet die Datei mit der Standard-App.
struct FileRowView: View {
    let file: RelevantFile
    @Bindable var model: ReportViewModel
    /// Ob diese Datei dem Ordner sein Datum stiftet (juengste sichtbare Datei).
    /// Datumstiftende Dateien werden fett dargestellt.
    var isDateSource: Bool = true

    private var isSelected: Bool { model.selection == .file(file.url) }

    var body: some View {
        HStack(spacing: 8) {
            Button {
                model.select(.file(file.url))
                FinderService.open(file.url)
            } label: {
                Image(nsImage: FileIconProvider.icon(for: file.url))
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 18, height: 18)
                    .padding(2)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Mit Standard-App öffnen")
            .accessibilityLabel("Mit Standard-App öffnen")

            Text(file.url.lastPathComponent)
                .font(.callout)
                .fontWeight(isDateSource ? .bold : .regular)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
            Text(DateFormatting.dateTime(file.timestamp))
                .font(.system(.callout, design: .monospaced))
                .fontWeight(isDateSource ? .bold : .regular)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 8)
        .background(SelectionBackground(isActive: isSelected, cornerRadius: 6))
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            model.select(.file(file.url))
            FinderService.open(file.url)
        }
        .onTapGesture {
            model.select(.file(file.url))
        }
        .contextMenu {
            Button("Öffnen") { FinderService.open(file.url) }
            Button("Im Finder anzeigen") { FinderService.reveal(file.url) }
            Button("Pfad kopieren") { ClipboardService.copy(file.url.path) }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Datei \(file.url.lastPathComponent)")
        .accessibilityValue(DateFormatting.dateTime(file.timestamp))
        .accessibilityHint("Zum Öffnen aktivieren")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction {
            model.select(.file(file.url))
            FinderService.open(file.url)
        }
    }
}
