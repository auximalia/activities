import SwiftUI
import AppKit
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
    /// Platz, den die Y-Achsenbeschriftung des Diagramms links einnimmt.
    private static let yAxisGutter: CGFloat = 38

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headline
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
                    colorAssignment: model.typeColorAssignment,
                    granularity: model.chartGranularity,
                    onRangeSelect: { from, to in model.selectRange(from: from, to: to) }
                )
                .frame(height: Self.chartHeight)
                .padding(.horizontal, 4)
                .padding(.top, 6)
                .padding(.bottom, 8)
            }

            filterIndicator
            noiseIndicator
        }
        .background(.bar)
    }

    /// Zeitraum als **Überschrift direkt über dem Diagramm**, linksbündig.
    ///
    /// Der Zeitraum beschriftet das Diagramm – ohne ihn sind die Balken nicht
    /// deutbar. Er gehört deshalb in dessen unmittelbare Nähe und **nicht** in
    /// die Titelleiste (dort stand er in v1.8.x; Gesetz der Nähe).
    /// Bleibt auch **eingeklappt** sichtbar, weil die Information dann erst
    /// recht gebraucht wird.
    private var headline: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(rangeHeadline)
                .font(.title3)
                .fontWeight(.semibold)
                .lineLimit(1)
                .truncationMode(.tail)
                .help("Aktuell angezeigter Zeitraum")

            if !model.headerExpanded && !model.topExtensions.isEmpty {
                Text(collapsedSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer(minLength: 8)
            collapseButton
        }
        // Links so weit einruecken, dass die Ueberschrift rechts neben der
        // Y-Achsenbeschriftung des Diagramms beginnt – sonst stossen „30" und
        // der Anfang der Ueberschrift optisch aneinander.
        .padding(.leading, Self.yAxisGutter)
        .padding(.trailing, 8)
        .padding(.top, 6)
        .padding(.bottom, model.headerExpanded ? 0 : 6)
    }

    /// Zeitraum ausgeschrieben, z. B. „Mi., 08.07.2026 – Do., 06.08.2026 · 30 Tage".
    /// Über dem Diagramm ist Platz für die Langfassung mit Wochentagen.
    private var rangeHeadline: String {
        let start = DateFormatting.weekdayDate(model.displayRangeStart)
        let end = DateFormatting.weekdayDate(model.displayRangeEnd)
        let days = model.displayRangeDayCount
        return "\(start) – \(end) · \(days) \(days == 1 ? "Tag" : "Tage")"
    }

    /// Auf-/Zuklappen – sitzt rechts in der Überschriftzeile.
    private var collapseButton: some View {
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
    }

    /// Kurzfassung der Legende für den eingeklappten Zustand.
    private var collapsedSummary: String {
        let names = model.topExtensions.prefix(4).map { ".\($0.ext)" }.joined(separator: ", ")
        let rest = model.topExtensions.count - min(4, model.topExtensions.count)
        return rest > 0 ? "\(names) +\(rest)" : names
    }

    /// Offenlegung, wie viel der Rauschfilter ausgeblendet hat.
    ///
    /// **Ausschlüsse dürfen kein stiller Zustand sein** (Lehre aus UX-06): Wer
    /// nicht sieht, dass etwas fehlt, hält die Auswertung für vollständig.
    @ViewBuilder
    private var noiseIndicator: some View {
        if model.skippedFolderCount > 0 || !model.excludedPaths.isEmpty {
            HStack(spacing: 6) {
                Image(systemName: "eye.slash")
                    .foregroundStyle(.secondary)
                Text(noiseText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Einstellungen …") {
                    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                }
                .buttonStyle(.link)
                .font(.caption)
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 4)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(noiseText)
        }
    }

    private var noiseText: String {
        var teile: [String] = []
        if model.skippedFolderCount > 0 {
            teile.append("\(model.skippedFolderCount) Ordner als Werkzeug-Erzeugnis übersprungen")
        }
        if !model.excludedPaths.isEmpty {
            let n = model.excludedPaths.count
            teile.append("\(n) \(n == 1 ? "Ordner" : "Ordner") von dir ausgeblendet")
        }
        return teile.joined(separator: " · ")
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
