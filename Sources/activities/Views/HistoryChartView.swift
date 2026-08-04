import SwiftUI
import Charts
import AppKit
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
        VStack(spacing: 8) {
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
                                .foregroundStyle(.primary)
                            Text(DateFormatting.dayMonth(date))
                                .font(.system(size: 10))
                                .fontWeight(.medium)
                                .foregroundStyle(.primary)
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
                    .help("Klick auf ein Balken-Segment springt zur passenden Datei")
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
        FlowLayout(horizontalSpacing: 6, verticalSpacing: 6) {
            ForEach(topExtensions) { item in
                LegendChip(
                    color: IconColor.dominant(forExtension: item.ext),
                    icon: FileIconProvider.icon(forExtension: item.ext),
                    title: ".\(item.ext)",
                    monospacedTitle: true,
                    count: item.count,
                    isHidden: hiddenExtensions.contains(item.ext),
                    onToggle: { onToggleExtension(item.ext) },
                    onSolo: { onSoloExtension(item.ext) }
                )
            }
            if hasOther {
                LegendChip(
                    color: otherColor,
                    icon: nil,
                    title: "Sonstige",
                    monospacedTitle: false,
                    count: otherCount,
                    isHidden: hiddenExtensions.contains(otherKey),
                    onToggle: { onToggleExtension(otherKey) },
                    onSolo: { onSoloExtension(otherKey) }
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
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

/// Ein klickbarer Legendeneintrag im Button-Look: Farbfeld, optionales Icon,
/// Name und Anzahl in einer umrandeten „Pille" mit Hover-Highlight und
/// Zeigehand-Cursor. Einfachklick = Toggle, Doppelklick = „Solo".
private struct LegendChip: View {
    let color: Color
    let icon: NSImage?
    let title: String
    let monospacedTitle: Bool
    let count: Int
    let isHidden: Bool
    let onToggle: () -> Void
    let onSolo: () -> Void

    @State private var hovering = false

    var body: some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 12, height: 12)
            if let icon {
                Image(nsImage: icon)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 16, height: 16)
            }
            Text(title)
                .font(monospacedTitle ? .system(.caption, design: .monospaced) : .caption)
            Text("\(count)")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .opacity(isHidden ? 0.4 : 1)
        .strikethrough(isHidden, color: .secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Color.secondary.opacity(hovering ? 0.20 : 0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .strokeBorder(Color.secondary.opacity(isHidden ? 0.25 : 0.45), lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .onTapGesture(count: 2) { onSolo() }
        .onTapGesture(count: 1) { onToggle() }
        .onHover { inside in
            hovering = inside
            if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
        .help(isHidden
              ? "Einblenden · Doppelklick: nur diesen"
              : "Ausblenden · Doppelklick: nur diesen")
    }
}

/// Linksbuendiges Flow-Layout: ordnet die Elemente dicht nebeneinander an und
/// bricht bei Platzmangel in die naechste Zeile um. Feste, kleine Abstaende –
/// keine gestreckten Spalten wie bei einem adaptiven Grid.
struct FlowLayout: Layout {
    var horizontalSpacing: CGFloat = 6
    var verticalSpacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalWidth: CGFloat = 0
        var totalHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if rowWidth > 0, rowWidth + horizontalSpacing + size.width > maxWidth {
                totalWidth = max(totalWidth, rowWidth)
                totalHeight += rowHeight + verticalSpacing
                rowWidth = size.width
                rowHeight = size.height
            } else {
                rowWidth += (rowWidth > 0 ? horizontalSpacing : 0) + size.width
                rowHeight = max(rowHeight, size.height)
            }
        }
        totalWidth = max(totalWidth, rowWidth)
        totalHeight += rowHeight
        return CGSize(width: min(totalWidth, maxWidth), height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + verticalSpacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: ProposedViewSize(size))
            x += size.width + horizontalSpacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
