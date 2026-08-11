import SwiftUI
import ActivitiesCore

/// Reiter „Dateitypen“: je Endung eine Zeile, zwei Häkchen, eine Schranke.
///
/// **⚠️ Eigener Reiter und kein Abschnitt im Rauschfilter.** Die beiden sehen
/// verwandt aus und sind es nicht: Der Rauschfilter arbeitet auf **Ordnernamen**
/// und wirkt im **Suchlauf** (`skipDescendants` – die Datei entsteht nie), diese
/// Tabelle arbeitet auf **Endungen** und wirkt bei der **Anzeige**, ohne
/// Neulesen umkehrbar. Sie teilen keinen Schlüsselraum. Wer beides in einen
/// Reiter legt, lässt den ersten Anwender vergeblich nach `.git` in der
/// Endungsliste suchen.
struct FileTypesSettingsView: View {
    @Bindable var model: ReportViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Welche Dateitypen als Arbeitsdateien gelten – und welche „Arbeit fortsetzen“ öffnen darf.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Table(model.typeInventory) {
                TableColumn("Endung") { zeile in
                    Text(".\(zeile.ext)").font(.system(.body, design: .monospaced))
                }
                .width(min: 80, ideal: 90)

                TableColumn("Dateien") { zeile in
                    Text("\(zeile.count)")
                        .monospacedDigit()
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .width(min: 55, ideal: 60)

                TableColumn("Standardprogramm") { zeile in
                    Text(FileTypeInspector.defaultApplicationName(forOpening: zeile.sample)
                         ?? "keine Zuordnung")
                        .foregroundStyle(
                            FileTypeInspector.defaultApplicationName(forOpening: zeile.sample) == nil
                            ? .secondary : .primary
                        )
                }
                .width(min: 130, ideal: 170)

                TableColumn("Office") { zeile in
                    OfficeHaken(model: model, ext: zeile.ext, beispiel: zeile.sample)
                }
                .width(min: 70, ideal: 70)

                TableColumn("Arbeit fortsetzen") { zeile in
                    FortsetzenHaken(model: model, ext: zeile.ext, beispiel: zeile.sample)
                }
                .width(min: 130, ideal: 140)
            }
            .frame(minHeight: 260)

            // ⚠️ Der Satz nennt die Regel, nicht die Bedienung. Dass man
            // Haeckchen setzt, sieht man; **warum** manche nicht gehen, nicht.
            Label(
                "Skripte, Programme und Abbilder lassen sich nicht für „Arbeit fortsetzen“ "
                + "freigeben – sie würden beim Öffnen ausgeführt. Ein Doppelklick auf eine "
                + "einzelne Datei öffnet dagegen immer alles.",
                systemImage: "lock.shield"
            )
            .font(.callout)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

            HStack {
                Spacer()
                Button("Eigene Freigaben zurücksetzen") { model.typeRules = .leer }
                    .disabled(model.typeRules == .leer)
            }
        }
        .padding(20)
    }
}

/// Häkchen „Office“: ergänzt die Sichtbarkeitsliste.
private struct OfficeHaken: View {
    @Bindable var model: ReportViewModel
    let ext: String
    let beispiel: URL

    private var eingebaut: Bool { WorkFileFilter.isWorkFile(beispiel) }

    var body: some View {
        Toggle("", isOn: Binding(
            get: { eingebaut || model.typeRules.extraVisible.contains(ext) },
            set: { an in
                var sichtbar = model.typeRules.extraVisible
                var fortsetzbar = model.typeRules.extraResumable
                if an { sichtbar.insert(ext) } else {
                    sichtbar.remove(ext)
                    // Die Zusicherung gilt auch beim Abwaehlen: Was nicht
                    // sichtbar ist, bleibt nicht fortsetzbar.
                    fortsetzbar.remove(ext)
                }
                model.typeRules = FileTypeRules(extraVisible: sichtbar, extraResumable: fortsetzbar)
            }
        ))
        .labelsHidden()
        // ⚠️ Eingebaute Typen sind gesetzt und nicht abwaehlbar – die Tabelle
        // ergaenzt, sie ersetzt nicht (siehe ``FileTypeRules``). Der Kurzhinweis
        // sagt den Grund, sonst wirkt es wie ein Fehler.
        .disabled(eingebaut)
        .help(eingebaut
              ? "Gehört fest zu den Arbeitsdateien und kann hier nicht abgewählt werden."
              : "Diese Dateien erscheinen, wenn der Office-Filter an ist.")
    }
}

/// Häkchen „Arbeit fortsetzen“: ergänzt die **Ausführungs**liste – mit Schranke.
private struct FortsetzenHaken: View {
    @Bindable var model: ReportViewModel
    let ext: String
    let beispiel: URL

    private var eingebaut: Bool { WorkDays.isResumable(beispiel) }
    private var sichtbar: Bool {
        WorkFileFilter.isWorkFile(beispiel) || model.typeRules.extraVisible.contains(ext)
    }
    private var ablehnung: String? { FileTypeInspector.resumeRejection(forExtension: ext) }

    var body: some View {
        HStack(spacing: 6) {
            Toggle("", isOn: Binding(
                get: { eingebaut || model.typeRules.extraResumable.contains(ext) },
                set: { an in
                    guard ablehnung == nil else { return }
                    var fortsetzbar = model.typeRules.extraResumable
                    if an { fortsetzbar.insert(ext) } else { fortsetzbar.remove(ext) }
                    model.typeRules = FileTypeRules(
                        extraVisible: model.typeRules.extraVisible,
                        extraResumable: fortsetzbar
                    )
                }
            ))
            .labelsHidden()
            // Drei Gruende, warum das Haeckchen nicht geht – und nur einer davon
            // ist eine Sperre. Die anderen beiden sind Zusicherungen:
            // eingebaut = schon an, nicht sichtbar = darf nicht fortsetzbar sein.
            .disabled(eingebaut || ablehnung != nil || !sichtbar)

            if ablehnung != nil {
                Image(systemName: "lock.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
        }
        .help(hinweis)
        .accessibilityLabel("Arbeit fortsetzen für .\(ext)")
        .accessibilityValue(hinweis)
    }

    private var hinweis: String {
        if let ablehnung { return ablehnung }
        if eingebaut { return "Gehört fest zu den Dateien, die wieder aufgeschlagen werden." }
        if !sichtbar { return "Erst als Arbeitsdatei freigeben – was man öffnen kann, soll man auch sehen." }
        return "„Arbeit fortsetzen“ darf diese Dateien öffnen."
    }
}
