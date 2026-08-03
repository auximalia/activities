import SwiftUI
import Quartz

/// Steuert die QuickLook-Vorschau fuer die sichtbaren Dateien.
@MainActor
final class QuickLookController: ObservableObject {
    fileprivate weak var host: QuickLookHostView?

    /// Zeigt die Vorschau mit der gesamten Dateiliste und startet bei ``current``.
    /// ``onChange`` meldet den Wechsel (fuer die Markierung in der Liste).
    func present(files: [URL], current: URL, onChange: @escaping (URL) -> Void) {
        host?.present(files: files, current: current, onChange: onChange)
    }
}

/// Bindet eine unsichtbare AppKit-View ein, die das QuickLook-Panel steuert.
struct QuickLookHost: NSViewRepresentable {
    let controller: QuickLookController

    func makeNSView(context: Context) -> QuickLookHostView {
        let view = QuickLookHostView()
        controller.host = view
        return view
    }

    func updateNSView(_ nsView: QuickLookHostView, context: Context) {}
}

/// AppKit-View, die das QuickLook-Panel mit Daten versorgt und ↑/↓/←/→ behandelt.
final class QuickLookHostView: NSView, QLPreviewPanelDataSource, QLPreviewPanelDelegate {
    private var urls: [URL] = []
    private var currentIndex = 0
    private var onChange: ((URL) -> Void)?

    override var acceptsFirstResponder: Bool { true }

    func present(files: [URL], current: URL, onChange: @escaping (URL) -> Void) {
        self.urls = files.isEmpty ? [current] : files
        self.currentIndex = self.urls.firstIndex(of: current) ?? 0
        self.onChange = onChange

        window?.makeFirstResponder(self)
        guard let panel = QLPreviewPanel.shared() else { return }
        if QLPreviewPanel.sharedPreviewPanelExists(), panel.isVisible {
            panel.reloadData()
            panel.currentPreviewItemIndex = currentIndex
        } else {
            panel.makeKeyAndOrderFront(nil)
            panel.currentPreviewItemIndex = currentIndex
        }
    }

    // MARK: - Panel-Steuerung

    override func acceptsPreviewPanelControl(_ panel: QLPreviewPanel!) -> Bool { true }

    override func beginPreviewPanelControl(_ panel: QLPreviewPanel!) {
        panel.dataSource = self
        panel.delegate = self
        panel.currentPreviewItemIndex = currentIndex
    }

    override func endPreviewPanelControl(_ panel: QLPreviewPanel!) {}

    // MARK: - QLPreviewPanelDataSource

    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int { urls.count }

    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem! {
        guard urls.indices.contains(index) else { return nil }
        return urls[index] as NSURL
    }

    // MARK: - QLPreviewPanelDelegate (Tastensteuerung)

    func previewPanel(_ panel: QLPreviewPanel!, handle event: NSEvent!) -> Bool {
        guard event.type == .keyDown else { return false }

        let delta: Int
        switch event.keyCode {
        case 125, 124: delta = 1   // Pfeil runter / rechts -> naechste Datei
        case 126, 123: delta = -1  // Pfeil hoch / links   -> vorherige Datei
        default: return false
        }

        let next = min(max(currentIndex + delta, 0), urls.count - 1)
        guard next != currentIndex else { return true }
        currentIndex = next
        panel.currentPreviewItemIndex = currentIndex
        onChange?(urls[currentIndex])
        return true
    }
}
