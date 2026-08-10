import Foundation
import CoreServices

/// Beobachtet **mehrere** Ordnerbaeume mit FSEvents und meldet Aenderungen.
///
/// ⚠️ Ein Strom fuer alle Pfade, nicht einer je Pfad: FSEvents nimmt die Liste
/// ohnehin entgegen, und mehrere Stroeme haetten mehrere Entprellungen bedeutet
/// – eine Aenderung in zwei beobachteten Quellen loeste dann zwei Suchlaeufe
/// aus.
///
/// Die Callback-Ausfuehrung erfolgt auf einer eigenen Queue; die Weiterleitung
/// an die Oberflaeche (Main-Actor) uebernimmt der Aufrufer im ``onChange``-Block.
final class FolderWatcher {
    private var stream: FSEventStreamRef?
    private let queue = DispatchQueue(label: "com.mtri.activities.folderwatcher")
    private var onChange: (() -> Void)?

    func start(urls: [URL], onChange: @escaping () -> Void) {
        stop()
        guard !urls.isEmpty else { return }
        self.onChange = onChange

        let callback: FSEventStreamCallback = { _, info, _, _, _, _ in
            guard let info else { return }
            let watcher = Unmanaged<FolderWatcher>.fromOpaque(info).takeUnretainedValue()
            watcher.onChange?()
        }

        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        let flags = FSEventStreamCreateFlags(
            kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagNoDefer
        )
        guard let stream = FSEventStreamCreate(
            kCFAllocatorDefault,
            callback,
            &context,
            urls.map(\.path) as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            1.0, // Latenz in Sekunden
            flags
        ) else {
            return
        }

        self.stream = stream
        FSEventStreamSetDispatchQueue(stream, queue)
        FSEventStreamStart(stream)
    }

    func stop() {
        guard let stream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        self.stream = nil
        onChange = nil
    }

    deinit { stop() }
}
