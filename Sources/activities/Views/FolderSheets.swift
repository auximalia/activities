import SwiftUI
import AppKit
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
                .onSubmit { if ablehnung == nil { model.confirmNewFolder(named: name) } }
                .background(SheetFieldFocus(selectStemOnly: false))

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
            } else if let reason = model.emptyFolderHiddenReason {
                // **⚠️ VOR dem Anlegen, nicht danach.** Ein leerer Ordner kann
                // keinen Filter erfuellen – er hat nichts, was durchkaeme. Ihn
                // trotzdem zu zeigen hiesse, ihn daran vorbeizuschmuggeln; ihn
                // wortlos verschwinden zu lassen waere der stille Zustand, den
                // dieses Programm nirgends duldet. Also: anlegen und es sagen.
                Label(reason.text, systemImage: "line.3.horizontal.decrease.circle")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
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
    }
}

/// Blatt: neuer Name für eine Datei oder einen Ordner.
struct RenameSheet: View {
    @Bindable var model: ReportViewModel
    let pending: ReportViewModel.PendingRename

    @State private var name = ""

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
                .onSubmit { if ablehnung == nil { model.confirmRename(to: name) } }
                // ⚠️ Bei einer DATEI wird nur der Stamm markiert, nicht die
                // Endung – wie im Finder. Wer `.docx` mitmarkiert, tippt es
                // versehentlich weg, und aus der Datei wird eine ohne Typ.
                .background(SheetFieldFocus(selectStemOnly: !pending.isFolder))

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
        .onAppear { name = pending.url.lastPathComponent }
    }
}

/// Setzt den Eingabefokus im Blatt und markiert den Text.
///
/// **⚠️ SwiftUIs `@FocusState` in `onAppear` reicht hier nicht** – aus der
/// Praxis gemeldet: *„Nach dem Aufruf zum Anlegen eines neuen Ordners kommt ein
/// Fenster – es hat aber keinen Fokus. Man muss es erst anklicken."* Ein Blatt
/// hat ein **eigenes** `NSWindow`, und zum Zeitpunkt von `onAppear` ist es noch
/// nicht Schlüsselfenster; der gesetzte Fokus läuft dann ins Leere.
///
/// Der Umweg über AppKit ist im Haus etabliert: ``SearchFieldFocus`` macht
/// dasselbe für das Suchfeld der Werkzeugleiste, weil `searchFocused` erst ab
/// macOS 15 gibt. **Hier wird nicht im ganzen Programm gesucht**, sondern nur im
/// eigenen Fenster — diese Ansicht liegt im Blatt, also *ist* `self.window` das
/// Blatt.
///
/// **⚠️ Und der Text wird MARKIERT, nicht nur der Cursor gesetzt.** Sonst stünde
/// „Neuer Ordner" da und das Getippte hinge hinten dran — `Neuer OrdnerArchiv`.
/// Der Finder markiert an dieser Stelle ebenfalls.
private struct SheetFieldFocus: NSViewRepresentable {
    /// Bei Dateien nur den Namensstamm markieren, nicht die Endung.
    let selectStemOnly: Bool

    func makeNSView(context: Context) -> NSView { Fokus(selectStemOnly: selectStemOnly) }
    func updateNSView(_ nsView: NSView, context: Context) {}

    final class Fokus: NSView {
        private let selectStemOnly: Bool
        private var done = false

        init(selectStemOnly: Bool) {
            self.selectStemOnly = selectStemOnly
            super.init(frame: .zero)
        }
        @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard window != nil, !done else { return }
            done = true
            // ⚠️ Eine Runde spaeter: Beim Einhaengen ist das Blatt noch nicht
            // Schluesselfenster, und `makeFirstResponder` auf ein Fenster, das
            // keinen Fokus hat, bleibt wirkungslos.
            //
            // *Diese Begruendung ist NICHT am laufenden Programm geprueft — sie
            // waere widerlegt, wenn der Fokus auch ohne die Verzoegerung sitzt.
            // Die Abnahme entscheidet es.*
            DispatchQueue.main.async { [weak self] in self?.focusField() }
        }

        private func focusField() {
            guard let window, let contents = window.contentView,
                  let field = Self.firstTextField(in: contents) else { return }
            window.makeFirstResponder(field)
            field.selectText(nil)
            guard selectStemOnly, let editor = field.currentEditor() else { return }
            let name = field.stringValue as NSString
            let punkt = name.range(of: ".", options: .backwards)
            // Ein fuehrender Punkt ist ein verstecktes Objekt, keine Endung.
            guard punkt.location != NSNotFound, punkt.location > 0 else { return }
            editor.selectedRange = NSRange(location: 0, length: punkt.location)
        }

        private static func firstTextField(in view: NSView) -> NSTextField? {
            if let field = view as? NSTextField, field.isEditable { return field }
            for unter in view.subviews {
                if let gefunden = firstTextField(in: unter) { return gefunden }
            }
            return nil
        }
    }
}
