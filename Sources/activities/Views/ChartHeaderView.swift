import SwiftUI
import ActivitiesCore

/// Feste Kopfzone über der Tabelle: Diagramm, Legende und der Hinweis auf
/// ausgeblendete Dateitypen.
///
/// **Warum fest statt mitscrollend?** Legende und Diagramm sind Bedienelemente,
/// keine Inhalte. Scrollten sie weg, müsste man zum Aus-/Einblenden eines Typs
/// erst wieder nach oben – bei langen Listen unzumutbar.
///
/// **Warum einklappbar?** Die Kopfzone kostet dauerhaft senkrechten Platz. Bei
/// kleinen Fenstern bliebe sonst zu wenig für die Tabelle übrig.
struct ChartHeaderView: View {
    @Bindable var model: ReportViewModel

    /// Höhe des Diagramms. Bewusst kompakter als früher (260), damit die feste
    /// Kopfzone auch bei kleiner Fensterhöhe genügend Raum für die Liste lässt.
    private static let chartHeight: CGFloat = 180

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if model.headerExpanded {
                HistoryChartView(
                    chartDays: model.chartDays,
                    topExtensions: model.topExtensions,
                    hiddenExtensions: model.hiddenExtensions,
                    otherCount: model.otherCount,
                    otherKey: ReportViewModel.otherKey,
                    onSelect: { day, ext in model.focus(day: day, ext: ext) },
                    onToggleExtension: { model.toggleExtension($0) },
                    onSoloExtension: { model.soloExtension($0) },
                    colorAssignment: model.typeColorAssignment
                )
                .frame(height: Self.chartHeight)
                .padding(.horizontal, 4)
                .padding(.top, 6)
                .padding(.bottom, 8)
            }

            filterIndicator
            collapseBar
        }
        .background(.bar)
    }

    /// Schmale Leiste zum Auf-/Zuklappen; zeigt eingeklappt eine Kurzfassung.
    private var collapseBar: some View {
        HStack(spacing: 6) {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
                    model.setHeaderExpanded(!model.headerExpanded)
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: model.headerExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                    Text(model.headerExpanded ? "Diagramm ausblenden" : "Diagramm einblenden")
                        .font(.caption)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Kopfzone auf- oder zuklappen – eingeklappt bleibt mehr Platz für die Liste")

            if !model.headerExpanded && !model.topExtensions.isEmpty {
                Text("·").foregroundStyle(.tertiary)
                Text(collapsedSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
    }

    /// Kurzfassung der Legende für den eingeklappten Zustand.
    private var collapsedSummary: String {
        let names = model.topExtensions.prefix(4).map { ".\($0.ext)" }.joined(separator: ", ")
        let rest = model.topExtensions.count - min(4, model.topExtensions.count)
        return rest > 0 ? "\(names) +\(rest)" : names
    }

    /// Hinweis auf ausgeblendete Dateitypen samt Zurücksetzen.
    ///
    /// Ohne diesen Hinweis wäre der Typ-Filter ein **stiller Zustand**: Die
    /// Ergebnisliste wirkt unvollständig, ohne dass erkennbar ist, warum.
    @ViewBuilder
    private var filterIndicator: some View {
        if model.hasTypeFilter {
            let count = model.hiddenTypeCount
            HStack(spacing: 6) {
                Image(systemName: "line.3.horizontal.decrease.circle.fill")
                    .foregroundStyle(.tint)
                Text("\(count) \(count == 1 ? "Typ" : "Typen") ausgeblendet")
                    .font(.callout)
                Button("Zurücksetzen") { model.resetTypeFilters() }
                    .buttonStyle(.link)
                    .help("Alle Dateitypen wieder einblenden (⌥⌘R)")
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color.accentColor.opacity(0.10))
            )
            .padding(.horizontal, 4)
            .padding(.bottom, 4)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(count) Dateitypen ausgeblendet")
            .accessibilityHint("Zum Zurücksetzen aktivieren")
        }
    }
}
