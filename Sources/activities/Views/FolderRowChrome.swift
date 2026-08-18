import SwiftUI
import ActivitiesCore

/// Alles, was eine Ordnerzeile trägt und **nicht** von der Ansicht abhängt.
///
/// **⚠️ Er entstand, weil Sprint 19 jedes einzelne Merkmal zweimal einbauen
/// musste** — Ziehquelle, Ablegeziel, Repo-Anhänger, Kontextmenü —, einmal in
/// ``FolderRowView`` (Zeitansicht) und einmal in ``TreeFolderRowView`` (Baum).
/// Vier Gelegenheiten, eine zu vergessen; bei der Reihenfolge der Modifikatoren
/// am Anhänger ist mir das in einer der beiden zunächst danebengegangen.
///
/// **⚠️ Was hier NICHT hineingehört, ist der eigentliche Inhalt der Trennung.**
/// Einrückung, Baumlinien und der Bezug des Zebrastreifens bleiben getrennt —
/// *sie sind der Grund, warum es zwei Ansichten gibt.* Der Zebrastreifen etwa
/// wechselt im Baum je Zeile und ist in der Zeitansicht fest, weil er dort nur
/// den Dateiblock unter einem Ordner gliedert.
///
/// **⚠️ Der Kurzhinweis gehört ebenfalls nicht hierher**, obwohl beide Ansichten
/// einen haben: Im Baum steht der **Pfad**, in der Zeitansicht steht, was ein
/// Klick tut. Beim Zusammenlegen fiel das zunächst zusammen — *zwei Dinge, die
/// gleich aussehen, sind nicht dasselbe, und die Zusammenlegung ist genau der
/// Moment, in dem man das verwechselt.*
struct FolderRowChrome: ViewModifier {
    @Bindable var model: ReportViewModel
    let folder: URL
    /// Ob diese Zeile markiert ist — die beiden Ansichten leiten das
    /// verschieden ab und reichen es deshalb herein.
    let isSelected: Bool
    /// Zebra: im Baum wechselnd, in der Zeitansicht fest.
    let isAlternate: Bool

    func body(content: Content) -> some View {
        content
            .background(SelectionBackground(isActive: isSelected))
            .background(RowMetrics.rowBackground(alternate: isAlternate))
            // Den Ordner selbst herausziehen — dieselbe Ziehquelle wie bei
            // Dateien: ein Weg, ein Verhalten.
            .background(
                MultiFileDragSource(
                    targets: { [folder] },
                    prepare: { model.noteDragOrigin(folder) }
                )
            )
            // Dateien und Ordner hierher ziehen.
            .folderDropTarget(model: model, folder: folder)
            .contentShape(Rectangle())
            .contextMenu { FolderContextMenu(folder: folder, model: model) }
    }
}

extension View {
    /// Siehe ``FolderRowChrome``.
    func folderRowChrome(model: ReportViewModel, folder: URL,
                         isSelected: Bool, isAlternate: Bool) -> some View {
        modifier(FolderRowChrome(model: model, folder: folder,
                                 isSelected: isSelected, isAlternate: isAlternate))
    }
}
