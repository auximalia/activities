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
    @Environment(\.openSettings) private var openSettings

    /// Höhe des Diagramms. Bewusst kompakter als früher (260), damit die feste
    /// Kopfzone auch bei kleiner Fensterhöhe genügend Raum für die Liste lässt.
    private static let chartHeight: CGFloat = 180
    /// Platz, den die Y-Achsenbeschriftung des Diagramms links einnimmt.
    private static let yAxisGutter: CGFloat = 38

    /// Zustand einer laufenden Rad-Geste (v1.19.71).
    @State private var scrub = ChartScrub()

    /// Nimmt ein Rad-Ereignis über der Diagrammfläche entgegen.
    ///
    /// **⚠️ Nachlauf wird verworfen** (`momentumPhase != []`). Ein Trackpad
    /// schickt nach dem Loslassen weiter Ereignisse; ohne diese Bedingung
    /// zählte ein Wisch nach dem Abheben der Finger weiter, und aus „eine Raste
    /// = ein Tag" würde ein Glücksrad. Am Trackpad zählt deshalb nur, solange
    /// die Finger aufliegen.
    ///
    /// **⚠️ Maus und Trackpad werden getrennt behandelt, weil sie
    /// Verschiedenes melden.** `hasPreciseScrollingDeltas` unterscheidet sie:
    /// Die Maus meldet ganze Zeilen – dort ist „eine Raste = ein Tag" exakt und
    /// braucht keine Umrechnung. Das Trackpad meldet Punkte; dafür sammelt
    /// ``DayScrub`` und gibt ganze Tage aus.
    ///
    /// **⚠️ Waagerechtes Wischen wird nicht angefasst.** Ein Zweifingerwisch
    /// nach links hat auf dieser Fläche keine Bedeutung, und ein Ereignis, das
    /// überwiegend waagerecht ist, war nicht als Verstellen gemeint.
    private func handleWheel(_ event: NSEvent) -> Bool {
        guard event.momentumPhase.isEmpty else { return true }
        let dy = event.scrollingDeltaY
        guard dy != 0, abs(dy) >= abs(event.scrollingDeltaX) else { return false }

        let eingabe: DayScrub.Input = event.hasPreciseScrollingDeltas
            ? .points(dy)
            : .notches(dy)
        // Ein Trackpad meldet das Ende der Geste selbst; ein Rad kennt keine
        // Phase, dort entscheidet die Ruhefrist in ``ChartScrub``.
        let endsNow = event.phase.contains(.ended) || event.phase.contains(.cancelled)

        scrub.handle(eingabe,
                     startDays: model.days,
                     startAll: model.ignoreTimeWindow,
                     endsNow: endsNow) { state in
            guard state.differs(fromDays: model.days,
                                isAllTime: model.ignoreTimeWindow,
                                usesRange: model.useDateRange) else { return }
            if state.isAllTime {
                model.setIgnoreTimeWindow(true)
            } else {
                model.setDays(state.days)
            }
        }
        return true
    }

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
                    worksFilesOnly: model.showsOnlyWorkFiles,
                    onToggleWorkFiles: { model.toggleWorkFilesOnly() },
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
                // ⚠️ Das Rad wirkt **nur über der Diagrammflaeche** – so
                // entschieden. Ueberschrift und Statuszeile der Kopfzone sind
                // ausgenommen, und eingeklappt gibt es kein Ziel; dann bleiben
                // ⌘1–⌘5, ⌘0, der Segmentschalter und das Zahlenfeld.
                //
                // **Kein Bildlauf-Konflikt, und das ist baulich so, nicht
                // wahrscheinlich:** Die Kopfzone ist **Geschwister** der Liste,
                // nicht ihr Kind (`RootView` gegen `ReportView`) – ueber ihr
                // liegt kein Bildlaufbereich, in den ein Ereignis aufsteigen
                // koennte.
                .background(WheelCatcher(onWheel: handleWheel))
                .overlay { ScrubIndicator(scrub: scrub) }
            }

            statusRow
        }
        .background(.bar)
    }

    /// Der **Gegenstand** als Überschrift direkt über dem Diagramm, linksbündig:
    /// aus welcher Quelle und aus welchem Zeitraum das Bild darunter stammt.
    ///
    /// Der Zeitraum beschriftet das Diagramm – ohne ihn sind die Balken nicht
    /// deutbar. Er gehört deshalb in dessen unmittelbare Nähe und **nicht** in
    /// die Titelleiste (dort stand er in v1.8.x; Gesetz der Nähe).
    /// Bleibt auch **eingeklappt** sichtbar, weil die Information dann erst
    /// recht gebraucht wird.
    ///
    /// **⚠️ Hier stand von v2.0.20 bis v2.0.21 eine zweite Zeile, und sie war
    /// zu drei Vierteln überflüssig (UX-75).** Gemeldet wurde: *„bei
    /// eingeklapptem Diagramm wirkt der Text oben unruhig und redundant."* Der
    /// Nachweis lag im Quelltext: Die Bedingungen für Rauschen, Name und Typ
    /// waren in beiden Zeilen **paarweise identisch** – die Überschneidung war
    /// nicht teilweise, sondern vollständig. Von drei Angaben der zweiten Zeile
    /// war genau eine neu, die Sortierung.
    ///
    /// *Gemessen worden war damals die Breite, nicht die Überschneidung.* Die
    /// Sortierung sitzt jetzt in der Statuszeile, und die Kopfzone trägt wieder
    /// **eine** Überschrift: **oben der Gegenstand, darunter die Behandlung.**
    private var headline: some View {
        // ⚠️ **Ein** Bedienhilfen-Element mit dem Satz ueber ALLE sechs Achsen,
        // obwohl sichtbar nur zwei hier stehen (UX-73). Wer nicht sieht, kann
        // nicht ueber zwei Zeilen blicken – „einen Blick" gibt es fuer
        // Vorleseprogramme sonst gar nicht. Die Statuszeile darunter bleibt
        // trotzdem einzeln erreichbar, weil ihre Knoepfe bedienbar sein muessen.
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                subjectHeadline
                    .font(.title3)
                    .fontWeight(.semibold)

                if !model.headerExpanded && !model.topExtensions.isEmpty {
                    Text(collapsedSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .accessibilityLabel("Häufigste Dateitypen")
                        .accessibilityValue(collapsedSummary)
                }

                Spacer(minLength: 8)
                collapseButton
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Was gerade wirkt")
        .accessibilityValue(ActiveFilters.spokenSummary(model.activeFilterFacets))
        // Links so weit einruecken, dass die Ueberschrift rechts neben der
        // Y-Achsenbeschriftung des Diagramms beginnt – sonst stossen „30" und
        // der Anfang der Ueberschrift optisch aneinander.
        .padding(.leading, Self.yAxisGutter)
        .padding(.trailing, 8)
        .padding(.top, 6)
        .padding(.bottom, model.headerExpanded ? 0 : 6)
    }

    /// Der Gegenstand: **Quelle · Zeitraum**.
    ///
    /// **⚠️ Zwei `Text` mit verschiedener Layout-Priorität, nicht eine
    /// zusammengesetzte Zeichenkette.** Als ein Text mit `.truncationMode(.tail)`
    /// hätte ein langer Quellenname den **Zeitraum** vom Ende her abgeschnitten
    /// – ausgerechnet die Angabe, ohne die die Balken darunter nicht deutbar
    /// sind (Entscheidung 6). Gemessen mit `measure-ui`: der Gegenstand ist im
    /// Normalfall 379,1 pt breit, die Zeile hat bei der Mindestfensterbreite von
    /// 820 pt rund 265 pt Luft – ein Quellenname mit vierzig Zeichen frisst sie
    /// auf. Der Quellenname weicht deshalb zuerst und **mittig** gekürzt, wie
    /// der Pfad in der Fußzeile; derselbe Grundsatz wie bei der Urheberangabe
    /// dort: *Schmückendes weicht Auskunft, nicht umgekehrt.*
    @ViewBuilder
    private var subjectHeadline: some View {
        let facets = ActiveFilters.subject(model.activeFilterFacets)
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            if let quelle = facets.first(where: { $0.axis == .source }) {
                Text(quelle.text)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .layoutPriority(-1)
                    .accessibilityLabel("Quelle")
                    .accessibilityValue(quelle.text)
                Text("·").foregroundStyle(.secondary).layoutPriority(-1)
            }
            if let zeitraum = facets.first(where: { $0.axis == .period }) {
                Text(zeitraum.text)
                    .lineLimit(1)
                    .layoutPriority(1)
                    .accessibilityLabel("Zeitraum")
                    .accessibilityValue(zeitraum.text)
            }
        }
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
        .help(Shortcuts.toggleChart.hint("Kopfzone auf- oder zuklappen – eingeklappt bleibt mehr Platz für die Liste"))
    }

    /// Kurzfassung der Legende für den eingeklappten Zustand.
    private var collapsedSummary: String {
        let names = model.topExtensions.prefix(4).map { ".\($0.ext)" }.joined(separator: ", ")
        let rest = model.topExtensions.count - min(4, model.topExtensions.count)
        return rest > 0 ? "\(names) +\(rest)" : names
    }

    /// **Die Zustandszeile: was zurückgehalten wird und wie geordnet ist.**
    ///
    /// **Warum zusammengefasst?** Typ-Filter und Rauschfilter beantworten dem
    /// Anwender dieselbe Frage: „Warum sehe ich nicht alles?" Zwei gestapelte
    /// Leisten kosteten doppelt Höhe und legten nahe, es seien zwei getrennte
    /// Sachverhalte.
    ///
    /// **⚠️ Seit v2.1.0 ist sie IMMER da, und damit ist sie keine Ausnahmezeile
    /// mehr (UX-75).** Gemeldet wurde: *„bei eingeklapptem Diagramm wirkt der
    /// Text oben unruhig und redundant."* Über ihr stand seit v2.0.20 eine
    /// zweite Zeile, deren Bedingungen für Rauschen, Name und Typ **paarweise
    /// identisch** mit denen hier waren — die Überschneidung war nicht
    /// teilweise, sondern vollständig. Beide sind zu **einer** verschmolzen; die
    /// Sortierung ist als fünftes Segment eingezogen.
    ///
    /// **⚠️ Damit ist Sprint 17, Festlegung 3 EINGESCHRÄNKT, nicht aufgehoben —
    /// und die Einschränkung gehört hierher, sonst zieht der Nächste den
    /// falschen Schluss.** Festlegung 3 argumentierte zweibeinig gegen die
    /// Aufnahme von „Dateien außerhalb des Zeitraums":
    /// *(a)* eine Ansage über den Vorgabezustand feuerte immer und wäre
    /// Grundrauschen — *„die drei Geschwister sind im Ruhezustand alle still"*;
    /// *(b)* was der Schalter durchsetzt, steht bereits als Überschrift über dem
    /// Diagramm (Entscheidung 6).
    ///
    /// **Bein (a) trug schon damals nicht.** `zeigtRauschen` ist bei jedem
    /// realen Ordnerbaum wahr — `.git`, `node_modules` und Konsorten werden
    /// immer übersprungen. Die Zeile war also **de facto längst permanent**; die
    /// Verschmelzung macht sie nicht dauerhaft, sie gibt zu, dass sie es ist.
    /// **Bein (b) steht unangetastet und trägt Festlegung 3 allein weiter:**
    /// „Dateien außerhalb des Zeitraums" kommt weiterhin nicht hinein.
    ///
    /// **Warum die Sortierung ganz links steht:** Sie ist das einzige Segment
    /// ohne „aus" und damit das ortsfesteste — siehe ``sortSegment``.
    ///
    /// **⚠️ Genau das war bis v2.0.18 der Fall, und die Begründung stand
    /// daneben (UX-72).** Sie war für **zwei** Segmente geschrieben („der
    /// Typ-Filter kommt und geht") und stimmte damals. Mit dem Namenssegment aus
    /// UX-29 kam ein **drittes, flüchtiges** links davor, und der Rauschfilter
    /// stand plötzlich in der Mitte. *Eine Begründung, die stehenbleibt, während
    /// der Aufbau sich ändert, schützt nicht mehr; sie lässt den Fehler nur
    /// begründet aussehen.* Dieselbe Regel hat jetzt die Sortierung nach vorn
    /// geschoben — sie ist damit zum zweiten Mal angewandt worden, nicht zum
    /// zweiten Mal übersehen.
    ///
    /// **Warum `ViewThatFits`?** Nebeneinander ist schlanker – aber bei schmalem
    /// Fenster würde Text abgeschnitten, und ein abgeschnittener Hinweis auf
    /// Ausgeblendetes wäre schlimmer als eine zweite Zeile. Passt es nicht,
    /// bricht die Zeile um, statt Information zu verlieren.
    @ViewBuilder
    private var statusRow: some View {
        // ⚠️ Sichtbarkeit und Text kommen aus DERSELBEN Quelle. Hier stand
        // `skippedFolderCount > 0 || !excludedPaths.isEmpty` – die zweite
        // Haelfte fragte die **Einrichtung**, waehrend der Text ueber den
        // **Suchlauf** berichtet. Eine Ausblendung ausserhalb der gewaehlten
        // Quellen liess die Zeile damit erscheinen und leer bleiben.
        let zeigtRauschen = model.revealHiddenFolders || model.skippedSummary != nil
        if let hinweis = model.sourceNotice {
            HStack(spacing: 5) {
                Image(systemName: "info.circle.fill").foregroundStyle(.tint)
                Text(hinweis)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Verstanden") { model.clearSourceNotice() }
                    .buttonStyle(.link)
            }
            .font(.subheadline)
            .padding(.horizontal, Self.yAxisGutter)
            .padding(.bottom, 4)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(hinweis)
        }
        // ⚠️ Eigene Zeile, nicht in die Filterzeile hinein: Das hier ist kein
        // Filter, sondern eine Auskunft ueber die **Daten**. Wer es zwischen
        // Namens- und Typ-Filter setzt, laesst es wie etwas aussehen, das man
        // abschalten kann.
        if model.futureFileCount > 0 {
            let n = model.futureFileCount
            let text = n == 1
                ? "1 Datei ist auf ein Datum in der Zukunft gesetzt und liegt außerhalb des Diagramms."
                : "\(n) Dateien sind auf ein Datum in der Zukunft gesetzt und liegen außerhalb des Diagramms."
            HStack(spacing: 5) {
                Image(systemName: "clock.badge.exclamationmark")
                    .foregroundStyle(.secondary)
                Text(text)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .padding(.horizontal, Self.yAxisGutter)
            .padding(.bottom, 4)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(text)
        }
        ViewThatFits(in: .horizontal) {
            // Reihenfolge: das Ortsfeste zuerst, die Flüchtigen dahinter –
            // Begründung im Doc-Kommentar oben (UX-72, UX-75).
            HStack(spacing: 10) {
                sortSegment
                if zeigtRauschen { Divider().frame(height: 11); noiseSegment }
                if model.nameFilterPending { Divider().frame(height: 11); pendingSegment }
                if model.hasNameFilter { Divider().frame(height: 11); nameSegment }
                if model.hasTypeFilter { Divider().frame(height: 11); typeSegment }
            }
            VStack(alignment: .leading, spacing: 3) {
                sortSegment
                if zeigtRauschen { noiseSegment }
                if model.nameFilterPending { pendingSegment }
                if model.hasNameFilter { nameSegment }
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

    /// Wonach die Liste geordnet ist – „nach Datum, absteigend".
    ///
    /// **⚠️ Das einzige Segment ohne Akzentfarbe und ohne Rückweg, und beides
    /// mit Absicht.** Der Akzentton trägt in dieser Zeile eine Bedeutung: *hier
    /// wird etwas zurückgehalten, und du kannst es zurückholen.* Die Sortierung
    /// hält nichts zurück – sie ordnet nur. Ein „Zurücksetzen" gäbe es hier
    /// nicht, sondern nur ein „anders"; gewechselt wird sie in der
    /// Werkzeugleiste und im Menü „Darstellung" (⌥⌘1–4). Ein dritter Bedienort
    /// wäre genau der Fehler, den PR-44 behoben hat.
    ///
    /// **⚠️ Sie steht ganz links, und das folgt der Regel dieser Zeile.**
    /// UX-72: *ein ortsfestes Element darf von einem flüchtigen nicht verschoben
    /// werden.* Seit v2.1.0 ist die Sortierung das einzige Segment, das
    /// **immer** dasteht — damit ist sie das ortsfesteste und rückt vor den
    /// Rauschfilter. Die Regel wird angewandt, nicht gebrochen.
    private var sortSegment: some View {
        HStack(spacing: 5) {
            Image(systemName: "arrow.up.arrow.down")
                .foregroundStyle(.secondary)
            Text(sortFacetText)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Sortierung")
        .accessibilityValue(model.sort.summary)
    }

    /// Der Wortlaut kommt aus ``ActiveFilters`` – nicht aus einer zweiten
    /// Formulierung hier.
    private var sortFacetText: String {
        model.activeFilterFacets.first { $0.axis == .sort }?.text ?? "nach \(model.sort.summary)"
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
    /// **Getipptes, das noch nicht gesucht wurde.**
    ///
    /// **⚠️ Der Preis der Enter-Auslösung, und er muss bezahlt werden.** Seit
    /// PR-55 rechnet das Programm beim Tippen nicht mehr – dafür zeigt die Liste
    /// währenddessen etwas anderes, als im Suchfeld steht. Ohne sichtbares
    /// Zeichen ist das genau die Erfahrung „die Suche ist kaputt": Man tippt,
    /// und nichts passiert. Derselbe Fehler wie UX-06, nur umgekehrt – dort war
    /// zu wenig zu sehen, hier zu viel.
    ///
    /// Steht **neben** dem Namensfilter, nicht an seiner Stelle: Beides kann
    /// gleichzeitig gelten (ein Filter ist gesetzt, und im Feld steht schon der
    /// nächste). Wer das eine durch das andere ersetzt, verschweigt, wonach
    /// gerade gefiltert wird.
    private var pendingSegment: some View {
        HStack(spacing: 5) {
            Image(systemName: "return.circle.fill")
                .foregroundStyle(.tint)
            Text("Enter drücken, um nach „\(model.namePatternDraft.trimmingCharacters(in: .whitespacesAndNewlines))“ zu suchen")
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Noch nicht gesucht: \(model.namePatternDraft). Enter drücken.")
    }

    private var nameSegment: some View {
        HStack(spacing: 5) {
            Image(systemName: "magnifyingglass.circle.fill")
                .foregroundStyle(.tint)
            Text("Namensfilter „\(model.namePattern)“")
            Button("Löschen") { model.clearNameFilter() }
                .buttonStyle(.link)
                .help(Shortcuts.clearNameFilter.hint("Namensfilter entfernen"))
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
        HStack(spacing: 5) {
            Image(systemName: "line.3.horizontal.decrease.circle.fill")
                .foregroundStyle(.tint)
            Text(model.typeFilterSummary)
            Button("Zurücksetzen") { model.resetTypeFilters() }
                .buttonStyle(.link)
                .help(Shortcuts.resetTypeFilter.hint("Alle Dateitypen wieder einblenden"))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(model.typeFilterSummary)
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

            // ⚠️ `openSettings` statt `SettingsLink`: Nur so laesst sich der
            // Reiter VOR dem Oeffnen setzen. Ein `SettingsLink` ist ein Knopf
            // ohne Ziel – er zeigt den Reiter, der zuletzt zu tun hatte.
            Button("Rauschfilter öffnen") {
                model.settingsTab = .noise
                openSettings()
            }
            .buttonStyle(.link)
            .help("Übersprungene und ausgeblendete Ordner verwalten (\(Shortcuts.settings.display))")
        }
    }

    private var noiseText: String {
        if model.revealHiddenFolders {
            return "Ausgeblendete Ordner werden angezeigt"
        }
        return model.skippedSummary ?? ""
    }
}
