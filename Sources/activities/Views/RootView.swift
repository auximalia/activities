import SwiftUI
import AppKit

/// Fensteraufbau: **feste Kopfzone** (Diagramm + Legende), darunter die
/// scrollende Liste, unten die Statuszeile. Die Bedienelemente liegen seit
/// v1.8.0 in der **Titelleisten-Toolbar** statt in einer eigenen Zeile.
struct RootView: View {
    @Bindable var model: ReportViewModel
    var updates: UpdateChecker

    var body: some View {
        VStack(spacing: 0) {
            if model.hasScanResults && model.errorMessage == nil {
                ChartHeaderView(model: model)
                Divider()
            }
            content
            Divider()
            StatusBarView(model: model)
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

/// Statuszeile: Anzahl Ordner/Dateien, Auto-Refresh-Zustand, Wurzelpfad.
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
                // Scandauer ist eine Diagnosegroesse, kein Nutzerwert –
                // deshalb im Tooltip statt dauerhaft im Blickfeld.
                .help(model.lastScanDuration > 0
                      ? String(format: "Letzte Suche: %.2f s", model.lastScanDuration)
                      : "Noch keine Suche abgeschlossen")
            Spacer()
            if model.autoRefresh {
                Label("Auto", systemImage: "arrow.triangle.2.circlepath")
                    .foregroundStyle(.secondary)
            }
            Text(model.rootURL.path)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .font(.caption)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
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
