import SwiftUI
import UniformTypeIdentifiers
import ActivitiesCore

/// Die Bedienelemente in der Titelleiste.
///
/// **Warum Toggle-Buttons statt `Switch`?** Laut HIG gehören Schalter in
/// Einstellungs-Formulare; in Toolbars gehören Knöpfe mit sichtbarem
/// Aktiv-Zustand hin. Zusätzlich sind sie deutlich kompakter.
///
/// **Reihenfolge folgt dem Arbeitsablauf**, von links nach rechts:
/// `Ort → Suche → Zeitraum → Anpassungen`.
/// 1. **Ort** – welchen Ordner durchsuche ich?
/// 2. **Suche** – welcher Name?
/// 3. **Zeitraum** – welcher Ausschnitt der Zeit?
/// 4. **Anpassungen** – Zustände (Darstellung) und Aktionen, durch Gruppierung getrennt.
///
/// Die ersten drei Schritte liegen in der `.navigation`-Zone (links), damit die
/// Lesereihenfolge der Arbeitsreihenfolge entspricht. Reicht die Breite nicht,
/// klappt macOS die hinteren Elemente automatisch in ein Überlauf-Menü.
struct MainToolbar: ToolbarContent {
    @Bindable var model: ReportViewModel
    var updates: UpdateChecker
    @State private var showImporter = false
    @State private var showCustomDays = false

    var body: some ToolbarContent {
        // 1. Ort
        ToolbarItem(placement: .navigation) {
            folderMenu
        }

        // 2. Suche
        ToolbarItem(placement: .navigation) {
            SearchField(
                text: $model.namePatternDraft,
                prompt: "Name filtern, z. B. studium",
                onChange: { model.namePatternDidChange() },
                onSubmit: { model.applyNameFilterNow() }
            )
            // **⚠️ 273 pt (Faktor 1,3), nicht 315 (1,5) – und die Zahl ist
            // gemessen, nicht gewaehlt.** Gewuenscht war 1,5. Gemessen wurde,
            // ab welcher Fensterbreite die Werkzeugleiste ueberlaeuft und
            // Knoepfe ins `»`-Menue wandern:
            //
            //   210 pt (bisher) → unter ~1295 pt Fensterbreite
            //   273 pt (1,3)    → unter ~1358 pt
            //   315 pt (1,5)    → unter ~1400 pt   (eingegrenzt: 1390 ja, 1410 nein)
            //
            // Verborgene Bedienelemente sind in diesem Programm eine teure
            // Lehre: UX-35, „Der Ordner-Umschalter war so unauffindbar
            // geworden, dass ihn der eigene Erbauer nicht mehr fand."
            //
            // **Versucht und verworfen:** `minWidth: 210, idealWidth: 315`,
            // damit das Feld bei Enge schrumpft. SwiftUI nimmt die Wunschbreite
            // und laesst stattdessen Knoepfe ueberlaufen – die Schwelle blieb
            // bei ~1400 pt. Ein flexibles Feld waere die bessere Loesung; es
            // gibt sie hier nicht.
            .frame(width: 273)
            // **Ein gesetzter Filter muss auffallen.** Ein Suchfeld mit Text
            // sieht sonst fast aus wie eines ohne – und dann wundert man sich
            // ueber eine unerklaerlich kurze Liste. Derselbe Grundsatz wie beim
            // Typ-Filter (UX-06): kein stiller Zustand.
            .overlay {
                if model.hasNameFilter {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(Color.accentColor, lineWidth: 2)
                        .allowsHitTesting(false)
                }
            }
            // ⚠️ Nicht ueber ``hint(_:)``: ⌘F springt ins Feld, es tut nicht das,
            // was der Satz davor beschreibt. Die Schreibweise kommt trotzdem aus
            // dem Katalog, damit sie nicht driften kann.
            .help("Teil des Dateinamens eingeben, dann Enter. Mehrere Wörter: alle müssen vorkommen. ODER trennt Alternativen. Platzhalter * und ? sind möglich. Ein leeres Feld hebt den Filter sofort auf. · Feld erreichen: \(Shortcuts.focusFilter.display)")
            .accessibilityLabel("Name filtern")
            .accessibilityValue(model.nameFilterPending
                ? "Noch nicht gesucht – Enter drücken"
                : (model.hasNameFilter ? "Filter aktiv: \(model.namePattern)" : "kein Filter"))
        }

        // 3. Zeitraum – mit dem Trennstrich zu den Anpassungen im selben Element.
        //
        // **⚠️ Gemeldet als „alles grau" – der Befund war ein anderer.** Der
        // Kontrast der Symbole stimmt seit PR-30 (`idleTint` ist
        // `Color.primary`, nicht die Systemfarbe). Was fehlte, war
        // **Gruppierung**: Zwoelf Bedienelemente standen in einem einzigen Zug,
        // ohne dass etwas den Ort-Suche-Zeitraum-Ablauf von den Schaltern
        // trennte. Eine ununterbrochene Reihe gleich grosser Symbole liest sich
        // als graue Wand – nicht weil die Symbole zu blass sind, sondern weil
        // das Auge keine Kante findet, an der es sich festhalten kann.
        //
        // Ein Trennstrich kostet ~1 pt Breite. Das ist wichtig, weil die Leiste
        // eng ist: Beschriftungen an den Knoepfen waeren die andere Antwort auf
        // dieselbe Frage gewesen – sie haetten aber den in PR-30 muehsam
        // erkaempften Platz sofort wieder aufgezehrt und die hinteren Elemente
        // ins Ueberlaufmenue gedraengt.
        //
        // **⚠️ Der Strich haengt am Zeitraum, statt ein eigenes `ToolbarItem`
        // zu sein.** `ToolbarContentBuilder` nimmt hoechstens zehn Elemente je
        // Bauplan – ein elftes bricht mit „extra argument in call", einer
        // Fehlermeldung, die den wahren Grund nicht nennt.
        ToolbarItem(placement: .navigation) {
            HStack(spacing: 8) {
                timeRangeControls
                Divider().frame(height: 16)
            }
        }

        // 4. Anpassungen – **Reihenfolge = Wichtigkeit**.
        //
        // ⚠️ Nicht nach Art gruppiert, sondern nach Rang. macOS schiebt bei zu
        // schmalem Fenster die **hinteren** Elemente in das Ueberlaufmenue „»".
        // Damit entscheidet die Reihenfolge, was zuerst unsichtbar wird. Als der
        // Gliederungs-Umschalter noch weiter hinten stand, war er nicht mehr
        // auffindbar (gemeldet) – dieselbe Falle wie ein Menuepunkt ohne Symbol.
        //
        // Vorne bleibt, was die Ansicht bestimmt (Gliederung, neu einlesen,
        // Sortierung); nach hinten wandern die Zustandsschalter und der Sprung
        // an den Listenanfang, der ohnehin ⌘↑ hat.

        // 4a. Anpassungen: Gliederung
        //
        // **Sichtbar, nicht im Menue.** Zuerst steckte der Umschalter im
        // Sortier-Menue – und war nicht auffindbar. Die Gliederung entscheidet,
        // *was* man ueberhaupt sieht; das gehoert wie der Zeitmodus daneben in
        // die Leiste, in derselben Bauform (Segmentwahl).
        ToolbarItem(placement: .navigation) {
            Picker("", selection: Binding(
                get: { model.viewMode },
                set: { model.setViewMode($0) }
            )) {
                ForEach(ViewMode.allCases, id: \.self) { mode in
                    Label(mode.label, systemImage: mode.symbol)
                        .labelStyle(.iconOnly)
                        .tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .fixedSize()
            .help("Gliederung: \(ViewMode.tree.longLabel) oder \(ViewMode.time.longLabel) · aktuell: \(model.viewMode.label)")
            .accessibilityLabel("Gliederung")
            .accessibilityValue(model.viewMode.longLabel)
        }

        // 4b. Neu einlesen – die wichtigste Aktion, deshalb weit vorn.
        ToolbarItem(placement: .navigation) {
            Button {
                model.rescan()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .foregroundStyle(ToolbarStateToggle.idleTint)
            }
            .help(Shortcuts.rescan.hint("Ordner neu einlesen"))
            .accessibilityLabel("Ordner neu einlesen")
        }

        // 4a. Anpassungen: Sortierung (Menue statt Dauer-Element – die Toolbar ist voll)
        ToolbarItem(placement: .navigation) {
            Menu {
                ForEach(SortField.allCases, id: \.self) { field in
                    Button {
                        model.setSortField(field)
                    } label: {
                        if model.sort.field == field {
                            Label(field.menuLabel, systemImage: model.sort.ascending ? "chevron.up" : "chevron.down")
                        } else {
                            Text(field.menuLabel)
                        }
                    }
                }
            } label: {
                Image(systemName: "arrow.up.arrow.down")
                    .foregroundStyle(ToolbarStateToggle.idleTint)
            }
            .help("Sortierung \(model.viewMode == .tree ? "unter Geschwistern" : "innerhalb der Zeitabschnitte") · aktuell: \(model.sort.field.label) \(model.sort.ascending ? "aufsteigend" : "absteigend")\(model.sort.field.sortsFolders ? "" : " · ordnet nur Dateizeilen")")
            .accessibilityLabel("Sortierung")
            .accessibilityValue("\(model.sort.field.label), \(model.sort.ascending ? "aufsteigend" : "absteigend")")
        }

        // 4a. Anpassungen: Zustände (ändern die Darstellung, nicht die Datenmenge)
        // Als Gruppe: SwiftUI erlaubt hoechstens zehn ToolbarItems je Builder.
        //
        // Zweite Zaesur: Davor stehen **Aktionen** (etwas geschieht auf Zuruf),
        // danach **Zustaende** (etwas bleibt ein- oder ausgeschaltet). Diese
        // beiden Arten zu mischen war der Grund, warum ein Anwender den
        // Auto-Refresh-Schalter fuer den Knopf „neu einlesen" hielt (v1.19.5).
        ToolbarItemGroup(placement: .navigation) {
            Divider().frame(height: 16)

            ToolbarStateToggle(
                isOn: Binding(
                    get: { model.allExpanded },
                    set: { model.setAllExpanded($0) }
                ),
                onSymbol: "list.bullet.indent",
                offSymbol: "list.bullet",
                // Derselbe Handgriff, zwei Formulierungen: Im Baum bleibt das
                // Ordnergeruest stehen und nur die Dateien verschwinden; in der
                // Zeitansicht ist das Zuklappen der Ordner derselbe Vorgang,
                // weil dort unter einem Ordner nur Dateien haengen.
                label: model.viewMode == .tree
                    ? "Dateien in allen Ordnern anzeigen"
                    : "Alle Ordner auf- oder zuklappen",
                onState: model.viewMode == .tree ? "werden angezeigt" : "alle aufgeklappt",
                offState: model.viewMode == .tree ? "sind ausgeblendet" : "nicht alle aufgeklappt",
                shortcut: Shortcuts.toggleAllExpanded
            )

            ToolbarStateToggle(
                isOn: Binding(
                    get: { model.showOutOfWindowFiles },
                    set: { model.setShowOutOfWindowFiles($0) }
                ),
                onSymbol: "clock.badge.checkmark",
                offSymbol: "clock.badge.xmark",
                label: "Dateien außerhalb des Zeitraums anzeigen",
                onState: "werden angezeigt",
                offState: "sind ausgeblendet"
            )

            // **Kein zweiter Kreispfeil.** Bis v1.19.5 trug dieser Schalter
            // `arrow.triangle.2.circlepath` und stand drei Symbole neben dem
            // Knopf „Ordner neu einlesen" (`arrow.clockwise`) – gemessen an
            // einem echten Missgriff: Der Anwender hielt den Schalter fuer den
            // Knopf und wunderte sich, dass nichts neu eingelesen wurde. Die
            // Antenne zeigt, was hier wirklich passiert: Der Ordner wird
            // **beobachtet** (FSEvents), nicht auf Zuruf gelesen.
            ToolbarStateToggle(
                isOn: Binding(
                    get: { model.autoRefresh },
                    set: { model.setAutoRefresh($0) }
                ),
                onSymbol: "antenna.radiowaves.left.and.right",
                offSymbol: "antenna.radiowaves.left.and.right.slash",
                label: "Automatisch aktualisieren bei Ordneränderung",
                onState: "ein",
                offState: "aus"
            )
        }

        // 4d. Zuletzt: der Sprung an den Listenanfang. Von allem hier der
        // entbehrlichste Knopf – er hat mit ⌘↑ ein Kuerzel und einen Menuepunkt,
        // darf also als Erster ins Ueberlaufmenue wandern.
        ToolbarItem(placement: .primaryAction) {
            Button {
                model.scrollToTopToken += 1
            } label: {
                Image(systemName: "arrow.up.to.line")
                    .foregroundStyle(ToolbarStateToggle.idleTint)
            }
            .help(Shortcuts.scrollToTop.hint("An den Anfang der Liste springen"))
            .accessibilityLabel("An den Anfang der Liste springen")
        }

        // --- Status ---
        // Fester Platz: Der Block ist immer vorhanden und nur waehrend einer
        // Suche sichtbar. Sonst wuerden die Nachbarelemente beim Ein- und
        // Ausblenden hin- und herspringen.
        ToolbarItem(placement: .navigation) {
            HStack(spacing: 6) {
                if model.isScanning || model.isLoadingDetails {
                    // Ohne Beschriftung ist der Fortschrittsring fuer
                // Vorleseprogramme ein namenloses Element (UX-37).
                ProgressView()
                    .accessibilityLabel("Suchlauf läuft").controlSize(.small)
                    Button {
                        model.cancelScan()
                    } label: {
                        Image(systemName: "stop.circle.fill").foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                    .help(Shortcuts.cancelScan.hint("Suche abbrechen"))
            .accessibilityLabel("Suche abbrechen")
                }
            }
            .frame(width: 44, alignment: .leading)
        }

        ToolbarItem {
            if updates.showsUpdateBadge, let latest = updates.latestVersion {
                Button {
                    updates.installUpdate()
                } label: {
                    Label("\(BuildInfo.short) → \(latest.description)", systemImage: "arrow.down.circle.fill")
                }
                .help("Update verfügbar – klicken zum Installieren")
            .accessibilityLabel("Update installieren")
            }
        }
    }

    // MARK: - Ordnerwahl

    private var folderMenu: some View {
        Menu {
            Button("Quelle hinzufügen …") { showImporter = true }
            if !model.sources.known.isEmpty {
                Divider()
                Section("Quellen") {
                    // Haken statt Auswahl: Quellen loesen einander nicht ab,
                    // sie addieren sich. Ein Menue mit Haken sagt das; eine
                    // Liste, aus der man eine Zeile anklickt, sagt das Gegenteil.
                    ForEach(model.sources.known, id: \.self) { url in
                        // **⚠️ Ordnername plus Pfad – nicht die verlaengerte
                        // Beschriftung aus ``sourceLabel(for:)``.** Gemeldet:
                        // „Sonst weiss keiner, wo die Quellen liegen." Zwei
                        // Ordner namens `Dokumente` auf interner und externer
                        // Platte waren nicht auseinanderzuhalten. Der Pfad loest
                        // das besser als ein verlaengerter Name, weil er nicht
                        // nur sagt *welche*, sondern *wo* – und zusammen ergaeben
                        // beide „Master/scansnap  /Volumes/Master/scansnap".
                        // Form wie in den Ordnerzeilen der Tabelle: Name, dahinter
                        // der Pfad in Grau.
                        Toggle(isOn: Binding(
                            get: { model.sources.isActive(url) },
                            set: { model.setSourceActive(url, $0) }
                        )) {
                            Text(url.lastPathComponent)
                                + Text("   " + model.sourcePath(for: url)).foregroundStyle(.secondary)
                        }
                        .help(url.path)
                    }
                }
            }
        } label: {
            Label(model.sourcesLabel, systemImage: "folder")
        }
        // Ausdruecklich MIT Beschriftung: Welche Quellen zaehlen, ist die
        // wichtigste Zustandsinformation der App – ein blosses Ordnersymbol
        // verschweigt sie.
        .labelStyle(.titleAndIcon)
        .help("Quellen wählen · aktuell: \(model.sourcesTooltip)")
        .accessibilityLabel("Quellen wählen")
        .accessibilityValue(model.sourcesLabel)
        // Menuebefehl ⇧⌘O: Der Dialog haengt hier, nicht im Menue.
        .onChange(of: model.folderPickerToken) { _, _ in showImporter = true }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [.folder],
            // Mehrfachauswahl: Wer drei Ordner gleichzeitig meint, soll sie
            // gleichzeitig waehlen duerfen. Ueberlappende lehnt das Modell ab.
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls): model.addSources(urls)
            case .failure(let fehler): model.reportSourceImportFailure(fehler)
            }
        }
    }

    // MARK: - Zeitraum (zusammengeführt)

    /// Modus und Werte in **einem** Bedienelement statt wie früher zwei parallel
    /// sichtbaren Wegen für dieselbe Größe (Presets **und** Stepper).
    @ViewBuilder
    private var timeRangeControls: some View {
        HStack(spacing: 8) {
            Picker("", selection: Binding(
                get: { model.timePreset },
                set: { model.setTimePreset($0) }
            )) {
                // „Heute" statt „1": Der Sonderfall verdient seinen Namen –
                // ein alleinstehendes „1" wirft die Frage „eins was?" auf.
                // Seit das Fenster in Kalendertagen rechnet, stimmt es auch:
                // 1 Tag = ab Tagesbeginn.
                //
                // Echtes Minuszeichen (U+2212) in ``TimePreset/toolbarLabel``,
                // nicht der Bindestrich: Es steht auf Zifferhoehe und liest
                // sich als Vorzeichen, nicht als Trennstrich.
                ForEach(TimePreset.rollingPresets, id: \.self) { preset in
                    Text(preset.toolbarLabel).tag(preset)
                }
                // ⚠️ Als einziges Segment ein Symbol – mit eigener
                // Beschriftung, weil ein blosses `Image` fuer Vorleseprogramme
                // namenlos ist (UX-37).
                Image(systemName: "slider.horizontal.3")
                    .accessibilityLabel(TimePreset.customDays.menuLabel)
                    .tag(TimePreset.customDays)
                Text(TimePreset.range.toolbarLabel).tag(TimePreset.range)
                Text(TimePreset.all.toolbarLabel).tag(TimePreset.all)
            }
            .pickerStyle(.segmented)
            .fixedSize()
            .help("Zeitraum: Kalendertage bis heute („Heute“ = ab 0 Uhr), eigene Tageszahl, feste Zeitspanne oder ohne Zeitgrenze")
            .accessibilityLabel("Zeitraum")
            .accessibilityValue(timeChoiceLabel)
            .popover(isPresented: $showCustomDays, arrowEdge: .bottom) {
                customDaysEditor
            }
            // Der Menuebefehl „Eigene Tageszahl …" kann das Feld nicht selbst
            // oeffnen – es haengt an dieser Ansicht. Er meldet sich ueber den
            // Zaehler, wie ⌘F es beim Suchfeld tut.
            .onChange(of: model.customDaysToken) { _, _ in showCustomDays = true }

            if model.useDateRange {
                DatePicker("", selection: Binding(
                    get: { model.rangeStart },
                    set: { model.setRangeStart($0) }
                ), in: ...model.rangeEnd, displayedComponents: .date)
                .datePickerStyle(.field).labelsHidden()
                .help("Von (inklusive)")
                .accessibilityLabel("Zeitraum von")

                Text("–").foregroundStyle(.secondary)

                DatePicker("", selection: Binding(
                    get: { model.rangeEnd },
                    set: { model.setRangeEnd($0) }
                ), in: model.rangeStart...Date(), displayedComponents: .date)
                .datePickerStyle(.field).labelsHidden()
                .help("Bis (inklusive ganzem Tag, max. heute)")
                .accessibilityLabel("Zeitraum bis")
            }
        }
    }

    /// Eine Wahl im **einen** Zeitraum-Bedienelement.
    ///
    /// **Warum zusammengezogen:** Zeitmodus und Tageszahl standen als zwei
    /// Segmentwahlen nebeneinander – zwei Bedienelemente fuer *eine* Frage
    /// („welchen Zeitraum sehe ich?"). Gemessen kosteten sie zusammen rund 365 pt
    /// und draengten vier Schalter ins Ueberlaufmenue. Als eine Reihe sind es
    /// ~290 pt, und die Wahl liest sich in einem Zug: fuenf Tageszahlen, eigene
    /// Zahl, feste Spanne, ohne Grenze.
    private var timeChoiceLabel: String {
        switch model.timePreset {
        case .today: "Heute"
        case .customDays: "\(model.days) Tage"
        case .range: "feste Zeitspanne"
        case .all: "ohne Zeitgrenze"
        default: "letzte \(model.days) Tage"
        }
    }

    /// Feineinstellung – erscheint nur auf Anforderung, statt dauerhaft neben
    /// den Presets Platz zu belegen.
    private var customDaysEditor: some View {
        HStack(spacing: 6) {
            Text("Tage:")
            TextField("", value: Binding(
                get: { model.days },
                set: { model.setDays($0) }
            ), format: .number)
            .textFieldStyle(.roundedBorder)
            .frame(width: 60)
            .multilineTextAlignment(.trailing)
            Stepper("", value: Binding(
                get: { model.days },
                set: { model.setDays($0) }
            ), in: 1...3650)
            .labelsHidden()
        }
        .padding(12)
        .help("Tage manuell eingeben (1–3650)")
            .accessibilityLabel("Tage manuell eingeben")
    }
}

/// Ein Zustandsschalter in der Titelleiste.
///
/// **Warum nicht einfach `toggleStyle(.button)`?** Der Standard traegt den
/// Zustand allein in einem minimal dunkleren Hintergrund. Auf der getoenten
/// Titelleiste ist das kaum zu sehen – und in einem **Hintergrundfenster**
/// blasst macOS saemtliche Bedienelemente ohnehin aus, sodass grau auf grau
/// uebrig bleibt. Genau dort wird die App aber meist nur „im Vorbeigehen"
/// gelesen.
///
/// Der Zustand steckt deshalb in **drei** Traegern, von denen keiner allein auf
/// Kontrast angewiesen ist:
/// 1. ein **eigenes Symbol** je Zustand (kein Fuell-Unterschied, sondern eine
///    andere Form – lesbar auch ohne Farbe),
/// 2. die **Akzentfarbe** bei „ein"; ausdruecklich gesetzte Farben bleiben
///    auch im inaktiven Fenster erhalten, Systemfarben nicht,
/// 3. der gewohnte Knopfhintergrund des Systems.
///
/// Zusaetzlich melden Tooltip und Bedienhilfen denselben Zustand im Klartext –
/// ein Symbol, das man deuten muss, ist keine Auskunft.
struct ToolbarStateToggle: View {
    @Binding var isOn: Bool
    /// Symbol im Zustand „ein" bzw. „aus" – bewusst **zwei verschiedene** Formen.
    let onSymbol: String
    let offSymbol: String
    /// Was der Schalter steuert (unveraenderlich, fuer die Bedienhilfen).
    let label: String
    /// Was der jeweilige Zustand bedeutet – im Klartext, nicht als „ein/aus",
    /// wo sich etwas Besseres sagen laesst.
    let onState: String
    let offState: String
    /// Das Kürzel desselben Befehls – erscheint im Tooltip, damit man es lernt.
    /// `nil` bei Schaltern, die keines haben (nicht jeder braucht eines).
    var shortcut: ShortcutEntry? = nil

    /// Farbe untaetiger Titelleisten-Symbole.
    ///
    /// ``Color/primary`` statt der System-Steuerfarbe: Letztere wird im
    /// inaktiven Fenster bis zur Unlesbarkeit aufgehellt.
    static let idleTint = Color.primary

    private var stateText: String { isOn ? onState : offState }

    var body: some View {
        Toggle(isOn: $isOn) {
            Image(systemName: isOn ? onSymbol : offSymbol)
                // **Gefuellt, nicht nur getoent.** Der Systemhintergrund eines
                // eingeschalteten Knopfes ist ein Hauch dunkleres Grau – auf der
                // getoenten Titelleiste kaum zu sehen und im Hintergrundfenster
                // gar nicht. Ein aktiver Zustand, den man suchen muss, ist ein
                // stiller Zustand (Akzeptanz aus UX-03: Symbol **und**
                // erkennbarer Zustand).
                .foregroundStyle(isOn ? AnyShapeStyle(.white) : AnyShapeStyle(Self.idleTint))
                .padding(.horizontal, 5)
                .padding(.vertical, 3)
                .background {
                    if isOn {
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(Color.accentColor)
                    }
                }
        }
        .toggleStyle(.button)
        .help((shortcut?.hint(label) ?? label) + " · aktuell: \(stateText)")
        .accessibilityLabel(label)
        .accessibilityValue(stateText)
    }
}
