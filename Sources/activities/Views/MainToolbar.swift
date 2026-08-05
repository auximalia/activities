import SwiftUI
import UniformTypeIdentifiers

/// Die Bedienelemente in der Titelleiste.
///
/// **Warum Toggle-Buttons statt `Switch`?** Laut HIG gehören Schalter in
/// Einstellungs-Formulare; in Toolbars gehören Knöpfe mit sichtbarem
/// Aktiv-Zustand hin. Zusätzlich sind sie deutlich kompakter.
///
/// Gruppiert nach Art – **Zustände** und **Aktionen** stehen nicht mehr
/// ununterscheidbar nebeneinander. Reicht die Breite nicht, klappt macOS die
/// hinteren Elemente automatisch in ein Überlauf-Menü.
struct MainToolbar: ToolbarContent {
    @Bindable var model: ReportViewModel
    var updates: UpdateChecker
    @State private var showImporter = false
    @State private var showCustomDays = false

    var body: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            folderMenu
        }

        ToolbarItem {
            timeRangeControls
        }

        // --- Zustände ---
        ToolbarItem {
            Toggle(isOn: Binding(
                get: { model.allExpanded },
                set: { model.setAllExpanded($0) }
            )) {
                Image(systemName: "chevron.up.chevron.down")
            }
            .toggleStyle(.button)
            .help("Alle Ordner auf- oder zuklappen")
        }

        ToolbarItem {
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

        ToolbarItem {
            Toggle(isOn: Binding(
                get: { model.autoRefresh },
                set: { model.setAutoRefresh($0) }
            )) {
                Image(systemName: "arrow.triangle.2.circlepath")
            }
            .toggleStyle(.button)
            .help("Automatisch aktualisieren, wenn sich der Ordner ändert")
        }

        // --- Aktionen ---
        ToolbarItem {
            Button {
                model.scrollToTopToken += 1
            } label: {
                Image(systemName: "arrow.up.to.line")
            }
            .help("An den Anfang der Liste springen (⌘↑)")
        }

        ToolbarItem {
            Button {
                model.rescan()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .help("Suche neu starten (⌘R)")
        }

        // --- Status ---
        ToolbarItem {
            if model.isScanning || model.isLoadingDetails {
                HStack(spacing: 6) {
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
            model.days = value
        }
    }

    /// Feineinstellung – erscheint nur auf Anforderung, statt dauerhaft neben
    /// den Presets Platz zu belegen.
    private var customDaysEditor: some View {
        HStack(spacing: 6) {
            Text("Tage:")
            TextField("", value: Binding(
                get: { model.days },
                set: { model.days = min(max($0, 1), 3650) }
            ), format: .number)
            .textFieldStyle(.roundedBorder)
            .frame(width: 60)
            .multilineTextAlignment(.trailing)
            Stepper("", value: Binding(
                get: { model.days },
                set: { model.days = min(max($0, 1), 3650) }
            ), in: 1...3650)
            .labelsHidden()
        }
        .padding(12)
        .help("Tage manuell eingeben (1–3650)")
    }
}
