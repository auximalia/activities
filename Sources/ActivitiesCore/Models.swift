import Foundation

/// Vollstaendig aufgeloeste Einstellungen fuer einen Suchlauf.
///
/// Zeitfenster als halboffenes Intervall ``[start, end)`` (``end`` exklusiv).
/// Fuer den rollierenden Modus ist ``end`` = ``Date.distantFuture`` (keine obere
/// Grenze); fuer eine feste Zeitspanne ist ``end`` = Tagesbeginn(bis) + 1 Tag.
public struct ScanSettings: Equatable, Sendable {
    public var rootURL: URL
    public var start: Date
    public var end: Date
    public var namePattern: String

    public init(rootURL: URL, start: Date, end: Date, namePattern: String) {
        self.rootURL = rootURL
        self.start = start
        self.end = end
        self.namePattern = namePattern
    }
}

/// Eine im Zeitraum liegende Datei samt ihrem beinhaltenden Ordner.
public struct RelevantFile: Identifiable, Sendable, Hashable {
    public var id: URL { url }
    public let url: URL
    public let folder: URL
    public let timestamp: Date
    /// Groesse in Bytes; `nil`, wenn sie nicht gelesen werden konnte.
    ///
    /// **⚠️ Optional und nicht `0`.** Eine nicht lesbare Groesse als Null zu
    /// fuehren hiesse, eine Datei ohne Inhalt zu behaupten – und die
    /// Sortierung nach Groesse stellte sie mit echten leeren Dateien in eine
    /// Reihe. „Weiss ich nicht" ist ein eigener Zustand.
    public let size: Int?

    public init(url: URL, folder: URL, timestamp: Date, size: Int? = nil) {
        self.url = url
        self.folder = folder
        self.timestamp = timestamp
        self.size = size
    }
}

/// Ein Ordner mit neuestem Datum und Anzahl relevanter Dateien.
///
/// **⚠️ Hier stand einmal `files: [RelevantFile]`, „lazy Detailliste".** Es
/// wurde in der gesamten Geschichte des Programms **nie befuellt und nie
/// gelesen** – alle Aufrufstellen liessen den Vorgabewert `[]` stehen, und die
/// Detaildateien laufen ueber den getrennten Weg
/// `filesByFolder: [URL: [RelevantFile]]`. Ein Feld, das nichts traegt, ist
/// keine Vorbereitung, sondern eine Zusage, die niemand einloest: Wer es sieht,
/// haelt es fuer die Detailliste und liest die leere Menge als „keine Dateien".
public struct FolderEntry: Identifiable, Sendable, Hashable {
    public var id: URL { folder }
    public let folder: URL
    public let newestDate: Date
    public let fileCount: Int

    public init(folder: URL, newestDate: Date, fileCount: Int) {
        self.folder = folder
        self.newestDate = newestDate
        self.fileCount = fileCount
    }
}
