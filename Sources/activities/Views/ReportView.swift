import SwiftUI
import ActivitiesCore

/// Bericht: Verlaufsdiagramm oben, darunter die nach Zeit gruppierte Ordnerliste.
struct ReportView: View {
    @Bindable var model: ReportViewModel

    /// Aktuell hervorgehobener Ordner (Ziel eines Klicks im Diagramm).
    @State private var highlightedFolder: URL?

    var body: some View {
        ScrollViewReader { proxy in
            List {
                Section {
                    HistoryChartView(dayCounts: model.dayCounts) { day in
                        selectDay(day, proxy: proxy)
                    }
                    .frame(height: 200)
                    .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                }

                ForEach(model.buckets) { bucket in
                    Section {
                        ForEach(bucket.entries) { entry in
                            FolderRowView(
                                entry: entry,
                                model: model,
                                isHighlighted: entry.id == highlightedFolder
                            )
                            .id(entry.id)
                        }
                    } header: {
                        Text("\(bucket.label) · \(bucket.entries.count)")
                            .font(.headline)
                    }
                }
            }
            .listStyle(.inset)
        }
    }

    /// Springt zum passenden Ordner und hebt ihn deutlich hervor.
    private func selectDay(_ day: Date, proxy: ScrollViewProxy) {
        guard let target = targetID(forDay: day) else { return }
        withAnimation(.easeInOut(duration: 0.35)) {
            highlightedFolder = target
            proxy.scrollTo(target, anchor: .center)
        }
    }

    /// Ermittelt den Ordnereintrag, zu dem beim Klick auf einen Tagesbalken gescrollt wird.
    private func targetID(forDay day: Date) -> URL? {
        let calendar = Calendar.current
        let entries = model.buckets.flatMap(\.entries)
        if let match = entries.first(where: { calendar.isDate($0.newestDate, inSameDayAs: day) }) {
            return match.id
        }
        // Sonst der erste Eintrag am oder vor diesem Tag (Liste ist absteigend sortiert).
        let endOfDay = calendar.startOfDay(for: day).addingTimeInterval(24 * 60 * 60)
        return entries.first(where: { $0.newestDate < endOfDay })?.id
    }
}
