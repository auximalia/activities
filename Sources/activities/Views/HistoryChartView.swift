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
    let otherCount: Int
    let otherKey: String
    /// Meldet Tag und (falls im Stapel getroffen) die Endung des Segments zurueck.
    var onSelect: (Date, String?) -> Void
    var onToggleExtension: (String) -> Void
    /// Doppelklick auf einen Legendeneintrag: nur diesen Typ anzeigen ("Solo").
    var onSoloExtension: (String) -> Void

    private var hasOther: Bool { otherCount > 0 }
    private var otherColor: Color { Color(nsColor: .systemGray) }

    /// Reihenfolge/Domain der Stapel: Top-Endungen, danach ggf. "Sonstige".
    private var chartKeys: [String] {
        topExtensions.map(\.ext) + (hasOther ? [otherKey] : [])
    }

    private var chartColors: [Color] {
        topExtensions.map { IconColor.dominant(forExtension: $0.ext) } + (hasOther ? [otherColor] : [])
    }

    private var points: [ChartPoint] {
        var result: [ChartPoint] = []
        for dayCount in chartDays {
            for key in chartKeys {
                if let count = dayCount.counts[key], count > 0 {
                    result.append(ChartPoint(day: dayCount.day, ext: key, count: count))
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
        .chartForegroundStyleScale(domain: chartKeys, range: chartColors)
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
                        guard let day: Date = proxy.value(atX: location.x - origin.x) else { return }
                        let value: Double? = proxy.value(atY: location.y - origin.y)
                        onSelect(day, resolveExtension(day: day, value: value))
                    }
            }
        }
    }

    /// Bestimmt aus der getroffenen Hoehe (Stapel von unten nach oben in
    /// ``chartKeys``-Reihenfolge) die Endung des angeklickten Segments.
    private func resolveExtension(day: Date, value: Double?) -> String? {
        guard let value, value > 0 else { return nil }
        let calendar = Calendar.current
        guard let dayCount = chartDays.first(where: { calendar.isDate($0.day, inSameDayAs: day) }) else {
            return nil
        }
        var cumulative = 0.0
        for key in chartKeys {
            let count = Double(dayCount.counts[key] ?? 0)
            if count <= 0 { continue }
            cumulative += count
            if value <= cumulative { return key }
        }
        return nil // ueber dem Stapel
    }

    private var legend: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 122), spacing: 8, alignment: .leading)],
            alignment: .leading,
            spacing: 4
        ) {
            ForEach(topExtensions) { item in
                extensionChip(item)
            }
            if hasOther {
                otherChip
            }
        }
        .padding(.horizontal, 4)
    }

    private func extensionChip(_ item: ExtensionCount) -> some View {
        let isHidden = hiddenExtensions.contains(item.ext)
        return HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 2)
                .fill(IconColor.dominant(forExtension: item.ext))
                .frame(width: 12, height: 12)
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
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { onSoloExtension(item.ext) }
        .onTapGesture(count: 1) { onToggleExtension(item.ext) }
        .help(isHidden
              ? "Einblenden · Doppelklick: nur diesen Typ"
              : "Ausblenden · Doppelklick: nur diesen Typ")
    }

    private var otherChip: some View {
        let isHidden = hiddenExtensions.contains(otherKey)
        return HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 2)
                .fill(otherColor)
                .frame(width: 12, height: 12)
            Text("Sonstige")
                .font(.caption)
            Text("\(otherCount)")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .opacity(isHidden ? 0.35 : 1)
        .strikethrough(isHidden, color: .secondary)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { onSoloExtension(otherKey) }
        .onTapGesture(count: 1) { onToggleExtension(otherKey) }
        .help(isHidden
              ? "Einblenden · Doppelklick: nur diese"
              : "Ausblenden · Doppelklick: nur diese")
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
    var id: String { "\(day.timeIntervalSince1970)-\(ext)" }
    let day: Date
    let ext: String
    let count: Int
}
