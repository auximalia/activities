import AppKit
import UniformTypeIdentifiers

/// Liefert das systemseitige Datei-Icon (z. B. Word, Excel, XMind) und cached es
/// pro Dateiendung, damit die Liste fluessig bleibt.
enum FileIconProvider {
    private static var cache: [String: NSImage] = [:]

    static func icon(for url: URL) -> NSImage {
        let ext = url.pathExtension.lowercased()
        if let cached = cache[ext] {
            return cached
        }
        let image: NSImage
        if !ext.isEmpty, let type = UTType(filenameExtension: ext) {
            image = NSWorkspace.shared.icon(for: type)
        } else {
            image = NSWorkspace.shared.icon(forFile: url.path)
        }
        cache[ext] = image
        return image
    }
}
