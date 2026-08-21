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

/// Liefert das Symbol eines **Programms** und cached es pro Pfad.
///
/// **⚠️ Eigener Zwischenspeicher, nicht der von ``FileIconProvider``.** Jener
/// hat als Schlüssel die **Dateiendung** — für Programme wäre das immer `app`
/// und damit für alle dasselbe Symbol. Zwei Fragen, zwei Speicher.
///
/// **⚠️ Der Schlüssel ist der Pfad, nicht die Bundle-ID.** Drei Fassungen von
/// IDLE teilen sich eine Bundle-ID und tragen verschiedene Symbole; über die ID
/// zwischengespeichert bekämen alle drei das der erstgefragten. Dieselbe
/// Begründung wie bei ``OpenWithMenu/Candidate/id``.
///
/// **⚠️ Bis v2.1.0 zeigte die App nirgends ein Programmsymbol** — Kontextmenü,
/// Einstellungen und Dateityp-Tabelle nannten nur Namen. Mit „Öffnen mit"
/// (PR-71) kommen sie hinzu, und zwar **in beiden Programmlisten**: hier und im
/// Wähler der Einstellungen. *Eine Liste von Programmen mit Symbolen neben einer
/// ohne wären zwei Antworten auf dieselbe Frage.*
enum AppIconProvider {
    private static var cache: [String: NSImage] = [:]

    static func icon(atPath path: String) -> NSImage {
        if let cached = cache[path] { return cached }
        let image = NSWorkspace.shared.icon(forFile: path)
        cache[path] = image
        return image
    }
}
