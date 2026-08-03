import SwiftUI
import Charts
import ActivitiesCore

/// Gestapeltes Balkendiagramm mit klickbarer Legende (Kategorien ein-/ausblenden).
///
/// Wochenenden sind hell hinterlegt. Beschriftet werden Montag und Freitag mit
/// Wochentags-Kuerzel und kurzem Datum. Ein Klick auf das Diagramm meldet den
/// getroffenen Tag zurueck.
struct HistoryChartView: View {
    let dayCounts: [DayCount]
    let presentCategories: [FileCategory]
    let hiddenCategories: Set<FileCategory>
    let topExtensions: [ExtensionCount]
    let hiddenExtensions: Set<String>
    var onSelectDay: (Date) -> Void
    var onToggleCategory: (FileCategory) -> Void
    var onToggleExtension: (String) -> Void

    private var points: [ChartPoint] {
        var result: [ChartPoint] = []
        for dayCount in dayCounts {
            for category in FileCategory.allCases {
                if let count = dayCount.countsByCategory[category], count > 0 {
                    result.append(ChartPoint(day: dayCount.day, category: category, count: count))
                }
            }
        }
        return result
    }

    private var weekendDays: [Date] {
        let calendar = Calendar.current
        return dayCounts.map(\.day).filter { calendar.isDateInWeekend($0) }
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
                .foregroundStyle(by: .value("Kategorie", point.category.displayName))
            }
        }
        .chartForegroundStyleScale(domain: ChartStyle.domain, range: ChartStyle.range)
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

    private var legend: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 12) {
                ForEach(presentCategories, id: \.self) { category in
                    categoryChip(category)
                }
                Spacer(minLength: 0)
            }
            if !topExtensions.isEmpty {
                HStack(spacing: 10) {
                    ForEach(topExtensions) { item in
                        extensionChip(item)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(.horizontal, 4)
    }

    private func categoryChip(_ category: FileCategory) -> some View {
        let isHidden = hiddenCategories.contains(category)
        return Button {
            onToggleCategory(category)
        } label: {
            HStack(spacing: 5) {
                Circle()
                    .fill(category.color)
                    .frame(width: 9, height: 9)
                Text(category.displayName)
                    .font(.caption)
            }
            .opacity(isHidden ? 0.35 : 1)
            .strikethrough(isHidden, color: .secondary)
        }
        .buttonStyle(.plain)
        .help(isHidden ? "Einblenden" : "Ausblenden")
    }

    private func extensionChip(_ item: ExtensionCount) -> some View {
        let isHidden = hiddenExtensions.contains(item.ext)
        return Button {
            onToggleExtension(item.ext)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "doc")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
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
        max(dayCounts.map(\.total).max() ?? 0, 1)
    }

    /// Beschriftet Montag und Freitag (bei kurzen Zeitraeumen jeden Tag).
    private func shouldLabel(_ date: Date) -> Bool {
        guard !dayCounts.isEmpty else { return false }
        if dayCounts.count <= 8 { return true }
        let weekday = Calendar.current.component(.weekday, from: date)
        return weekday == 2 || weekday == 6
    }
}

/// Ein Datenpunkt fuer einen Tag und eine Kategorie.
private struct ChartPoint: Identifiable {
    let id = UUID()
    let day: Date
    let category: FileCategory
    let count: Int
}
