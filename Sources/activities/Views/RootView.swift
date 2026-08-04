import SwiftUI

/// Fensteraufbau: Steuerleiste oben, Inhalt in der Mitte, Statuszeile unten.
struct RootView: View {
    @Bindable var model: ReportViewModel

    var body: some View {
        VStack(spacing: 0) {
            ControlsView(model: model)
            Divider()
            content
            Divider()
            StatusBarView(model: model)
        }
        .task { model.startInitialScanIfNeeded() }
        .alert("Sehr grosser Zeitraum", isPresented: $model.confirmLargeScan) {
            Button("Trotzdem suchen") { model.confirmLargeScanAndProceed() }
            Button("Abbrechen", role: .cancel) { model.dismissLargeScan() }
        } message: {
            Text("Der gewaehlte Zeitraum umfasst mehr als 10 Jahre. Die Suche kann sehr lange dauern und viele Ordner liefern. Trotzdem starten?")
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
            EmptyStateView(
                systemImage: "tray",
                title: "Keine Ordner gefunden",
                message: "Im gewaehlten Zeitraum wurde nichts bearbeitet. Erhoehe die Tage, waehle einen anderen Ordner oder passe den Filter an."
            )
        } else {
            ReportView(model: model)
        }
    }
}

/// Statuszeile: Anzahl Ordner/Dateien, Scandauer, Auto-Refresh-Zustand.
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
            if model.lastScanDuration > 0 {
                Text("· \(String(format: "%.2f s", model.lastScanDuration))")
                    .foregroundStyle(.secondary)
            }
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
