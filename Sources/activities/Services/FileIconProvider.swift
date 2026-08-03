import AppKit
import UniformTypeIdentifiers

/// Liefert das systemseitige Datei-Icon (z. B. Word, Excel, XMind) und cached es
/// pro Dateiendung, damit die Liste fluessig bleibt.
enum FileIconProvider {
    private static var cache: [String: NSImage] = [:]

    static func icon(for url: URL) -> NSImage {
        icon(forExtension: url.pathExtension)
    }

    static func icon(forExtension ext: String) -> NSImage {
        let key = ext.lowercased()
        if let cached = cache[key] {
            return cached
        }
        let image: NSImage
        if !key.isEmpty, let type = UTType(filenameExtension: key) {
            image = NSWorkspace.shared.icon(for: type)
        } else {
            image = NSWorkspace.shared.icon(for: .data)
        }
        cache[key] = image
        return image
    }
}
