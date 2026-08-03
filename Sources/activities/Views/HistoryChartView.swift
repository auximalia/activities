import SwiftUI
import Charts
import ActivitiesCore

/// Gestapeltes Balkendiagramm nach Dateiendung, gefaerbt mit der dominierenden
/// Farbe des jeweiligen Datei-Icons. Klickbare Legende blendet Endungen ein/aus.
///
/// Wochenenden sind hell hinterlegt. Beschriftet werden Montag und Freitag mit
/// Wochentags-Kuerzel und kurzem Datum. Ein Klick auf das Diagramm meldet den
/// getroffenen Tag zurueck.
struct HistoryChartView: View {
    let chartDays: [DayExtensionCount]
    let topExtensions: [ExtensionCount]
    let hiddenExtensions: Set<String>
    var onSelectDay: (Date) -> Void
    var onToggleExtension: (String) -> Void

    private var extensionKeys: [String] { topExtensions.map(\.ext) }

    private var points: [ChartPoint] {
        var result: [ChartPoint] = []
        for dayCount in chartDays {
            for ext in extensionKeys {
                if let count = dayCount.counts[ext], count > 0 {
                    result.append(ChartPoint(day: dayCount.day, ext: ext, count: count))
                }
            }
        }
        return result
    }

    private var weekendDays: [Date] {
        let calendar = Calendar.current
        return chartDays.map(\.day).filter { calendar.isDateInWeekend($0) }
    }

    var body: some View {
        VStack(spacing: 6) {
            chart
            legend
        }
    }

    private var chart: some View {
        Chart {
            ForEach(weekendDays, id: \.self) { day in
                RectangleMark(
                    x: .value("Tag", day, unit: .day),
                    yStart: .value("von", 0),
                    yEnd: .value("bis", maxTotal)
                )
                .foregroundStyle(Color.secondary.opacity(0.10))
            }

            ForEach(points) { point in
                BarMark(
                    x: .value("Tag", point.day, unit: .day),
                    y: .value("Anzahl", point.count)
                )
                .foregroundStyle(by: .value("Typ", point.ext))
            }
        }
        .chartForegroundStyleScale(domain: extensionKeys, range: extensionColors)
        .chartLegend(.hidden)
        .chartXAxis {
            AxisMarks(values: .stride(by: .day)) { value in
                if let date: Date = value.as(Date.self), shouldLabel(date) {
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel {
                        VStack(spacing: 1) {
                            Text(DateFormatting.weekdayShort(date))
                                .font(.caption2)
                                .fontWeight(.semibold)
                            Text(DateFormatting.dayMonth(date))
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                        }
                        .fixedSize()
                    }
                }
            }
        }
        .chartYAxis { AxisMarks(position: .leading) }
        .chartOverlay { proxy in
            GeometryReader { geometry in
                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .onTapGesture { location in
                        guard let plotFrame = proxy.plotFrame else { return }
                        let origin = geometry[plotFrame].origin
                        if let day: Date = proxy.value(atX: location.x - origin.x) {
                            onSelectDay(day)
                        }
                    }
            }
        }
    }

    private var extensionColors: [Color] {
        extensionKeys.map { IconColor.dominant(forExtension: $0) }
    }

    private var legend: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 104), spacing: 8, alignment: .leading)],
            alignment: .leading,
            spacing: 4
        ) {
            ForEach(topExtensions) { item in
                extensionChip(item)
            }
        }
        .padding(.horizontal, 4)
    }

    private func extensionChip(_ item: ExtensionCount) -> some View {
        let isHidden = hiddenExtensions.contains(item.ext)
        return Button {
            onToggleExtension(item.ext)
        } label: {
            HStack(spacing: 5) {
                Image(nsImage: FileIconProvider.icon(forExtension: item.ext))
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 16, height: 16)
                Text(".\(item.ext)")
                    .font(.system(.caption, design: .monospaced))
                Text("\(item.count)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .opacity(isHidden ? 0.35 : 1)
            .strikethrough(isHidden, color: .secondary)
        }
        .buttonStyle(.plain)
        .help(isHidden ? "Einblenden" : "Ausblenden")
    }

    private var maxTotal: Int {
        max(chartDays.map(\.total).max() ?? 0, 1)
    }

    /// Beschriftet Montag und Freitag (bei kurzen Zeitraeumen jeden Tag).
    private func shouldLabel(_ date: Date) -> Bool {
        guard !chartDays.isEmpty else { return false }
        if chartDays.count <= 8 { return true }
        let weekday = Calendar.current.component(.weekday, from: date)
        return weekday == 2 || weekday == 6
    }
}

/// Ein Datenpunkt fuer einen Tag und eine Dateiendung.
private struct ChartPoint: Identifiable {
    let id = UUID()
    let day: Date
    let ext: String
    let count: Int
}
