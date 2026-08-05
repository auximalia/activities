import SwiftUI
import UniformTypeIdentifiers

/// Steuerleiste: Ordnerwahl (mit zuletzt genutzten), Zeitraum-Presets, Filter,
/// Auto-Refresh und "Aktualisieren".
struct ControlsView: View {
    @Bindable var model: ReportViewModel
    var updates: UpdateChecker
    @State private var showImporter = false
    @FocusState private var filterFocused: Bool

    /// Tage-Eingabe, geklemmt auf 1…3650 (nicht-negative ganze Zahlen).
    private var daysBinding: Binding<Int> {
        Binding(
            get: { model.days },
            set: { model.days = min(max($0, 1), 3650) }
        )
    }

    var body: some View {
        HStack(spacing: 12) {
            folderMenu

            Divider().frame(height: 18)

            Picker("", selection: Binding(
                get: { model.useDateRange },
                set: { model.setUseDateRange($0) }
            )) {
                Text("Tage").tag(false)
                Text("Zeitspanne").tag(true)
            }
            .pickerStyle(.segmented)
            .fixedSize()
            .help("Zeitraum als rollierende Tage oder feste Zeitspanne (von–bis)")

            if model.useDateRange {
                DatePicker("", selection: Binding(
                    get: { model.rangeStart },
                    set: { model.setRangeStart($0) }
                ), in: ...model.rangeEnd, displayedComponents: .date)
                .datePickerStyle(.field)
                .labelsHidden()
                .help("Von (inklusive)")

                Text("–").foregroundStyle(.secondary)

                DatePicker("", selection: Binding(
                    get: { model.rangeEnd },
                    set: { model.setRangeEnd($0) }
                ), in: model.rangeStart...Date(), displayedComponents: .date)
                .datePickerStyle(.field)
                .labelsHidden()
                .help("Bis (inklusive ganzem Tag, max. heute)")
            } else {
                Picker("", selection: Binding(
                    get: { model.days },
                    set: { model.days = $0 }
                )) {
                    Text("7").tag(7)
                    Text("30").tag(30)
                    Text("90").tag(90)
                }
                .pickerStyle(.segmented)
                .fixedSize()
                .help("Zeitraum in Tagen")

                HStack(spacing: 4) {
                    TextField("", value: daysBinding, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 48)
                        .multilineTextAlignment(.trailing)
                        .help("Tage manuell eingeben (1–3650)")
                    Text("Tage").foregroundStyle(.secondary)
                    Stepper("", value: daysBinding, in: 1...3650)
                        .labelsHidden()
                }
                .fixedSize()
            }

            TextField("Filter, z. B. *Studium*.xls*", text: $model.namePattern)
                .textFieldStyle(.roundedBorder)
                .frame(minWidth: 180, maxWidth: 300)
                .focused($filterFocused)
                .onSubmit { model.rescan() }
                .help("Namensfilter (Glob-Muster * und ?) für Datei- und Ordnernamen · Enter startet die Suche")

            Button {
                model.rescan()
            } label: {
                Label("Aktualisieren", systemImage: "arrow.clockwise")
            }
            .keyboardShortcut("r", modifiers: .command)
            .help("Suche neu starten (⌘R)")

            Toggle(isOn: Binding(
                get: { model.allExpanded },
                set: { model.setAllExpanded($0) }
            )) {
                Image(systemName: "chevron.up.chevron.down")
            }
            .toggleStyle(.switch)
            .controlSize(.mini)
            .help("Alle Ordner auf- oder zuklappen")

            Button {
                model.scrollToTopToken += 1
            } label: {
                Image(systemName: "arrow.up.to.line")
            }
            .buttonStyle(.borderless)
            .help("An den Anfang der Liste springen (⌘↑)")

            Toggle(isOn: Binding(
                get: { model.autoRefresh },
                set: { model.setAutoRefresh($0) }
            )) {
                Image(systemName: "arrow.triangle.2.circlepath")
            }
            .toggleStyle(.switch)
            .controlSize(.mini)
            .help("Automatisch aktualisieren, wenn sich der Ordner aendert")

            // Fortschritt/Abbrechen: fester Platz, damit die Leiste beim Ein-/Ausblenden nicht springt.
            HStack(spacing: 6) {
                if model.isScanning || model.isLoadingDetails {
                    ProgressView().controlSize(.small)
                    if model.isScanning {
                        Text("\(model.scanProgress) Dateien")
                            .font(.caption).monospacedDigit().foregroundStyle(.secondary).lineLimit(1)
                    } else if model.detailTotal > 0 {
                        Text("\(model.detailDone)/\(model.detailTotal)")
                            .font(.caption).monospacedDigit().foregroundStyle(.secondary).lineLimit(1)
                    }
                    Button {
                        model.cancelScan()
                    } label: {
                        Image(systemName: "stop.circle.fill")
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                    .help("Suche abbrechen")
                }
            }
            .frame(width: 170, alignment: .leading)

            Spacer(minLength: 0)

            // Update-Hinweis: erscheint nur, wenn im Repo eine neuere Version liegt.
            if updates.showsUpdateBadge, let latest = updates.latestVersion {
                Button {
                    updates.installUpdate()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down.circle.fill")
                        Text("\(BuildInfo.short) → \(latest.description)")
                            .font(.caption)
                            .monospacedDigit()
                    }
                    .foregroundStyle(.tint)
                    .lineLimit(1)
                }
                .buttonStyle(.plain)
                .help("Update verfügbar (installiert \(BuildInfo.short), verfügbar \(latest.description)) – klicken zum Installieren")
            }

            VStack(alignment: .trailing, spacing: 1) {
                Text("designed by matthias.riedel.dresden")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text(BuildInfo.short)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .help(BuildInfo.details)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .layoutPriority(-1)
        }
        .padding(10)
        .onChange(of: model.days) { _, _ in model.rescan() }
        .onChange(of: model.filterFocusToken) { _, _ in filterFocused = true }
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
                .lineLimit(1)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help("Wurzelordner wählen (zuletzt genutzte im Menü) · aktuell: \(model.rootURL.path)")
    }
}
