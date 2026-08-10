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

                workFilesRow
            }

            statusRow
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
        DateFormatting.range(
            from: model.displayRangeStart,
            to: model.displayRangeEnd,
            days: model.displayRangeDayCount
        )
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

    /// **Eine** Statuszeile für alles gerade Ausgeblendete.
    ///
    /// **Warum zusammengefasst?** Typ-Filter und Rauschfilter beantworten dem
    /// Anwender dieselbe Frage: „Warum sehe ich nicht alles?" Zwei gestapelte
    /// Leisten kosteten doppelt Höhe und legten nahe, es seien zwei getrennte
    /// Sachverhalte.
    ///
    /// **Warum der Rauschfilter links steht:** Er ist dauerhaft sichtbar, der
    /// Typ-Filter kommt und geht. Stünde der Typ-Filter zuerst, spränge das
    /// Auge bei jedem Ein- und Ausblenden nach rechts – ein ortsfestes
    /// Bedienelement darf nicht von einem flüchtigen verschoben werden.
    ///
    /// **Warum `ViewThatFits`?** Nebeneinander ist schlanker – aber bei schmalem
    /// Fenster würde Text abgeschnitten, und ein abgeschnittener Hinweis auf
    /// Ausgeblendetes wäre schlimmer als eine zweite Zeile. Passt es nicht,
    /// bricht die Zeile um, statt Information zu verlieren.
    @ViewBuilder
    private var statusRow: some View {
        let zeigtRauschen = model.revealHiddenFolders
            || model.skippedFolderCount > 0
            || !model.excludedPaths.isEmpty
        if model.hasNameFilter || model.hasTypeFilter || zeigtRauschen {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    if model.hasNameFilter { nameSegment }
                    if model.hasNameFilter && (model.hasTypeFilter || zeigtRauschen) {
                        Divider().frame(height: 11)
                    }
                    if zeigtRauschen { noiseSegment }
                    if model.hasTypeFilter && zeigtRauschen {
                        Divider().frame(height: 11)
                    }
                    if model.hasTypeFilter { typeSegment }
                }
                VStack(alignment: .leading, spacing: 3) {
                    if model.hasNameFilter { nameSegment }
                    if zeigtRauschen { noiseSegment }
                    if model.hasTypeFilter { typeSegment }
                }
            }
            // ⚠️ `.subheadline` (11 pt) statt `.caption` (10 pt): Diese Zeile
            // ist die **einzige** Stelle, an der ein stiller Filter sichtbar
            // wird. Sie in der kleinsten Schrift des Fensters zu setzen
            // widerspricht ihrem Zweck – wer sie uebersieht, haelt eine
            // gefilterte Liste fuer den ganzen Bestand (UX-06).
            .font(.subheadline)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
            .padding(.bottom, 5)
        }
    }

    /// Der Schalter „Nur Arbeitsdateien" (PR-44).
    ///
    /// **Warum unter dem Diagramm und nicht in den Einstellungen.** Er wird
    /// mehrmals am Tag umgelegt und wirkt sofort sichtbar auf Diagramm und
    /// Legende, die direkt darueber stehen. Ein Schalter, der etwas ausblendet,
    /// gehoert neben das, was er ausblendet – sonst sucht man die Ursache an
    /// der falschen Stelle.
    ///
    /// **⚠️ Immer sichtbar, nicht nur wenn er an ist.** Die uebrigen Hinweise in
    /// ``statusRow`` erscheinen erst, wenn gefiltert wird; dieser hier ist der
    /// Schalter selbst. Waere er nur im eingeschalteten Zustand da, gaebe es
    /// keinen Weg, ihn einzuschalten.
    private var workFilesRow: some View {
        HStack(spacing: 6) {
            Toggle(isOn: Binding(
                get: { model.showsOnlyWorkFiles },
                set: { _ in model.toggleWorkFilesOnly() }
            )) {
                Text("Nur Arbeitsdateien")
            }
            .toggleStyle(.checkbox)
            .help("Zeigt nur Dokumente, PDF, Tabellen, Präsentationen und "
                  + "Diagramme (bpmn, graph). Blendet Quelltext, Archive, "
                  + "Medien, Bilder und Dateien ohne Endung aus.")
            .accessibilityHint("Blendet alles aus, was keine Arbeitsdatei ist")

            if model.showsOnlyWorkFiles {
                Text("Quelltext, Archive, Medien, Bilder und Dateien ohne Endung sind ausgeblendet")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            Spacer(minLength: 4)
        }
        .font(.subheadline)
        .padding(.horizontal, Self.yAxisGutter)
        .padding(.bottom, 6)
    }

    /// Der gesetzte **Namensfilter**.
    ///
    /// **Offene Randnotiz aus UX-29, endlich eingeloest.** Dort stand: „Analog
    /// zu UX-06 einen dezenten Dauerhinweis, solange ein Namensfilter aktiv ist
    /// – dann faellt es schon *vor* dem Ordnerwechsel auf." Der Punkt blieb
    /// liegen, weil er in einem bereits **geschlossenen** Eintrag stand.
    ///
    /// Der Filter steht zwar im Suchfeld, aber ein Feld mit Text sieht fast aus
    /// wie eines ohne. Wer ihn uebersieht, haelt eine gefilterte Liste fuer den
    /// ganzen Bestand.
    private var nameSegment: some View {
        HStack(spacing: 5) {
            Image(systemName: "magnifyingglass.circle.fill")
                .foregroundStyle(.tint)
            Text("Namensfilter „\(model.namePattern)“")
            Button("Löschen") { model.clearNameFilter() }
                .buttonStyle(.link)
                .help("Namensfilter entfernen")
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Namensfilter \(model.namePattern) ist aktiv")
        .accessibilityHint("Zum Löschen aktivieren")
    }

    /// Ausgeblendete Dateitypen.
    ///
    /// Ohne diesen Hinweis wäre der Typ-Filter ein **stiller Zustand**: Die
    /// Ergebnisliste wirkt unvollständig, ohne dass erkennbar ist, warum.
    /// Der Akzentton bleibt, weil dieser Zustand vom Anwender selbst gesetzt
    /// wurde – anders als der dauerhaft laufende Rauschfilter.
    private var typeSegment: some View {
        let count = model.hiddenTypeCount
        return HStack(spacing: 5) {
            Image(systemName: "line.3.horizontal.decrease.circle.fill")
                .foregroundStyle(.tint)
            Text("\(count) \(count == 1 ? "Typ" : "Typen") ausgeblendet")
            Button("Zurücksetzen") { model.resetTypeFilters() }
                .buttonStyle(.link)
                .help("Alle Dateitypen wieder einblenden (⌥⌘R)")
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(count) Dateitypen ausgeblendet")
        .accessibilityHint("Zum Zurücksetzen aktivieren")
    }

    /// Offenlegung, wie viel der Rauschfilter ausgeblendet hat.
    ///
    /// **Ausschlüsse dürfen kein stiller Zustand sein** (Lehre aus UX-06): Wer
    /// nicht sieht, dass etwas fehlt, hält die Auswertung für vollständig.
    private var noiseSegment: some View {
        HStack(spacing: 5) {
            // Das Auge ist der Schalter: ein Klick zeigt das Ausgeblendete,
            // ein zweiter blendet es wieder aus.
            Button {
                model.toggleRevealHiddenFolders()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: model.revealHiddenFolders ? "eye" : "eye.slash")
                    Text(noiseText)
                }
                .foregroundStyle(model.revealHiddenFolders ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(model.revealHiddenFolders
                  ? "Ausgeblendete Ordner wieder ausblenden"
                  : "Ausgeblendete Ordner vorübergehend anzeigen")
            .accessibilityLabel(noiseText)
            .accessibilityHint(model.revealHiddenFolders
                               ? "Blendet sie wieder aus"
                               : "Zeigt sie vorübergehend an")

            SettingsLink {
                Text("Einstellungen …")
            }
            .buttonStyle(.link)
        }
    }

    private var noiseText: String {
        if model.revealHiddenFolders {
            return "Ausgeblendete Ordner werden angezeigt"
        }
        var teile: [String] = []
        if model.skippedFolderCount > 0 {
            // „samt Inhalt": Die Zahl nennt die uebersprungenen EINSTIEGE – darunter
            // liegen meist deutlich mehr Ordner (46 Einstiege ≙ 168 Ordner gemessen).
            teile.append("\(model.skippedFolderCount) Ordner samt Inhalt übersprungen")
        }
        if !model.excludedPaths.isEmpty {
            let n = model.excludedPaths.count
            teile.append("\(n) von dir ausgeblendet")
        }
        return teile.joined(separator: " · ")
    }
}
