import SwiftUI
import AppKit
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
    /// Jede zweite Zeile bekommt einen dezenten Hintergrund (Zebra, Lesehilfe).
    var isAlternate: Bool = false
    /// Schmales Fenster: Datumsspalte kuerzer.
    var isCompact: Bool = false

    private var isSelected: Bool { model.selection == .file(file.url) }
    /// Ob die Datei im gewaehlten Zeitfenster liegt (sonst: Hinweis-Symbol).
    private var isInWindow: Bool { model.isInWindow(file) }

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
                    // Ausserhalb des Zeitraums: Icon entfaerben und leicht dimmen,
                    // damit die farbigen Icons die relevanten Treffer markieren.
                    .saturation(isInWindow ? 1 : RowMetrics.outOfWindowIconSaturation)
                    .opacity(isInWindow ? 1 : RowMetrics.outOfWindowIconOpacity)
                    .padding(2)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Mit Standard-App öffnen")
            .accessibilityLabel("Mit Standard-App öffnen")

            Text(file.url.lastPathComponent)
                .font(.callout)
                .fontWeight(isDateSource ? .bold : .regular)
                .foregroundStyle(isInWindow ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary))
                .opacity(isInWindow ? 1 : RowMetrics.outOfWindowTextOpacity)
                .lineLimit(1)
                .truncationMode(.middle)

            if !isInWindow {
                Image(systemName: "clock.badge.xmark")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .help("Außerhalb des gewählten Zeitraums – zählt nicht zum Ordnerdatum")
                    .accessibilityLabel("Außerhalb des gewählten Zeitraums")
            }

            Spacer(minLength: RowMetrics.itemSpacing)
            Text(isCompact ? DateFormatting.dateTimeCompact(file.timestamp) : DateFormatting.dateTime(file.timestamp))
                .font(.system(.callout, design: .monospaced))
                .fontWeight(isDateSource ? .bold : .regular)
                .foregroundStyle(.secondary)
                .opacity(isInWindow ? 1 : RowMetrics.outOfWindowTextOpacity)
                .lineLimit(1)
                .frame(width: RowMetrics.dateColumnWidth(compact: isCompact), alignment: .trailing)
        }
        .padding(.vertical, 3)
        .padding(.horizontal, RowMetrics.horizontalPadding)
        .background(SelectionBackground(isActive: isSelected, cornerRadius: 6))
        .background(isAlternate ? RowMetrics.zebraColor : Color.clear)
        .contentShape(Rectangle())
        // Herausziehen in andere Programme (Mail, Finder, Editor).
        //
        // **Reihenfolge ist wichtig:** `.onDrag` steht VOR der
        // Sofort-Markierungsgeste. Andernfalls verschluckt die
        // `DragGesture(minimumDistance: 0)` die Zugbewegung und das Ziehen
        // kommt nie zustande.
        .onDrag {
            model.select(.file(file.url))
            let provider = NSItemProvider(contentsOf: file.url)
                ?? NSItemProvider(object: file.url as NSURL)
            // **Ohne `suggestedName` benennt der Empfaenger die Datei nach ihrem
            // TYP** („XMind Workbook.xmind") statt nach ihrem echten Namen.
            //
            // **Ohne Endung uebergeben:** Der Empfaenger haengt die zum Typ
            // passende Endung selbst an – mit „name.xmind" entstuende
            // „name.xmind.xmind".
            provider.suggestedName = file.url.deletingPathExtension().lastPathComponent
            return provider
        } preview: {
            // Eigene Vorschau: Die Standardvorschau ist eine verkleinerte
            // Abbildung der gesamten Zeile und damit unlesbar.
            HStack(spacing: 6) {
                Image(nsImage: FileIconProvider.icon(for: file.url))
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 16, height: 16)
                Text(file.url.lastPathComponent)
                    .font(.callout)
                    .lineLimit(1)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .help("Klick: markieren · Doppelklick: öffnen · Leertaste: Vorschau · Ziehen: in andere Programme")
        // Markieren sofort beim Mausdruck: zwei konkurrierende onTapGesture
        // (count 1 und 2) wuerden SwiftUI zwingen, das Doppelklick-Intervall
        // (~300 ms) abzuwarten, bevor der Einfachklick feuert.
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isSelected { model.select(.file(file.url)) }
                }
        )
        .onTapGesture(count: 2) {
            model.select(.file(file.url))
            FinderService.open(file.url)
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
