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
                text: $model.namePattern,
                prompt: "Name filtern",
                onChange: { model.namePatternDidChange() },
                onSubmit: { model.applyNameFilterNow() }
            )
            // 220 pt kosteten drei Zustandsschalter den Platz in der Leiste –
            // gemessen bei 1280 pt Fensterbreite. Der Hinweistext ist dafuer
            // kuerzer; das ausfuehrliche Beispiel steht im Tooltip.
            .frame(width: 170)
            .help("Teil des Dateinamens eingeben, z. B. studium. Platzhalter * und ? sind zusätzlich möglich. Enter startet die Suche.")
            .accessibilityLabel("Name filtern")
        }

        // 3. Zeitraum
        ToolbarItem(placement: .navigation) {
            timeRangeControls
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
            .help("Ordner neu einlesen (⌘R)")
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
                            Label(field.label, systemImage: model.sort.ascending ? "chevron.up" : "chevron.down")
                        } else {
                            Text(field.label)
                        }
                    }
                }
            } label: {
                Image(systemName: "arrow.up.arrow.down")
                    .foregroundStyle(ToolbarStateToggle.idleTint)
            }
            .help("Sortierung \(model.viewMode == .tree ? "unter Geschwistern" : "innerhalb der Zeitabschnitte") · aktuell: \(model.sort.field.label) \(model.sort.ascending ? "aufsteigend" : "absteigend")")
            .accessibilityLabel("Sortierung")
            .accessibilityValue("\(model.sort.field.label), \(model.sort.ascending ? "aufsteigend" : "absteigend")")
        }

        // 4a. Anpassungen: Zustände (ändern die Darstellung, nicht die Datenmenge)
        // Als Gruppe: SwiftUI erlaubt hoechstens zehn ToolbarItems je Builder.
        ToolbarItemGroup(placement: .navigation) {
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
                offState: model.viewMode == .tree ? "sind ausgeblendet" : "nicht alle aufgeklappt"
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
        ToolbarItem(placement: .navigation) {
            Button {
                model.scrollToTopToken += 1
            } label: {
                Image(systemName: "arrow.up.to.line")
                    .foregroundStyle(ToolbarStateToggle.idleTint)
            }
            .help("An den Anfang der Liste springen (⌘↑)")
            .accessibilityLabel("An den Anfang der Liste springen")
        }

        // --- Status ---
        // Fester Platz: Der Block ist immer vorhanden und nur waehrend einer
        // Suche sichtbar. Sonst wuerden die Nachbarelemente beim Ein- und
        // Ausblenden hin- und herspringen.
        ToolbarItem(placement: .navigation) {
            HStack(spacing: 6) {
                if model.isScanning || model.isLoadingDetails {
                    ProgressView().controlSize(.small)
                    Button {
                        model.cancelScan()
                    } label: {
                        Image(systemName: "stop.circle.fill").foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                    .help("Suche abbrechen")
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
            Button("Ordner wählen …") { showImporter = true }
            if !model.recentFolders.isEmpty {
                Divider()
                Section("Zuletzt genutzt") {
                    ForEach(model.recentFolders, id: \.self) { url in
                        Button(url.lastPathComponent) { model.setRoot(url) }
                            .help(url.path)
                    }
                }
            }
        } label: {
            Label(model.rootURL.lastPathComponent, systemImage: "folder")
        }
        // Ordnername ausdruecklich MIT Beschriftung: Der aktuelle Ordner ist die
        // wichtigste Zustandsinformation der App – ein blosses Ordnersymbol
        // verschweigt sie.
        .labelStyle(.titleAndIcon)
        .help("Wurzelordner wählen · aktuell: \(model.rootURL.path)")
        .accessibilityLabel("Ordner wählen")
        .accessibilityValue(model.rootURL.lastPathComponent)
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                model.setRoot(url)
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
                get: { model.timeMode },
                set: { model.setTimeMode($0) }
            )) {
                Text("Tage").tag(TimeMode.rolling)
                Text("Spanne").tag(TimeMode.range)
                Text("Alle").tag(TimeMode.all)
            }
            .pickerStyle(.segmented)
            .fixedSize()
            .help("Rollierende Tage, feste Zeitspanne oder ohne Zeitgrenze (reines Suchen)")
            .accessibilityLabel("Zeitmodus")

            if model.ignoreTimeWindow {
                EmptyView()
            } else if model.useDateRange {
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
            } else {
                Picker("", selection: Binding(
                    get: { presetSelection },
                    set: { applyPreset($0) }
                )) {
                    // „Heute" statt „1": Der Sonderfall verdient seinen Namen –
                    // ein alleinstehendes „1" wirft die Frage „eins was?" auf.
                    // Seit das Fenster in Kalendertagen rechnet, stimmt es auch:
                    // 1 Tag = ab Tagesbeginn.
                    Text("Heute").tag(1)
                    // Echtes Minuszeichen (U+2212), nicht der Bindestrich: Es
                    // steht auf Zifferhoehe und liest sich als Vorzeichen, nicht
                    // als Trennstrich. Die Zahlen zeigen damit, wohin es geht –
                    // rueckwaerts.
                    Text("\u{2212}3").tag(3)
                    Text("\u{2212}7").tag(7)
                    Text("\u{2212}30").tag(30)
                    Text("\u{2212}90").tag(90)
                    Image(systemName: "slider.horizontal.3").tag(-1)
                }
                .pickerStyle(.segmented)
                .fixedSize()
                .help("Zeitraum in Kalendertagen bis heute · „Heute“ = ab 0 Uhr")
            .accessibilityLabel("Zeitraum in Tagen")
                .popover(isPresented: $showCustomDays, arrowEdge: .bottom) {
                    customDaysEditor
                }
            }
        }
    }

    /// Aktuelle Auswahl: ein Preset oder „Eigene …" (−1).
    private var presetSelection: Int {
        [1, 3, 7, 30, 90].contains(model.days) ? model.days : -1
    }

    private func applyPreset(_ value: Int) {
        if value == -1 {
            showCustomDays = true
        } else {
            model.setDays(value)
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

    /// Farbe untaetiger Titelleisten-Symbole.
    ///
    /// ``Color/primary`` statt der System-Steuerfarbe: Letztere wird im
    /// inaktiven Fenster bis zur Unlesbarkeit aufgehellt.
    static let idleTint = Color.primary

    private var stateText: String { isOn ? onState : offState }

    var body: some View {
        Toggle(isOn: $isOn) {
            Image(systemName: isOn ? onSymbol : offSymbol)
                .foregroundStyle(isOn ? Color.accentColor : Self.idleTint)
        }
        .toggleStyle(.button)
        .help("\(label) · aktuell: \(stateText)")
        .accessibilityLabel(label)
        .accessibilityValue(stateText)
    }
}
