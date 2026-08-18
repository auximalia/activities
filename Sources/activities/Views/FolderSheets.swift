import SwiftUI
import ActivitiesCore

/// Blatt: Name für einen neuen Ordner.
///
/// **⚠️ Ein Blatt und keine Bearbeitung in der Zeile.** Die Dateizeile trägt
/// bereits drei Erkenner, und die Quelle hält zwei Regressionen fest, die aus
/// deren Zusammenspiel entstanden sind — erst verschluckte die
/// `DragGesture(minimumDistance: 0)` das Ziehen, dann verschluckten beide
/// zusammen den Doppelklick. Ein Textfeld darin wäre der vierte.
struct NewFolderSheet: View {
    @Bindable var model: ReportViewModel
    let pending: ReportViewModel.PendingFolderName

    @State private var name = "Neuer Ordner"
    @FocusState private var imFeld: Bool

    private var ablehnung: FolderNaming.Rejection? {
        FolderNaming.rejection(for: name, existing: pending.existing)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(pending.withSelection.isEmpty
                 ? "Neuer Ordner in \u{201E}\(pending.parent.lastPathComponent)\u{201C}"
                 : "Neuer Ordner mit \(pending.withSelection.count) "
                   + "\(pending.withSelection.count == 1 ? "Datei" : "Dateien")")
                .font(.headline)

            TextField("Name", text: $name)
                .textFieldStyle(.roundedBorder)
                .focused($imFeld)
                .onSubmit { if ablehnung == nil { model.confirmNewFolder(named: name) } }

            // ⚠️ Der Grund steht DA, nicht nur der abgeblendete Knopf. Ein
            // Knopf, der nicht geht, ohne zu sagen warum, ist ein Raetsel.
            if let ablehnung {
                Label(ablehnung.reason, systemImage: "exclamationmark.triangle")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else if !pending.withSelection.isEmpty {
                Text("Die markierten Dateien werden anschließend hineinverschoben.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Spacer()
                Button("Abbrechen", role: .cancel) { model.cancelNewFolder() }
                    .keyboardShortcut(.cancelAction)
                Button("Anlegen") { model.confirmNewFolder(named: name) }
                    .keyboardShortcut(.defaultAction)
                    .disabled(ablehnung != nil)
            }
        }
        .padding(20)
        .frame(width: 380)
        .onAppear { imFeld = true }
    }
}

/// Blatt: neuer Name für eine Datei oder einen Ordner.
struct RenameSheet: View {
    @Bindable var model: ReportViewModel
    let pending: ReportViewModel.PendingRename

    @State private var name = ""
    @FocusState private var imFeld: Bool

    /// **⚠️ Der eigene Name zählt nicht als Kollision.** Sonst ließe sich ein
    /// Name nicht in seine eigene Schreibweise ändern — und genau das ist der
    /// Fall, den `FolderNaming.isCaseOnlyChange` behandelt.
    private var belegt: Set<String> {
        pending.existing.subtracting([pending.url.lastPathComponent])
    }

    private var ablehnung: FolderNaming.Rejection? {
        FolderNaming.rejection(for: name, existing: belegt)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(pending.isFolder ? "Ordner umbenennen" : "Datei umbenennen")
                .font(.headline)

            TextField("Name", text: $name)
                .textFieldStyle(.roundedBorder)
                .focused($imFeld)
                .onSubmit { if ablehnung == nil { model.confirmRename(to: name) } }

            if let ablehnung {
                Label(ablehnung.reason, systemImage: "exclamationmark.triangle")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else if let hinweis = pending.repoWarning {
                // ⚠️ Umbenennen ist fuer die Versionsverwaltung derselbe
                // Eingriff wie Verschieben – derselbe Satz, derselbe fehlende
                // Befehl.
                Label(hinweis, systemImage: "arrow.triangle.branch")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                Spacer()
                Button("Abbrechen", role: .cancel) { model.cancelRename() }
                    .keyboardShortcut(.cancelAction)
                Button("Umbenennen") { model.confirmRename(to: name) }
                    .keyboardShortcut(.defaultAction)
                    .disabled(ablehnung != nil)
            }
        }
        .padding(20)
        .frame(width: 420)
        .onAppear {
            name = pending.url.lastPathComponent
            imFeld = true
        }
    }
}
