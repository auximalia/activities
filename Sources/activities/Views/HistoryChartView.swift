import SwiftUI
import Charts
import ActivitiesCore

/// Gestapeltes Balkendiagramm: bearbeitete Dateien je Tag, nach Kategorie gefaerbt.
///
/// Wochenenden sind hell hinterlegt. Ein Klick auf das Diagramm meldet den
/// getroffenen Tag zurueck (fuer den Sprung in die Liste).
struct HistoryChartView: View {
    let dayCounts: [DayCount]
    var onSelectDay: (Date) -> Void

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
        .chartLegend(position: .bottom, spacing: 8)
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
        .chartYAxis {
            AxisMarks(position: .leading)
        }
        .chartOverlay { proxy in
            GeometryReader { geometry in
                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .onTapGesture { location in
                        guard let plotFrame = proxy.plotFrame else { return }
                        let origin = geometry[plotFrame].origin
                        let x = location.x - origin.x
                        if let day: Date = proxy.value(atX: x) {
                            onSelectDay(day)
                        }
                    }
            }
        }
    }

    private var maxTotal: Int {
        max(dayCounts.map(\.total).max() ?? 0, 1)
    }

    /// Beschriftet Montag und Freitag (bei kurzen Zeitraeumen jeden Tag).
    private func shouldLabel(_ date: Date) -> Bool {
        guard !dayCounts.isEmpty else { return false }
        if dayCounts.count <= 8 { return true }
        let weekday = Calendar.current.component(.weekday, from: date)
        return weekday == 2 || weekday == 6 // Montag oder Freitag
    }
}

/// Ein Datenpunkt fuer einen Tag und eine Kategorie.
private struct ChartPoint: Identifiable {
    let id = UUID()
    let day: Date
    let category: FileCategory
    let count: Int
}
