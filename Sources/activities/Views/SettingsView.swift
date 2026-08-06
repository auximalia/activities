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

    var body: some View {
        TabView {
            noiseTab
                .tabItem { Label("Rauschfilter", systemImage: "eye.slash") }
        }
        .frame(width: 560, height: 480)
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
