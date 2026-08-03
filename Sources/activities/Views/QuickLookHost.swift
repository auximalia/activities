import SwiftUI
import Quartz

/// Steuert die QuickLook-Vorschau fuer die aktuell markierte Datei.
@MainActor
final class QuickLookController: ObservableObject {
    fileprivate weak var host: QuickLookHostView?

    func preview(_ url: URL) {
        host?.preview(url: url)
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

/// AppKit-View, die als Responder das QuickLook-Panel mit Daten versorgt.
final class QuickLookHostView: NSView, QLPreviewPanelDataSource, QLPreviewPanelDelegate {
    private var url: URL?

    override var acceptsFirstResponder: Bool { true }

    func preview(url: URL) {
        self.url = url
        window?.makeFirstResponder(self)
        guard let panel = QLPreviewPanel.shared() else { return }
        if QLPreviewPanel.sharedPreviewPanelExists(), panel.isVisible {
            panel.reloadData()
        } else {
            panel.makeKeyAndOrderFront(nil)
        }
    }

    // MARK: - Panel-Steuerung

    override func acceptsPreviewPanelControl(_ panel: QLPreviewPanel!) -> Bool { true }

    override func beginPreviewPanelControl(_ panel: QLPreviewPanel!) {
        panel.dataSource = self
        panel.delegate = self
    }

    override func endPreviewPanelControl(_ panel: QLPreviewPanel!) {}

    // MARK: - QLPreviewPanelDataSource

    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        url == nil ? 0 : 1
    }

    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem! {
        url as NSURL?
    }
}
