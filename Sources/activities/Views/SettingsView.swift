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

    var body: some View {
        TabView {
            generalTab
                .tabItem { Label("Allgemein", systemImage: "gearshape") }
            noiseTab
                .tabItem { Label("Rauschfilter", systemImage: "eye.slash") }
        }
        .frame(width: 560, height: 480)
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
                appSlot(
                    title: "Editor",
                    hint: "Erscheint als „In … öffnen“ im Kontextmenü (⌘⇧E).",
                    current: model.editorApp,
                    candidates: ExternalAppService.editorCandidates,
                    apply: { model.setEditorApp($0) }
                )
                appSlot(
                    title: "Terminal",
                    hint: "Öffnet den Ordner, bei Dateien deren Ordner (⌘⇧T).",
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
                    Text("⌥⌘A").font(.system(.body, design: .monospaced))
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
