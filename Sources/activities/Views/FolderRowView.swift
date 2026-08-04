import SwiftUI
import ActivitiesCore

/// Kopfzeile eines Ordners in der flachen Liste.
///
/// Klick auf die Zeile klappt die Dateien auf/zu, markiert den Ordner und
/// **kopiert den Ordnerpfad** in die Zwischenablage. Ein Klick auf das
/// **Ordner-Symbol** markiert ihn und oeffnet ihn im Finder (+ kopiert den Pfad).
struct FolderRowView: View {
    let entry: FolderEntry
    @Bindable var model: ReportViewModel

    private var isExpanded: Bool { model.isExpanded(entry.folder) }
    private var isSelected: Bool { model.selection == .folder(entry.folder) }

    /// Live berechnetes Ordner-Datum (juengste sichtbare Datei) – filterabhaengig.
    private var displayDate: Date { model.newestVisibleDate(in: entry.folder) ?? entry.newestDate }
    /// Live berechnete Anzahl sichtbarer Dateien.
    private var displayCount: Int {
        let live = model.visibleFileCount(in: entry.folder)
        return live > 0 ? live : entry.fileCount
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 12)

            Button {
                model.select(.folder(entry.folder))
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
            .accessibilityLabel("Ordner im Finder öffnen")

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
                Text(DateFormatting.dateTime(displayDate))
                    .font(.system(.callout, design: .monospaced))
                Text("\(displayCount) \(displayCount == 1 ? "Datei" : "Dateien")")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 8)
        .background(SelectionBackground(isActive: isSelected))
        .contentShape(Rectangle())
        .help("Klick: auf-/zuklappen & Pfad kopieren · Doppelklick: im Finder öffnen")
        .onTapGesture(count: 2) {
            model.select(.folder(entry.folder))
            FinderService.open(entry.folder)
            ClipboardService.copy(entry.folder.path)
        }
        .onTapGesture {
            model.select(.folder(entry.folder))
            ClipboardService.copy(entry.folder.path)
            withAnimation(.easeInOut(duration: 0.2)) { model.toggleExpand(entry.folder) }
        }
        .contextMenu {
            Button("Im Finder öffnen") { FinderService.open(entry.folder) }
            Button("Im Finder anzeigen") { FinderService.reveal(entry.folder) }
            Button("Pfad kopieren") { ClipboardService.copy(entry.folder.path) }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Ordner \(entry.folder.lastPathComponent)")
        .accessibilityValue("\(entry.fileCount) Dateien, zuletzt \(DateFormatting.dateTime(entry.newestDate))")
        .accessibilityHint("Zum Auf- und Zuklappen aktivieren")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction {
            model.select(.folder(entry.folder))
            model.toggleExpand(entry.folder)
        }
    }
}
