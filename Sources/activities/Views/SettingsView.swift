import SwiftUI
import ActivitiesCore

/// Einstellungen (⌘,) – bislang ausschließlich der **Rauschfilter**.
///
/// Ein Einstellungen-Fenster war im Backlog lange als UX-24 geführt und wurde
/// dort **verworfen**, weil es nichts zu zeigen gehabt hätte. Mit den
/// Ausschlussregeln gibt es nun einen echten Inhalt – das ist der Grund, warum
/// es jetzt entsteht und vorher nicht.
struct SettingsView: View {
    @Bindable var model: ReportViewModel

    var body: some View {
        TabView {
            noiseTab
                .tabItem { Label("Rauschfilter", systemImage: "eye.slash") }
        }
        .frame(width: 520, height: 400)
    }

    private var noiseTab: some View {
        Form {
            Section {
                Toggle(isOn: Binding(
                    get: { model.excludeAmbiguousBuildFolders },
                    set: { model.setExcludeAmbiguousBuildFolders($0) }
                )) {
                    Text("Auch mehrdeutige Erzeugnis-Ordner ausblenden")
                    Text(ExclusionRules.ambiguousBuildFolders.sorted().joined(separator: ", "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Werkzeug-Erzeugnisse")
            } footer: {
                Text("Ordner wie \(ExclusionRules.unambiguousBuildFolders.sorted().prefix(4).joined(separator: ", ")) "
                     + "und App-Bündel werden immer übersprungen – dort arbeitet niemand. "
                     + "Namen wie „build\" oder „dist\" können dagegen auch echte Projektordner sein "
                     + "und bleiben deshalb standardmäßig sichtbar.")
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
        }
        .formStyle(.grouped)
    }
}
