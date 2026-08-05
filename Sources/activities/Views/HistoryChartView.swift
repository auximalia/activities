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
    /// Farbplatz je Endung (kategoriale Palette aus dem Kern).
    var colorAssignment: [String: Int]
    /// Buendelung der X-Achse (Tag/Woche/Monat).
    var granularity: ChartGranularity
    /// Aufgezogener Zeitraum (von, bis) – setzt den Zeitraum der App.
    var onRangeSelect: (Date, Date) -> Void

    /// Laufende Aufzieh-Geste (x-Positionen im Overlay).
    @State private var dragFrom: CGFloat?
    @State private var dragTo: CGFloat?

    /// Buendel unter dem Mauszeiger (Fadenkreuz + Kurzinfo).
    @State private var hoveredBucket: DayExtensionCount?
    /// Position des Zeigers im Diagramm, fuer die Platzierung der Kurzinfo.
    @State private var hoverPoint: CGPoint = .zero

    private var hasOther: Bool { otherCount > 0 }
    private var otherColor: Color { FileTypeColor.other }

    /// Reihenfolge/Domain der Stapel: Top-Endungen, danach ggf. "Sonstige".
    private var chartKeys: [String] {
        topExtensions.map(\.ext) + (hasOther ? [otherKey] : [])
    }

    private var chartColors: [Color] {
        topExtensions.map { FileTypeColor.color(forExtension: $0.ext, assignment: colorAssignment) }
            + (hasOther ? [otherColor] : [])
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

    /// Kalender-Einheit passend zur Buendelung.
    private var calendarUnit: Calendar.Component {
        switch granularity {
        case .day: .day
        case .week: .weekOfYear
        case .month: .month
        }
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
            // Wochenend-Baender ergeben nur bei Tages-Buendelung Sinn.
            ForEach(granularity == .day ? weekendDays : [], id: \.self) { day in
                RectangleMark(
                    x: .value("Tag", day, unit: .day),
                    yStart: .value("von", 0),
                    yEnd: .value("bis", maxTotal)
                )
                // Kontextschicht: bewusst dicht am Hintergrund (ΔE <= 15),
                // damit ein Wochenend-Band nie als Datenflaeche gelesen wird.
                .foregroundStyle(Color.secondary.opacity(0.06))
            }

            ForEach(points) { point in
                BarMark(
                    x: .value("Zeit", point.day, unit: calendarUnit),
                    y: .value("Anzahl", point.count)
                )
                .foregroundStyle(by: .value("Typ", point.ext))
            }
        }
        .chartForegroundStyleScale(domain: chartKeys, range: chartColors)
        .chartLegend(.hidden)
        .chartXAxis {
            AxisMarks(values: .stride(by: calendarUnit)) { value in
                if let date: Date = value.as(Date.self), shouldLabel(date) {
                    AxisGridLine().foregroundStyle(Color.secondary.opacity(0.18))
                    AxisTick().foregroundStyle(Color.secondary.opacity(0.25))
                    AxisValueLabel {
                        VStack(spacing: 1) {
                            switch granularity {
                            case .day:
                                Text(DateFormatting.weekdayShort(date))
                                    .font(.caption2).fontWeight(.semibold).foregroundStyle(.primary)
                                Text(DateFormatting.dayMonth(date))
                                    .font(.system(size: 10)).fontWeight(.medium).foregroundStyle(.primary)
                            case .week:
                                Text("KW")
                                    .font(.caption2).foregroundStyle(.secondary)
                                Text(DateFormatting.dayMonth(date))
                                    .font(.system(size: 10)).fontWeight(.medium).foregroundStyle(.primary)
                            case .month:
                                Text(DateFormatting.monthShort(date))
                                    .font(.system(size: 10)).fontWeight(.medium).foregroundStyle(.primary)
                            }
                        }
                        .fixedSize()
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { _ in
                AxisGridLine().foregroundStyle(Color.secondary.opacity(0.18))
                AxisValueLabel()
            }
        }
        .chartOverlay { proxy in
            GeometryReader { geometry in
                ZStack(alignment: .topLeading) {
                    // Fadenkreuz auf dem Buendel unter dem Zeiger.
                    if hoveredBucket != nil {
                        Rectangle()
                            .fill(Color.secondary.opacity(0.35))
                            .frame(width: 1)
                            .position(x: hoverPoint.x, y: geometry.size.height / 2)
                            .allowsHitTesting(false)
                    }

                    // Aufgezogener Bereich waehrend der Geste.
                    if let from = dragFrom, let to = dragTo {
                        Rectangle()
                            .fill(Color.accentColor.opacity(0.18))
                            .overlay(
                                Rectangle().strokeBorder(Color.accentColor.opacity(0.5), lineWidth: 1)
                            )
                            .frame(width: abs(to - from))
                            .position(x: (from + to) / 2, y: geometry.size.height / 2)
                            .allowsHitTesting(false)
                    }

                    Rectangle()
                        .fill(Color.clear)
                        .contentShape(Rectangle())
                        // Aufziehen setzt den Zeitraum. `minimumDistance` trennt
                        // die Geste sauber vom Klick (der zur Datei springt).
                        .gesture(
                            DragGesture(minimumDistance: 5)
                                .onChanged { value in
                                    if dragFrom == nil { dragFrom = value.startLocation.x }
                                    dragTo = value.location.x
                                }
                                .onEnded { value in
                                    defer { dragFrom = nil; dragTo = nil }
                                    guard let plotFrame = proxy.plotFrame else { return }
                                    let origin = geometry[plotFrame].origin
                                    guard
                                        let a: Date = proxy.value(atX: value.startLocation.x - origin.x),
                                        let b: Date = proxy.value(atX: value.location.x - origin.x)
                                    else { return }
                                    onRangeSelect(min(a, b), max(a, b))
                                }
                        )
                        .onTapGesture { location in
                            guard let plotFrame = proxy.plotFrame else { return }
                            let origin = geometry[plotFrame].origin
                            guard let day: Date = proxy.value(atX: location.x - origin.x) else { return }
                            let value: Double? = proxy.value(atY: location.y - origin.y)
                            onSelect(day, resolveExtension(day: day, value: value))
                        }
                        // Rueckmeldung beim Ueberfahren: Ohne sie muss man raten,
                        // wofuer ein Balken steht.
                        .help("Klick springt zur Datei · Ziehen wählt einen Zeitraum")
                        .onContinuousHover { phase in
                            switch phase {
                            case .active(let location):
                                hoverPoint = location
                                guard let plotFrame = proxy.plotFrame else { return }
                                let origin = geometry[plotFrame].origin
                                guard let date: Date = proxy.value(atX: location.x - origin.x) else {
                                    hoveredBucket = nil
                                    return
                                }
                                hoveredBucket = bucket(at: date)
                            case .ended:
                                hoveredBucket = nil
                            }
                        }

                    if let bucket = hoveredBucket {
                        tooltip(for: bucket)
                            .position(tooltipPosition(in: geometry.size))
                            .allowsHitTesting(false)
                    }
                }
            }
        }
    }

    /// Kurzinfo zum Buendel unter dem Zeiger.
    private func tooltip(for bucket: DayExtensionCount) -> some View {
        let parts = chartKeys.compactMap { key -> (String, Int)? in
            guard let count = bucket.counts[key], count > 0 else { return nil }
            return (key == otherKey ? "Sonstige" : ".\(key)", count)
        }
        return VStack(alignment: .leading, spacing: 3) {
            Text(bucketLabel(bucket.day))
                .font(.caption).fontWeight(.semibold)
            Text("\(bucket.total) \(bucket.total == 1 ? "Datei" : "Dateien")")
                .font(.caption2).foregroundStyle(.secondary)
            ForEach(parts.prefix(6), id: \.0) { name, count in
                HStack(spacing: 5) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(name == "Sonstige"
                              ? otherColor
                              : FileTypeColor.color(forExtension: String(name.dropFirst()), assignment: colorAssignment))
                        .frame(width: 8, height: 8)
                    Text(name).font(.caption2)
                    Spacer(minLength: 6)
                    Text("\(count)").font(.caption2).monospacedDigit().foregroundStyle(.secondary)
                }
            }
            if parts.count > 6 {
                Text("+\(parts.count - 6) weitere").font(.caption2).foregroundStyle(.tertiary)
            }
        }
        .padding(8)
        .frame(minWidth: 130, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.secondary.opacity(0.25), lineWidth: 1)
        )
        .shadow(radius: 6, y: 2)
    }

    /// Haelt die Kurzinfo im sichtbaren Bereich (kippt am rechten Rand nach links).
    private func tooltipPosition(in size: CGSize) -> CGPoint {
        let width: CGFloat = 150
        let x = hoverPoint.x + width / 2 + 14 > size.width
            ? hoverPoint.x - width / 2 - 14
            : hoverPoint.x + width / 2 + 14
        return CGPoint(x: max(width / 2, x), y: min(max(70, hoverPoint.y), size.height - 20))
    }

    /// Beschriftung eines Buendels – abhaengig von der Granularitaet.
    private func bucketLabel(_ date: Date) -> String {
        switch granularity {
        case .day:
            return "\(DateFormatting.weekdayShort(date)). \(DateFormatting.day(date))"
        case .week:
            let end = Calendar.current.date(byAdding: .day, value: 6, to: date) ?? date
            return "Woche \(DateFormatting.dayMonth(date))–\(DateFormatting.day(end))"
        case .month:
            return DateFormatting.monthYear(date)
        }
    }

    /// Das Buendel, in das ``date`` faellt.
    private func bucket(at date: Date) -> DayExtensionCount? {
        guard !chartDays.isEmpty else { return nil }
        // Das letzte Buendel, das nicht nach `date` beginnt.
        var match: DayExtensionCount?
        for entry in chartDays {
            if entry.day <= date { match = entry } else { break }
        }
        return match ?? chartDays.first
    }

    /// Bestimmt aus der getroffenen Hoehe (Stapel von unten nach oben in
    /// ``chartKeys``-Reihenfolge) die Endung des angeklickten Segments.
    private func resolveExtension(day: Date, value: Double?) -> String? {
        guard let value, value > 0 else { return nil }
        let calendar = Calendar.current
        _ = calendar
        guard let dayCount = bucket(at: day) else { return nil }
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
                    color: FileTypeColor.color(forExtension: item.ext, assignment: colorAssignment),
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

    /// Steuert die Beschriftungsdichte, damit die Achse nicht zulaeuft.
    private func shouldLabel(_ date: Date) -> Bool {
        guard !chartDays.isEmpty else { return false }
        if chartDays.count <= 8 { return true }
        switch granularity {
        case .day:
            // Montag und Freitag.
            let weekday = Calendar.current.component(.weekday, from: date)
            return weekday == 2 || weekday == 6
        case .week:
            // Etwa jede vierte Woche.
            let week = Calendar.current.component(.weekOfYear, from: date)
            return week % 4 == 1
        case .month:
            // Bei vielen Monaten nur jedes Quartal.
            let month = Calendar.current.component(.month, from: date)
            return chartDays.count <= 18 || (month - 1) % 3 == 0
        }
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
