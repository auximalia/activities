import SwiftUI
import ActivitiesCore

extension FileCategory {
    /// Farbe der Kategorie im Diagramm und in der Legende.
    var color: Color {
        switch self {
        case .documents: return .blue
        case .pdf: return .red
        case .spreadsheets: return .green
        case .presentations: return .orange
        case .images: return .purple
        case .media: return .pink
        case .archives: return .brown
        case .code: return .teal
        case .other: return .gray
        }
    }
}

enum ChartStyle {
    /// Reihenfolge und Farben fuer die Foreground-Style-Skala von Swift Charts.
    static let domain: [String] = FileCategory.allCases.map(\.displayName)
    static let range: [Color] = FileCategory.allCases.map(\.color)
}
