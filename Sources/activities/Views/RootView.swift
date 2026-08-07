import SwiftUI
import AppKit

/// Fensteraufbau: **feste Kopfzone** (Diagramm + Legende), darunter die
/// scrollende Liste, unten die Statuszeile. Die Bedienelemente liegen seit
/// v1.8.0 in der **Titelleisten-Toolbar** statt in einer eigenen Zeile.
struct RootView: View {
    @Bindable var model: ReportViewModel
    var updates: UpdateChecker
    /// Ob gerade ein Ordner ueber dem Fenster schwebt (Abwurfziel hervorheben).
    @State private var isDropTargeted = false
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: 0) {
            if model.showsIntro && model.hasScanResults {
                introBanner
                Divider()
            }
            if model.hasScanResults && model.errorMessage == nil {
                ChartHeaderView(model: model)
                Divider()
            }
            content
            Divider()
            StatusBarView(model: model)
        }
        // Ordner aufs Fenster ziehen = neuer Wurzelordner. Ziel ist bewusst das
        // GANZE Fenster, nicht nur die Liste – beim Ziehen zielt man nicht genau.
        .dropDestination(for: URL.self) { urls, _ in
            guard let folder = urls.first(where: \.hasDirectoryPath) else { return false }
            model.setRoot(folder)
            return true
        } isTargeted: { targeted in
            isDropTargeted = targeted
        }
        .overlay {
            if isDropTargeted {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.accentColor, lineWidth: 3)
                    .padding(4)
                    .allowsHitTesting(false)
            }
        }
        .toolbar { MainToolbar(model: model, updates: updates) }
        // ⌘F: `.searchFocused` gibt es erst ab macOS 15 – Ziel ist macOS 14.
        // Deshalb wird das Suchfeld ueber AppKit zum First Responder gemacht.
        .onChange(of: model.filterFocusToken) { _, _ in SearchFieldFocus.focus() }
        // Der Zeitraum steht NICHT mehr hier, sondern als Ueberschrift direkt
        // ueber dem Diagramm (siehe ChartHeaderView): Er beschriftet das
        // Diagramm und gehoert in dessen Naehe, nicht in die Fenster-Metazeile.
        // Der Ordnername steht jetzt sichtbar im Ordner-Menue der Toolbar –
        // im Fenstertitel waere er unmittelbar daneben eine Dopplung.
        .navigationTitle("activities")
        .task { model.startInitialScanIfNeeded() }
        .task { await updates.check() }
        // Ein Programm, das sich nicht starten laesst, muss **dastehen**. Der
        // stille Rueckfall auf den Finder waere schlimmer als gar nichts: Der
        // Anwender haelt den Handgriff fuer erledigt und sucht das Fenster im
        // falschen Programm.
        .alert(
            "Öffnen nicht möglich",
            isPresented: Binding(
                get: { model.actionError != nil },
                set: { if !$0 { model.actionError = nil } }
            )
        ) {
            Button("OK", role: .cancel) { model.actionError = nil }
        } message: {
            Text(model.actionError ?? "")
        }
        .alert(
            updates.manualResult?.title ?? "",
            isPresented: Binding(
                get: { updates.manualResult != nil },
                set: { if !$0 { updates.manualResult = nil } }
            )
        ) {
            if updates.manualResult?.offersInstall == true {
                Button("Jetzt installieren") {
                    updates.manualResult = nil
                    updates.installUpdate()
                }
                Button("Später", role: .cancel) { updates.manualResult = nil }
            } else {
                Button("OK", role: .cancel) { updates.manualResult = nil }
            }
        } message: {
            Text(updates.manualResult?.message ?? "")
        }
    }


    /// Erstkontakt: erklärt in drei Sätzen, was man sieht.
    ///
    /// Bewusst ein **Streifen** und kein Dialog: Er blockiert nicht und lässt die
    /// Auswertung sofort sehen – gerade sie ist die beste Erklärung.
    private var introBanner: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "sparkles")
                .foregroundStyle(.tint)
                .font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text("Willkommen bei activities")
                    .font(.callout).fontWeight(.semibold)
                Text("Hier siehst du, in welchen Ordnern zuletzt gearbeitet wurde. "
                     + "Den Ordner wechselst du links oben, den Zeitraum daneben. "
                     + "Ein Klick ins Diagramm springt zur passenden Datei.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            VStack(spacing: 6) {
                Button("Verstanden") { model.dismissIntro() }
                    .keyboardShortcut(.defaultAction)
                Button("Hilfe öffnen") {
                    model.dismissIntro()
                    openWindow(id: "help")
                }
                .buttonStyle(.link)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.accentColor.opacity(0.08))
    }

    /// Leerzustand, der die **tatsächliche** Ursache nennt.
    ///
    /// Häufigster Fall im Alltag: Nach einem Ordnerwechsel steht noch ein
    /// Suchbegriff im Feld und blendet alles aus – wer das nicht bemerkt, hält
    /// den Ordner für leer oder die App für defekt.
    @ViewBuilder
    private var emptyState: some View {
        switch model.emptyReason {
        case let .nameFilter(pattern, foldersWithout):
            EmptyStateView(
                systemImage: "line.3.horizontal.decrease.circle",
                title: "Keine Treffer für „\(pattern)“",
                message: "Der Namensfilter blendet alles aus. Ohne ihn wären es \(foldersWithout) "
                    + (foldersWithout == 1 ? "Ordner" : "Ordner") + " im gewählten Zeitraum.",
                actionTitle: "Filter löschen",
                action: { model.clearNameFilter() }
            )
        case let .timeWindow(total):
            EmptyStateView(
                systemImage: "calendar.badge.exclamationmark",
                title: "Im Zeitraum wurde nichts bearbeitet",
                message: "Der Ordner enthält \(total) Dateien, aber keine davon wurde im gewählten Zeitraum geändert.",
                actionTitle: "Auf 90 Tage erweitern",
                action: { model.setUseDateRange(false); model.setDays(90) }
            )
        case .emptyFolder:
            EmptyStateView(
                systemImage: "tray",
                title: "Keine Dateien gefunden",
                message: "In diesem Ordner liegen keine auswertbaren Dateien. Wähle über das Ordner-Menü einen anderen Ordner."
            )
        }
    }

    @ViewBuilder
    private var content: some View {
        if let message = model.errorMessage {
            EmptyStateView(systemImage: "exclamationmark.triangle", title: "Es ist ein Problem aufgetreten", message: message)
        } else if model.isScanning && !model.hasScanResults {
            VStack(spacing: 12) {
                ProgressView()
                Text("Durchsuche \(model.rootURL.lastPathComponent) … \(model.scanProgress) Dateien")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                Button("Abbrechen") { model.cancelScan() }
                    .controlSize(.small)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if !model.hasScanResults {
            emptyState
        } else {
            ReportView(model: model)
        }
    }
}

/// Statuszeile: Anzahl Ordner/Dateien, Stand der Daten, Auto-Refresh, Wurzelpfad.
struct StatusBarView: View {
    @Bindable var model: ReportViewModel

    private var folderCount: Int {
        model.displayBuckets.reduce(0) { $0 + $1.entries.count }
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "folder")
                .foregroundStyle(.secondary)
            Text("\(folderCount) Ordner · \(model.scannedFileCount) Dateien")

            Divider().frame(height: 10)
            scanAge

            Spacer()
            if model.autoRefresh {
                Label("Auto", systemImage: "antenna.radiowaves.left.and.right")
                    .foregroundStyle(.secondary)
            }
            Text(model.rootURL.path)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)

            // Versionsnummer gehoert als **Statusinformation** hierher (nicht in
            // die Arbeitsflaeche): Sie wird bei Rueckfragen und Fehlermeldungen
            // gebraucht. Der Credit-Text dagegen steht im „Ueber"-Fenster.
            Divider().frame(height: 10)
            Text("v\(BuildInfo.short)")
                .foregroundStyle(.tertiary)
                .monospacedDigit()
                .textSelection(.enabled)
                .help(BuildInfo.details)
                .layoutPriority(1)
        }
        .font(.caption)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
    }

    /// Wann zuletzt **von der Platte** gelesen wurde.
    ///
    /// **Sichtbar statt im Tooltip.** Hier stand frueher nur die Scan-*Dauer*,
    /// und die auch nur als Kurzhinweis – sie beantwortet die einzige Frage,
    /// auf die es ankommt („darf ich dem Gezeigten glauben?"), gerade nicht.
    /// Zeitraum-Ueberschrift und Abschnittsnamen sagen „heute", der Bestand
    /// kann aber von gestern sein (siehe ``ReportViewModel/lastScanAt``).
    @ViewBuilder
    private var scanAge: some View {
        if let readAt = model.lastScanAt {
            // **Eigener Takt.** Die Warnung wird genau dann gebraucht, wenn
            // niemand etwas tut – ein unberuehrtes Fenster zeichnet sonst nie
            // neu und bliebe ewig unauffaellig gruen.
            TimelineView(.periodic(from: readAt, by: 60)) { context in
                let age = context.date.timeIntervalSince(readAt)
                let isStale = age >= ReportViewModel.stalenessLimit
                HStack(spacing: 4) {
                    Image(systemName: isStale ? "exclamationmark.triangle.fill" : "clock.arrow.circlepath")
                    Text("Stand: \(DateFormatting.dateTime(readAt))")
                }
                .foregroundStyle(isStale ? Color.orange : Color.secondary)
                .help(isStale
                      ? "Zuletzt eingelesen \(DateFormatting.relative(readAt)) – seitdem kann sich einiges geändert haben. ⌘R liest den Ordner neu ein."
                      : String(
                          format: "Zuletzt eingelesen: %@ (Suchlauf %.2f s). ⌘R liest den Ordner neu ein.",
                          DateFormatting.dateTime(readAt),
                          model.lastScanDuration
                      ))
            }
        } else {
            Text("Noch nicht eingelesen")
                .foregroundStyle(.secondary)
        }
    }
}


/// Fokussiert das Suchfeld der Toolbar (Menuebefehl „Filter fokussieren", ⌘F).
///
/// SwiftUIs ``searchFocused`` ist erst ab macOS 15 verfuegbar; das Ziel dieser
/// App ist macOS 14. Der Umweg ueber AppKit sucht das ``NSSearchField`` im
/// Fenster – inklusive der Titelleiste, wo die Toolbar lebt.
enum SearchFieldFocus {
    static func focus() {
        guard let window = NSApp.keyWindow ?? NSApp.windows.first(where: \.isVisible) else { return }
        let roots = [window.contentView, window.contentView?.superview].compactMap { $0 }
        for root in roots {
            if let field = firstSearchField(in: root) {
                window.makeFirstResponder(field)
                return
            }
        }
    }

    private static func firstSearchField(in view: NSView) -> NSSearchField? {
        if let field = view as? NSSearchField { return field }
        for subview in view.subviews {
            if let found = firstSearchField(in: subview) { return found }
        }
        return nil
    }
}
