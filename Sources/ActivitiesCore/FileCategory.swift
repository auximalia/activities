import Foundation

/// Dateityp-Kategorie fuer Diagramm und Legende.
///
/// Die Reihenfolge der Faelle bestimmt zugleich die Stapel- und Legenden-
/// reihenfolge im Balkendiagramm. Nicht zugeordnete Endungen fallen unter
/// ``other`` ("Sonstige"). Portierung von ``file_types.py``.
public enum FileCategory: String, CaseIterable, Sendable, Hashable {
    case documents = "Dokumente"
    case pdf = "PDF"
    case spreadsheets = "Tabellen"
    case presentations = "Präsentationen"
    case images = "Bilder"
    case media = "Medien"
    case archives = "Archive"
    case code = "Code"
    case other = "Sonstige"

    /// Anzeigename (identisch zum Rohwert, hier fuer klare Semantik).
    public var displayName: String { rawValue }

    /// Ermittelt die Kategorie anhand der Dateiendung (klein, ohne Punkt).
    public static func category(for url: URL) -> FileCategory {
        let ext = url.pathExtension.lowercased()
        return extensionMap[ext] ?? .other
    }

    /// Endung (ohne Punkt, klein) -> Kategorie.
    private static let extensionMap: [String: FileCategory] = [
        // Dokumente
        "doc": .documents, "docx": .documents, "odt": .documents, "rtf": .documents,
        "txt": .documents, "md": .documents, "pages": .documents,
        // Mindmaps und Gliederungen zaehlen als Dokumente.
        //
        // **⚠️ Sie lagen vorher unter ``other`` – und das war nicht nur
        // ungenau, es war gefaehrlich.** „Sonstige" ist der Eimer fuer alles
        // Unbekannte, und darin liegen auch `.app`, `.command`, `.scpt`,
        // `.pkg`, `.dmg`. Wer „Sonstige" pauschal oeffnet, startet oder
        // installiert unter Umstaenden etwas. Damit „Arbeit fortsetzen"
        // Mindmaps anbieten kann, ohne diesen Eimer aufzumachen, muessen sie
        // dort heraus – in die Kategorie, in die sie ohnehin gehoeren.
        "xmind": .documents, "mmap": .documents, "mm": .documents,
        "opml": .documents,
        // PDF
        "pdf": .pdf,
        // Tabellen
        "xls": .spreadsheets, "xlsx": .spreadsheets, "ods": .spreadsheets,
        "csv": .spreadsheets, "numbers": .spreadsheets,
        // Praesentationen
        "ppt": .presentations, "pptx": .presentations, "odp": .presentations,
        "key": .presentations,
        // Bilder
        "jpg": .images, "jpeg": .images, "png": .images, "gif": .images,
        "heic": .images, "tiff": .images, "tif": .images, "bmp": .images,
        "svg": .images, "webp": .images,
        // Medien (Audio/Video)
        "mp3": .media, "wav": .media, "m4a": .media, "aac": .media,
        "flac": .media, "mp4": .media, "mov": .media, "avi": .media,
        "mkv": .media, "m4v": .media,
        // Archive
        "zip": .archives, "rar": .archives, "7z": .archives, "tar": .archives,
        "gz": .archives, "bz2": .archives,
        // Code
        "py": .code, "js": .code, "ts": .code, "java": .code, "c": .code,
        "cpp": .code, "h": .code, "hpp": .code, "cs": .code, "go": .code,
        "rb": .code, "php": .code, "html": .code, "css": .code, "json": .code,
        "xml": .code, "yaml": .code, "yml": .code, "sh": .code, "sql": .code,
    ]
}
