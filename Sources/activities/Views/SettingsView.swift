import SwiftUI
import ActivitiesCore

/// Einstellungen (⌘,) – **alle** Regeln des Rauschfilters an einer Stelle.
///
/// **Entwurfsgrundsatz:** Aus Anwendersicht darf es nur *eine* Antwort auf die
/// Frage „warum sehe ich diesen Ordner nicht?" geben. Vorher entschieden fünf
/// Mechanismen darüber, von denen nur zwei sichtbar waren – die interne
/// Unterscheidung „eindeutig/mehrdeutig" war in die Oberfläche durchgeschlagen.
/// Jetzt steht **eine Liste**; die mehrdeutigen Namen sind darin lediglich nicht
/// vorangekreuzt. Was sich nicht ändern lässt, wird wenigstens **benannt**.
struct SettingsView: View {
    @Bindable var model: ReportViewModel
    @State private var newRule = ""
    @State private var launchesAtLogin = AppPresence.launchesAtLogin
    @State private var loginError: String?
    @State private var showAppPicker = false
    /// Welcher Platz die Wahl aus dem Programme-Dialog entgegennimmt.
    @State private var pickerApply: ((ExternalApp?) -> Void)?
    /// Ordner-Dialog des Quellen-Reiters.
    @State private var showSourceImporter = false

    var body: some View {
        TabView {
            generalTab
                .tabItem { Label("Allgemein", systemImage: "gearshape") }
            sourcesTab
                .tabItem { Label("Quellen", systemImage: "folder") }
            noiseTab
                .tabItem { Label("Rauschfilter", systemImage: "eye.slash") }
            // Eigener Reiter, kein Abschnitt im Rauschfilter: andere Schluessel
            // (Endungen statt Ordnernamen), anderer Zeitpunkt (Anzeige statt
            // Suchlauf). Begruendung in ``FileTypesSettingsView``.
            FileTypesSettingsView(model: model)
                .tabItem { Label("Dateitypen", systemImage: "doc.badge.gearshape") }
        }
        .frame(width: 620, height: 520)
    }

    private var generalTab: some View {
        Form {
            Section {
                Toggle(isOn: Binding(
                    get: { model.showsDockIcon },
                    set: { model.setShowsDockIcon($0) }
                )) {
                    Text("Im Dock anzeigen")
                    Text("Ausgeschaltet lebt activities nur in der Menüleiste.")
                        .font(.caption).foregroundStyle(.secondary)
                }

                Toggle(isOn: Binding(
                    get: { launchesAtLogin },
                    set: { neu in
                        loginError = AppPresence.setLaunchesAtLogin(neu)
                        launchesAtLogin = AppPresence.launchesAtLogin
                    }
                )) {
                    Text("Beim Anmelden starten")
                    if let loginError {
                        Text(loginError)
                            .font(.caption).foregroundStyle(.red)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text("Die App muss dafür in „Programme“ liegen.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Verhalten")
            }

            Section {
                Picker("Schriftgröße der Liste", selection: Binding(
                    get: { model.rowSize },
                    set: { model.setRowSize($0) }
                )) {
                    ForEach(RowSize.allCases) { stufe in
                        Text(stufe.label).tag(stufe)
                    }
                }
                .pickerStyle(.segmented)
                // ⚠️ Nennt die Zahlen, statt „klein/mittel/groß" raten zu lassen.
                // Wer die Wahl trifft, soll wissen, worin sie besteht – und die
                // Zahlen sind gemessen, nicht gegriffen.
                Text("Dateinamen \(Int(model.rowSize.nameFontSize)) pt, Datum und Größe "
                     + "\(Int(model.rowSize.metaFontSize)) pt. Die Zeilenhöhe bleibt in allen "
                     + "Stufen gleich – die Liste zeigt also gleich viele Einträge.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } header: {
                Text("Darstellung")
            }

            Section {
                appSlot(
                    title: "Editor",
                    // ⚠️ Stand hier als „⌘⇧E" – falsche Reihenfolge. macOS setzt ⌃⌥⇧⌘,
                    // und ``ShortcutModifiers/display`` haelt das fest. Aus dem
                    // Katalog gelesen kann es nicht mehr abweichen.
                    hint: "Erscheint als „In … öffnen“ im Kontextmenü (\(Shortcuts.openInEditor.display)).",
                    current: model.editorApp,
                    candidates: ExternalAppService.editorCandidates,
                    apply: { model.setEditorApp($0) }
                )
                appSlot(
                    title: "Terminal",
                    hint: "Öffnet den Ordner, bei Dateien deren Ordner (\(Shortcuts.openInTerminal.display)).",
                    current: model.terminalApp,
                    candidates: ExternalAppService.terminalCandidates,
                    apply: { model.setTerminalApp($0) }
                )
            } header: {
                Text("Programme")
            } footer: {
                Text("Vorbelegt wird, was tatsächlich installiert ist. Gespeichert wird die "
                     + "Bundle-Kennung, nicht der Pfad – ein verschobenes Programm wird weiter gefunden.")
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }

            Section("Tastenkürzel") {
                LabeledContent("Fenster nach vorn holen") {
                    Text(Shortcuts.bringToFront.display).font(.system(.body, design: .monospaced))
                }
                Text("Wirkt aus jedem Programm heraus – ohne zusätzliche Systemfreigabe.")
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .formStyle(.grouped)
        .fileImporter(
            isPresented: $showAppPicker,
            allowedContentTypes: [.application],
            allowsMultipleSelection: false
        ) { result in
            guard case .success(let urls) = result,
                  let url = urls.first,
                  let picked = ExternalAppService.app(at: url)
            else { return }
            pickerApply?(picked)
        }
    }

    /// Ein Programmplatz: aktuelle Wahl, erkannte Kandidaten, freie Auswahl.
    ///
    /// Bewusst ein Menue und keine Liste zum Verwalten: Es geht um **einen**
    /// Wert je Platz. Eine Verwaltungsoberflaeche fuer beliebig viele Programme
    /// waere Vorrat auf einen Bedarf, den es nicht gibt.
    @ViewBuilder
    private func appSlot(
        title: String,
        hint: String,
        current: ExternalApp?,
        candidates: [String],
        apply: @escaping (ExternalApp?) -> Void
    ) -> some View {
        LabeledContent {
            Menu(current?.name ?? "Keines") {
                ForEach(ExternalAppService.installed(among: candidates)) { app in
                    Button(app.name) { apply(app) }
                }
                Divider()
                Button("Anderes Programm …") {
                    pickerApply = apply
                    showAppPicker = true
                }
                Button("Keines") { apply(nil) }
            }
            .fixedSize()
        } label: {
            Text(title)
            Text(hint)
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    /// Verwaltung des Quellen-Bestands (PR-19).
    ///
    /// **⚠️ Auswaehlen steht im Menue, Loeschen hier – und das ist dieselbe
    /// Regel, nach der die Menueleiste geordnet ist:** Was man mehrmals am Tag
    /// tut, gehoert an den kurzen Weg; was selten und unwiderruflich ist, hinter
    /// eine Tuer. Ein Loeschknopf neben jedem Haken waere ein Fehlklick mit
    /// Datenverlust.
    private var sourcesTab: some View {
        Form {
            Section {
                if model.sources.known.isEmpty {
                    Text("Keine Quelle eingetragen.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(model.sources.known, id: \.self) { url in
                        HStack {
                            Toggle(isOn: Binding(
                                get: { model.sources.isActive(url) },
                                set: { model.setSourceActive(url, $0) }
                            )) {
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(url.lastPathComponent)
                                    Text(model.sourcePath(for: url))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }
                            }
                            Spacer()
                            Button("Entfernen") { model.removeSource(url) }
                                .buttonStyle(.link)
                                .font(.caption)
                        }
                    }
                }
                Button("Quelle hinzufügen …") { showSourceImporter = true }
            } header: {
                Text("Durchsuchte Ordner")
            } footer: {
                Text("Abgewählte Quellen bleiben in der Liste – nur ihre Dateien zählen nicht. "
                     + "Ein Ordner, der bereits in einer Quelle liegt, wird abgelehnt: Er würde "
                     + "jede Datei doppelt zählen. Die App fragt dann, ob die vorhandene Quelle "
                     + "angehakt oder durch den neuen Ordner ersetzt werden soll.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .formStyle(.grouped)
        .fileImporter(
            isPresented: $showSourceImporter,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls): model.addSources(urls)
            case .failure(let fehler): model.reportSourceImportFailure(fehler)
            }
        }
    }

    private var noiseTab: some View {
        Form {
            Section {
                ForEach(model.allFolderRuleNames, id: \.self) { name in
                    Toggle(isOn: Binding(
                        get: { model.activeFolderRules.contains(name) },
                        set: { model.setFolderRule(name, active: $0) }
                    )) {
                        HStack(spacing: 6) {
                            Text(name).font(.system(.body, design: .monospaced))
                            if ExclusionRules.ambiguousBuildFolders.contains(name) {
                                Text("kann auch ein echter Projektordner sein")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                HStack {
                    TextField("Weiterer Ordnername …", text: $newRule)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { addRule() }
                    Button("Hinzufügen", action: addRule)
                        .disabled(newRule.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            } header: {
                HStack {
                    Text("Ordner, die übersprungen werden")
                    Spacer()
                    Button("Auf Empfehlung zurücksetzen") { model.resetFolderRules() }
                        .buttonStyle(.link)
                        .font(.caption)
                }
            } footer: {
                Text("Namen wie „build\" oder „dist\" sind nicht vorangekreuzt – sie können auch "
                     + "echte Projektordner sein. Ordner mit diesen Namen werden samt Inhalt "
                     + "übersprungen.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }

            Section("Von dir ausgeblendete Ordner") {
                if model.excludedPaths.isEmpty {
                    Text("Keine. Über das Kontextmenü einer Ordnerzeile lässt sich "
                         + "„Diesen Ordner nicht mehr zeigen\" wählen.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    ForEach(model.excludedPaths.sorted(), id: \.self) { path in
                        HStack {
                            Text(path)
                                .font(.callout)
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .help(path)
                            Spacer()
                            Button("Wieder zeigen") { model.showFolderAgain(path) }
                                .buttonStyle(.link)
                        }
                    }
                }
            }

            // Was sich nicht einstellen lässt, wird wenigstens benannt – sonst
            // bleibt es ein stiller Zustand.
            Section("Immer übersprungen") {
                labelled("Versteckte Objekte",
                         "Alles, was mit einem Punkt beginnt (.git, .build, .venv) sowie "
                         + "vom System als versteckt markierte Objekte.")
                labelled("Systemdateien",
                         ExclusionRules.default.filePatterns.joined(separator: ", "))
                labelled("App-Bündel",
                         "Programme und Dokumentbündel (.app, .rtfd, .photoslibrary …) zählen "
                         + "als eine Datei – ihr Innenleben ist keine Arbeit.")
            }
        }
        .formStyle(.grouped)
    }

    private func labelled(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func addRule() {
        model.addFolderRule(newRule)
        newRule = ""
    }
}
