import SwiftUI
import UniformTypeIdentifiers

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
                prompt: "Name filtern, z. B. studium",
                onSubmit: { model.applyWindowChange() }
            )
            .frame(width: 220)
            .help("Teil des Dateinamens eingeben. Platzhalter * und ? sind zusätzlich möglich. Enter startet die Suche.")
        }

        // 3. Zeitraum
        ToolbarItem(placement: .navigation) {
            timeRangeControls
        }

        // 4a. Anpassungen: Zustände (ändern die Darstellung, nicht die Datenmenge)
        ToolbarItem(placement: .navigation) {
            Toggle(isOn: Binding(
                get: { model.allExpanded },
                set: { model.setAllExpanded($0) }
            )) {
                Image(systemName: "chevron.up.chevron.down")
            }
            .toggleStyle(.button)
            .help("Alle Ordner auf- oder zuklappen")
        }

        ToolbarItem(placement: .navigation) {
            Toggle(isOn: Binding(
                get: { model.showOutOfWindowFiles },
                set: { model.setShowOutOfWindowFiles($0) }
            )) {
                Image(systemName: "clock.badge.xmark")
            }
            .toggleStyle(.button)
            .help(model.showOutOfWindowFiles
                  ? "Dateien außerhalb des Zeitraums werden angezeigt"
                  : "Dateien außerhalb des Zeitraums sind ausgeblendet")
        }

        ToolbarItem(placement: .navigation) {
            Toggle(isOn: Binding(
                get: { model.autoRefresh },
                set: { model.setAutoRefresh($0) }
            )) {
                Image(systemName: "arrow.triangle.2.circlepath")
            }
            .toggleStyle(.button)
            .help("Automatisch aktualisieren, wenn sich der Ordner ändert")
        }

        // 4b. Anpassungen: Aktionen
        ToolbarItem(placement: .navigation) {
            Button {
                model.scrollToTopToken += 1
            } label: {
                Image(systemName: "arrow.up.to.line")
            }
            .help("An den Anfang der Liste springen (⌘↑)")
        }

        ToolbarItem(placement: .navigation) {
            Button {
                model.rescan()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .help("Suche neu starten (⌘R)")
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
                get: { model.useDateRange },
                set: { model.setUseDateRange($0) }
            )) {
                Text("Tage").tag(false)
                Text("Spanne").tag(true)
            }
            .pickerStyle(.segmented)
            .fixedSize()
            .help("Rollierende Tage oder feste Zeitspanne")

            if model.useDateRange {
                DatePicker("", selection: Binding(
                    get: { model.rangeStart },
                    set: { model.setRangeStart($0) }
                ), in: ...model.rangeEnd, displayedComponents: .date)
                .datePickerStyle(.field).labelsHidden()
                .help("Von (inklusive)")

                Text("–").foregroundStyle(.secondary)

                DatePicker("", selection: Binding(
                    get: { model.rangeEnd },
                    set: { model.setRangeEnd($0) }
                ), in: model.rangeStart...Date(), displayedComponents: .date)
                .datePickerStyle(.field).labelsHidden()
                .help("Bis (inklusive ganzem Tag, max. heute)")
            } else {
                Picker("", selection: Binding(
                    get: { presetSelection },
                    set: { applyPreset($0) }
                )) {
                    Text("7").tag(7)
                    Text("30").tag(30)
                    Text("90").tag(90)
                    Image(systemName: "slider.horizontal.3").tag(-1)
                }
                .pickerStyle(.segmented)
                .fixedSize()
                .help("Zeitraum in Tagen")
                .popover(isPresented: $showCustomDays, arrowEdge: .bottom) {
                    customDaysEditor
                }
            }
        }
    }

    /// Aktuelle Auswahl: ein Preset oder „Eigene …" (−1).
    private var presetSelection: Int {
        [7, 30, 90].contains(model.days) ? model.days : -1
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
    }
}
