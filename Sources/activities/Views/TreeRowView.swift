import SwiftUI
import AppKit
import ActivitiesCore

/// Die Verzweigungslinien einer Baumzeile.
///
/// Wird als **Hintergrund der ganzen Zeile** gezeichnet, nicht als eigene Spalte
/// davor. Nur so kann die Senkrechte dort liegen, wo sie hingehoert: auf der
/// **Mitte des Ordnersymbols** des Elternteils – genau wie in der Listenansicht.
/// Eine vorangestellte Rinne haette sie an den linken Zeilenrand gedraengt, weit
/// weg von dem Symbol, aus dem sie zu entspringen scheint.
///
/// **⚠️ Die Indizes sind um eins versetzt.** ``TreeRow/ancestorsContinue`` zaehlt
/// nach *Ebenen*: Eintrag `j` sagt „der Vorfahre auf Ebene `j` hat noch
/// Geschwister". Die *Linie* auf Ebene `j` traegt aber die Geschwisterlinie der
/// Knoten auf Ebene `j+1`. Deshalb fragt Ebene `j` den Eintrag `j+1` ab. Eintrag
/// 0 wird nie gezeichnet – links von Ebene 0 gibt es keine Linie.
struct TreeGuides: View {
    let ancestorsContinue: [Bool]
    let isLastSibling: Bool
    /// Waagerechte Position, an der der Zeileninhalt beginnt (dort endet der Bogen).
    let contentStart: CGFloat

    private var level: Int { ancestorsContinue.count }

    /// Mitte des Ordnersymbols auf Ebene ``level``.
    private func lineX(_ level: Int) -> CGFloat {
        CGFloat(level) * RowMetrics.treeIndentStep + RowMetrics.connectorX
    }

    var body: some View {
        Canvas { context, size in
            guard level > 0 else { return }
            let midY = size.height / 2
            let radius = min(RowMetrics.connectorRadius, midY)
            var path = Path()

            // Durchlaufende Senkrechten hoeherer Vorfahren.
            for ebene in 0..<(level - 1) where ancestorsContinue[ebene + 1] {
                let x = lineX(ebene)
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
            }

            // Eigene Verzweigung: aus der Symbolmitte des Elternteils herab und
            // im Bogen zur Zeile.
            let x = lineX(level - 1)
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: midY - radius))
            path.addQuadCurve(
                to: CGPoint(x: x + radius, y: midY),
                control: CGPoint(x: x, y: midY)
            )
            path.addLine(to: CGPoint(x: max(contentStart, x + radius), y: midY))

            // Nach unten weiter, solange Geschwister folgen.
            if !isLastSibling {
                path.move(to: CGPoint(x: x, y: midY - radius))
                path.addLine(to: CGPoint(x: x, y: size.height))
            }

            context.stroke(
                path,
                with: .color(RowMetrics.connectorColor),
                style: StrokeStyle(lineWidth: RowMetrics.connectorLineWidth, lineCap: .round)
            )
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Eine Ordnerzeile in der **Baumansicht**.
///
/// **Warum nicht ``FolderRowView`` mit Zusatzschaltern:** Die Zeitansicht ist
/// die gewachsene, tragende Loesung; sie um Sonderfaelle zu erweitern hiesse,
/// sie fuer eine zweite Ansicht zu riskieren. Der Bau ist bewusst getrennt –
/// geteilt wird nur, was sonst auseinanderliefe (``FolderContextMenu``).
///
/// Zwei Dinge unterscheiden sie von der Listenzeile:
/// 1. **Durchgangsknoten** (ohne eigene Treffer) stehen in schwaecherer Schrift
///    und melden ihre Zahlen als Teilbaum – sie behaupten keine eigene Arbeit.
/// 2. Der Name **kuerzt** statt zu draengen. In der flachen Liste durfte er nie
///    gekuerzt werden (`fixedSize`); mit Einrueckung ginge das nicht mehr auf.
struct TreeFolderRowView: View {
    let node: FolderNode
    let guides: TreeRow
    @Bindable var model: ReportViewModel
    var isCompact: Bool = false
    /// Jede zweite Zeile bekommt einen dezenten Hintergrund (Zebra, Lesehilfe).
    var isAlternate: Bool = false

    private var isExpanded: Bool { model.isExpanded(node.folder) }
    private var isSelected: Bool { model.cursor == .folder(node.folder) }

    /// Datum der Zeile.
    ///
    /// Bei eigenen Treffern das **eigene** (live gefiltert, wie in der Liste),
    /// bei Durchgangsknoten das des Teilbaums – sonst haette die Zeile gar keins.
    private var displayDate: Date {
        if node.hasOwnFiles {
            return model.newestVisibleDate(in: node.folder) ?? node.subtreeNewestDate
        }
        return node.subtreeNewestDate
    }

    private var ownCount: Int {
        let live = model.visibleFileCount(in: node.folder)
        return live > 0 ? live : node.ownFileCount
    }

    var body: some View {
        content
            .padding(.leading, CGFloat(guides.level) * RowMetrics.treeIndentStep)
            // Linien ueber der Auswahlflaeche, aber unter dem Inhalt.
            .background(
                TreeGuides(
                    ancestorsContinue: guides.ancestorsContinue,
                    isLastSibling: guides.isLastSibling,
                    contentStart: CGFloat(guides.level) * RowMetrics.treeIndentStep
                        + RowMetrics.treeDisclosureLeading
                )
            )
            // Hervorhebung ueber die **ganze** Zeile, Einrueckung eingeschlossen –
            // wie im Finder. Nur den Inhalt zu hinterlegen liesse die Markierung
            // bei tiefen Zweigen als schmalen Streifen rechts erscheinen.
            .background(SelectionBackground(isActive: isSelected))
            // Zebra ganz hinten: Es beantwortet die **waagerechte** Frage
            // („welches Datum gehoert zu dieser Zeile?"), die Baumlinien die
            // senkrechte. Zwei verschiedene Aufgaben – kein doppeltes
            // Trennsystem.
            .background(RowMetrics.rowBackground(alternate: isAlternate))
            // Dateien aus der Liste hierher ziehen (v1.19.77).
            .folderDropTarget(model: model, folder: node.folder)
            .contentShape(Rectangle())
            .help(node.folder.path)
            .onTapGesture {
                model.select(.folder(node.folder))
                ClipboardService.copy(node.folder.path)
                withAnimation(.easeInOut(duration: 0.2)) { model.toggleExpand(node.folder) }
            }
            .contextMenu { FolderContextMenu(folder: node.folder, model: model) }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(node.isPassThrough ? "Durchgangsordner" : "Ordner") \(node.label)")
            // Ebene und Art gehoeren **gesprochen** dazu: Ohne sie ist ein Baum
            // fuer VoiceOver eine flache Liste, und der Unterschied zwischen
            // echtem Treffer und Wegfuehrung waere allein an der Schriftstaerke
            // haengen geblieben – also unsichtbar.
            .accessibilityValue(accessibilityValue)
            .accessibilityHint("Zum Auf- und Zuklappen aktivieren")
            .accessibilityAddTraits(.isButton)
            .accessibilityAddTraits(isSelected ? [.isSelected] : [])
            .accessibilityAction {
                model.select(.folder(node.folder))
                model.toggleExpand(node.folder)
            }
    }

    /// ⚠️ Anheftung und Aufklappzustand stehen im **Wert**, nicht am Symbol.
    /// Das Anheft-Symbol trug nur ein `.help`, und die Zeile fasst ihre Kinder
    /// mit `children: .combine` zusammen – das ausdrueckliche Label verdraengt
    /// deren Beschriftungen. Sichtbar war der Zustand, hoerbar nicht (UX-37).
    private var accessibilityValue: String {
        let ebene = "Ebene \(guides.level + 1)"
        let datum = "zuletzt \(DateFormatting.dateTime(displayDate))"
        let zusatz = (model.isPinned(node.folder) ? ", angeheftet" : "")
            + (node.children.isEmpty ? "" : (isExpanded ? ", aufgeklappt" : ", zugeklappt"))
        if node.isPassThrough {
            return "\(ebene), keine eigenen Dateien, \(node.subtreeFileCount) im Unterbaum, \(datum)\(zusatz)"
        }
        return "\(ebene), \(ownCount) Dateien, \(datum)\(zusatz)"
    }

    private var content: some View {
        HStack(spacing: 0) {
            // Der Aufklapppfeil sitzt mittig zwischen Verzweigungslinie und
            // Ordnersymbol – die Masse dafuer stehen in ``RowMetrics``.
            Color.clear.frame(width: RowMetrics.treeDisclosureLeading)

            Image(systemName: isExpanded ? "minus.circle" : "plus.circle")
                // ⚠️ Das Plus traegt mehr Gewicht als das Minus – siehe
                // ``RowMetrics/disclosureWidth``. Zugeklappt verbirgt etwas,
                // aufgeklappt verbirgt nichts.
                .font(.caption.weight(isExpanded ? .regular : .bold))
                .foregroundStyle(.secondary)
                .frame(width: RowMetrics.disclosureWidth)
                .opacity(node.children.isEmpty && model.visibleFileCount(in: node.folder) == 0 ? 0.25 : 1)

            Color.clear.frame(width: RowMetrics.treeDisclosureToIcon)

            Button {
                model.select(.folder(node.folder))
                FinderService.open(node.folder)
                ClipboardService.copy(node.folder.path)
            } label: {
                Image(systemName: node.isPassThrough ? "folder" : "folder.fill")
                    .foregroundStyle(node.isPassThrough ? AnyShapeStyle(.secondary) : AnyShapeStyle(.tint))
                    .frame(width: RowMetrics.folderIconSize, height: RowMetrics.folderIconSize)
                    // ⚠️ NACH `foregroundStyle` und `frame`: davor faerbte die
                    // Ordnerfarbe den Anhaenger mit ein, und die Ueberlagerung
                    // richtete sich an der natuerlichen statt an der gesetzten
                    // Symbolgroesse aus.
                    .repoBadge(model.repos.mark(forFolder: node.folder),
                               isRoot: model.repos.mark(forFolder: node.folder)?.root == node.folder)
                    .padding(RowMetrics.folderIconPadding)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Im Finder öffnen · Pfad kopieren")
            .accessibilityLabel("Ordner im Finder öffnen")

            HStack(spacing: RowMetrics.itemSpacing) {
                if model.isPinned(node.folder) {
                    Image(systemName: "pin.fill")
                        .font(.caption2)
                        .foregroundStyle(.tint)
                        .help("Angeheftet")
                }

                Text(node.label)
                    .font(.system(size: model.rowSize.nameFontSize))
                    // Durchgangsknoten: schwaecher, damit sie nicht behaupten,
                    // hier sei gearbeitet worden. Sie tragen nur den Weg.
                    .fontWeight(node.isPassThrough ? .regular : .semibold)
                    .foregroundStyle(node.isPassThrough ? AnyShapeStyle(.secondary) : AnyShapeStyle(.primary))
                    .lineLimit(1)
                    .truncationMode(.middle)

                // **⚠️ Auch im Baum, obwohl die Einrueckung den Ort schon
                // zeigt.** Ausdruecklich so gewuenscht. Das Argument dagegen
                // ist real – der Pfad wiederholt, was die Verschachtelung
                // sagt – aber es traegt nur, solange die Elternzeilen sichtbar
                // sind. Beim Blaettern in einem tiefen Baum sind sie es nicht,
                // und Durchgangsknoten fassen ohnehin mehrere Stufen zu einer
                // Zeile zusammen. Gleiche Form wie in der Zeitansicht: Name,
                // dahinter der Pfad in Grau, bei schmalem Fenster entfaellt er.
                if !isCompact {
                    Text(model.displayPath(of: node.folder))
                        .font(.system(size: model.rowSize.metaFontSize))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .layoutPriority(-1)
                }

                Text(countLabel)
                    // Nebenangabe wie Datum und Groesse (PR-38): 11 pt.
                    .font(.system(size: model.rowSize.metaFontSize))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .layoutPriority(-1)

                Spacer(minLength: RowMetrics.itemSpacing)

                DateStampView(date: displayDate, isCompact: isCompact, size: model.rowSize)
                if !isCompact { SizeStampPlaceholder(size: model.rowSize) }
            }
            .padding(.leading, RowMetrics.itemSpacing)
        }
        .frame(height: RowMetrics.rowHeight)
        .padding(.trailing, RowMetrics.horizontalPadding)
        .columnRule(isVisible: !isCompact, size: model.rowSize)
    }

    /// Zahlenangabe der Zeile – bei Durchgangsknoten ausdruecklich als Teilbaum.
    private var countLabel: String {
        if node.isPassThrough { return "· \(node.subtreeFileCount) im Unterbaum" }
        if node.subtreeFileCount > ownCount { return "· \(ownCount) · \(node.subtreeFileCount) gesamt" }
        return "· \(ownCount)"
    }
}
