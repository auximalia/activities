import Foundation

/// Vollstaendig aufgeloeste Einstellungen fuer einen Suchlauf.
public struct ScanSettings: Equatable, Sendable {
    public var rootURL: URL
    public var days: Int
    public var namePattern: String

    public init(rootURL: URL, days: Int, namePattern: String) {
        self.rootURL = rootURL
        self.days = days
        self.namePattern = namePattern
    }
}

/// Eine im Zeitraum liegende Datei samt ihrem beinhaltenden Ordner.
public struct RelevantFile: Identifiable, Sendable, Hashable {
    public var id: URL { url }
    public let url: URL
    public let folder: URL
    public let timestamp: Date

    public init(url: URL, folder: URL, timestamp: Date) {
        self.url = url
        self.folder = folder
        self.timestamp = timestamp
    }
}

/// Ein Ordner mit neuestem Datum, Anzahl relevanter Dateien und (lazy) Detailliste.
public struct FolderEntry: Identifiable, Sendable, Hashable {
    public var id: URL { folder }
    public let folder: URL
    public let newestDate: Date
    public let fileCount: Int
    public var files: [RelevantFile]

    public init(folder: URL, newestDate: Date, fileCount: Int, files: [RelevantFile] = []) {
        self.folder = folder
        self.newestDate = newestDate
        self.fileCount = fileCount
        self.files = files
    }
}

/// Anzahl bearbeiteter Dateien an einem Kalendertag, aufgeschluesselt nach Typ.
public struct DayCount: Identifiable, Sendable {
    public var id: Date { day }
    public let day: Date
    public let countsByCategory: [FileCategory: Int]

    public init(day: Date, countsByCategory: [FileCategory: Int]) {
        self.day = day
        self.countsByCategory = countsByCategory
    }

    /// Gesamtzahl der Dateien des Tages ueber alle Kategorien.
    public var total: Int { countsByCategory.values.reduce(0, +) }
}
