import SwiftUI

/// Fensteraufbau: Steuerleiste oben, darunter Diagramm + Ordnerliste bzw. Leerzustand.
struct RootView: View {
    @State private var model = ReportViewModel()

    var body: some View {
        VStack(spacing: 0) {
            ControlsView(model: model)
            Divider()
            content
        }
        .task { model.startInitialScanIfNeeded() }
    }

    @ViewBuilder
    private var content: some View {
        if let message = model.errorMessage {
            EmptyStateView(systemImage: "exclamationmark.triangle", title: "Es ist ein Problem aufgetreten", message: message)
        } else if model.isScanning && model.buckets.isEmpty {
            VStack(spacing: 12) {
                ProgressView()
                Text("Durchsuche \(model.rootURL.lastPathComponent) …")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if model.buckets.isEmpty {
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
