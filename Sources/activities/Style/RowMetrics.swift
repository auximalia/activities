import SwiftUI

/// Zentrale Masse fuer die Zeilendarstellung (Ordner-/Dateizeilen und Baumlinien).
///
/// Die Werte sind bewusst an einer Stelle gebuendelt, damit Einrueckung,
/// Konnektor-Rinne und Datumsspalte zueinander passen.
enum RowMetrics {
    /// Waagerechter Innenabstand einer Zeile (links wie rechts).
    static let horizontalPadding: CGFloat = 8
    /// Breite des Aufklapp-Pfeils in der Ordnerzeile.
    static let disclosureWidth: CGFloat = 12
    /// Abstand zwischen den Elementen einer Zeile.
    static let itemSpacing: CGFloat = 8
    /// Feste Kantenlaenge des Ordnersymbols (macht seine Mitte berechenbar).
    ///
    /// **⚠️ Das Symbol bestimmt die Zeilenhoehe, nicht der Text.** Die
    /// Schriftzeile misst rund 16 pt; ein 18-pt-Symbol mit 2 pt Innenabstand
    /// machte daraus 22 pt und mit dem Zeilenabstand 32 pt je Zeile – gemessen.
    /// Finder kommt mit ~24 pt aus. 16 pt Symbol und 1 pt Abstand ergeben 18 pt
    /// Inhalt: gerade so viel, wie die Schrift ohnehin braucht.
    static let folderIconSize: CGFloat = 16
    /// Innenabstand um das Ordnersymbol herum (Klickflaeche).
    static let folderIconPadding: CGFloat = 1
    /// Kantenlaenge der Dateisymbole – dieselbe Hoehe wie die Ordnersymbole,
    /// damit Ordner- und Dateizeilen gleich hoch werden.
    static let fileIconSize: CGFloat = 16
    /// Senkrechter Innenabstand einer Ordnerzeile.
    static let folderRowPadding: CGFloat = 3
    /// Senkrechter Innenabstand einer Dateizeile.
    static let fileRowPadding: CGFloat = 2
    /// Abstand zwischen zwei Zeilen in der Liste.
    ///
    /// 1 pt statt 2: Bei 0 stossen die Zebra-Streifen aneinander und die Liste
    /// wirkt wie ein Block; 1 pt genuegt als Fuge.
    static let rowSpacing: CGFloat = 1

    /// Breite der Rinne, in der die Baumlinien gezeichnet werden.
    static let connectorWidth: CGFloat = 22
    /// Einrueckung je Ebene in der **Baumansicht**.
    ///
    /// **⚠️ Nicht frei waehlbar – es gibt eine Untergrenze.** Die senkrechte
    /// Verzweigungslinie soll wie in der Listenansicht aus der **Mitte des
    /// Ordnersymbols** des Elternteils nach unten laufen, also bei
    /// ``connectorX``. Damit sie links vom Aufklapppfeil des Kindes bleibt und
    /// nicht mitten durch dessen Zeile schneidet, muss gelten:
    ///
    ///     Schrittweite + treeDisclosureLeading > connectorX
    ///     28 + 12 = 40 > 37  ✓
    ///
    /// Mit dem kleineren Ordnersymbol (16 statt 18 pt) ist ``connectorX`` von 39
    /// auf 37 gesunken – die Untergrenze fiel damit von 31 auf 25 pt. Deshalb
    /// reichen jetzt 28 statt 34 pt: bei fuenf Ebenen 30 pt weniger Einrueckung,
    /// ohne dass die Linie ihren Platz verliert.
    static let treeIndentStep: CGFloat = 28

    /// Zusatz-Einrueckung von **Dateizeilen** im Baum.
    ///
    /// Dateien haben keinen Aufklapppfeil. Ohne Ausgleich staende ihr Symbol
    /// 20 pt links von dem gleichrangiger Unterordner – Geschwister saehen aus
    /// wie verschiedene Ebenen.
    static var treeFileExtraIndent: CGFloat { disclosureWidth + itemSpacing }

    /// Abstand vom Zeilenanfang bis zum Aufklapppfeil (nur Baumansicht).
    ///
    /// **⚠️ Gemeinsam mit ``treeDisclosureToIcon`` festgelegt.** Der Pfeil soll
    /// mittig zwischen der Verzweigungslinie und dem Ordnersymbol sitzen, und
    /// die Symbolmitte muss weiterhin auf ``connectorX`` liegen – sonst waendert
    /// die Linie der naechsten Ebene aus. Daraus folgt zwingend:
    ///
    ///     treeDisclosureLeading + disclosureWidth + treeDisclosureToIcon
    ///         + folderIconPadding + folderIconSize/2  ==  connectorX
    ///     12 + 12 + 4 + 1 + 8 == 37  ✓
    static let treeDisclosureLeading: CGFloat = 12
    /// Abstand zwischen Aufklapppfeil und Ordnersymbol (nur Baumansicht).
    static let treeDisclosureToIcon: CGFloat = 4
    /// Eckenradius der abgerundeten Baumlinien ("Mind-Map"-Anmutung).
    static let connectorRadius: CGFloat = 6
    /// Linienstaerke der Baumlinien.
    static let connectorLineWidth: CGFloat = 1.2
    /// Luft zwischen Ordnersymbol-Unterkante und dem Beginn des Baum-Stubs,
    /// damit die Linie das Symbol nicht uebermalt.
    static let stubGap: CGFloat = 3

    /// Waagerechte Position der senkrechten Baumlinie = **Mitte des
    /// Ordnersymbols**, gemessen vom linken Rand eines Ordner-Blocks. Dadurch
    /// haengt der Baum symmetrisch unter dem Ordner.
    static var connectorX: CGFloat {
        horizontalPadding + disclosureWidth + itemSpacing + folderIconPadding + folderIconSize / 2
    }

    /// Einrueckung des Dateiblocks, so gewaehlt, dass die Konnektor-Rinne mittig
    /// unter dem Ordnersymbol sitzt.
    static var fileIndent: CGFloat { max(connectorX - connectorWidth / 2, 0) }

    /// Feste Breite der Datumsspalte. Verhindert, dass der Zeitstempel bei
    /// breitem Fenster weit vom Namen abrueckt (Gesetz der Naehe).
    static let dateColumnWidth: CGFloat = 150
    /// Schmalere Datumsspalte im Kompakt-Layout.
    static let dateColumnWidthCompact: CGFloat = 124

    /// Ab welcher Fensterbreite auf das Kompakt-Layout umgeschaltet wird.
    ///
    /// Darunter kostet die Zeile zu viel an feste Bestandteile (Datumsspalte,
    /// Einrueckung, Pfad) und fuer den Dateinamen bleibt kaum Platz. Statt alles
    /// zu quetschen, entfaellt dann der Pfad (bleibt im Tooltip) und die
    /// Datumsspalte wird kuerzer.
    static let compactThreshold: CGFloat = 940

    /// Datumsspaltenbreite je Layout.
    static func dateColumnWidth(compact: Bool) -> CGFloat {
        compact ? dateColumnWidthCompact : dateColumnWidth
    }

    /// Farbe der Baumlinien.
    static let connectorColor = Color.secondary.opacity(0.45)

    /// Hintergrund einer Zeile – abwechselnd, als Lesehilfe fuer die
    /// waagerechte Zuordnung (welches Datum am rechten Rand gehoert hierher?).
    ///
    /// **Aus den Systemfarben, nicht selbst gemischt.**
    /// ``NSColor.alternatingContentBackgroundColors`` ist genau dafuer gedacht:
    /// Weiss und ein sehr helles Grau im hellen Erscheinungsbild, passend
    /// invertiert im dunklen. Die frueheren Werte (Fensterhintergrund plus
    /// ``Color.secondary.opacity(0.07)``) lagen beide im Grau und wirkten
    /// insgesamt zu dunkel – gemeldet.
    static func rowBackground(alternate: Bool) -> Color {
        let colors = NSColor.alternatingContentBackgroundColors
        let index = alternate && colors.count > 1 ? 1 : 0
        return Color(nsColor: colors[index])
    }

    /// Hintergrund eines Abschnittskopfs in der Zeitansicht.
    ///
    /// Muss sich von **beiden** Zeilenfarben abheben – sonst geht die Zaesur
    /// zwischen „Heute" und „Gestern" im Wechsel der Zeilen unter. Deshalb der
    /// Fensterhintergrund (deutlich grauer als die weissen Zeilen) mit einer
    /// leichten Verstaerkung darauf.
    static let sectionHeaderBackground = Color(nsColor: .windowBackgroundColor)
    /// Verstaerkung ueber ``sectionHeaderBackground``; hebt im hellen Modus ab
    /// und hellt im dunklen auf – in beiden Faellen eine eigene Flaeche.
    static let sectionHeaderOverlay = Color.primary.opacity(0.06)

    /// Saettigung des Datei-Icons bei Dateien **ausserhalb** des Zeitraums.
    /// 0 = Graustufen: farbige Icons markieren so die relevanten Treffer
    /// (Farbe wirkt praeattentiv, faellt also ohne Suchen auf).
    static let outOfWindowIconSaturation: Double = 0
    /// Deckkraft des Icons ausserhalb des Zeitraums (noch klar erkennbar).
    static let outOfWindowIconOpacity: Double = 0.55
    /// Deckkraft des Dateinamens ausserhalb des Zeitraums.
    static let outOfWindowTextOpacity: Double = 0.75
}

/// Abgerundete Baumlinie vor einer Dateizeile ("Mind-Map"-Stil statt ASCII).
///
/// Zeichnet eine senkrechte Linie und einen abgerundeten Bogen zur Zeilenmitte.
/// Bei der letzten Datei eines Ordners endet die Senkrechte am Bogen, sonst
/// laeuft sie bis zum unteren Rand weiter.
struct TreeConnector: View {
    /// Ob dies die letzte Datei des Ordners ist (dann kein Weiterlaufen nach unten).
    let isLast: Bool

    var body: some View {
        Canvas { context, size in
            let x = size.width / 2
            let midY = size.height / 2
            let radius = min(RowMetrics.connectorRadius, midY)

            var path = Path()
            // Senkrechte von oben bis kurz vor die Zeilenmitte.
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: midY - radius))
            // Abgerundeter Bogen nach rechts.
            path.addQuadCurve(
                to: CGPoint(x: x + radius, y: midY),
                control: CGPoint(x: x, y: midY)
            )
            path.addLine(to: CGPoint(x: size.width, y: midY))

            // Zwischenzeilen: Senkrechte laeuft nach unten weiter.
            if !isLast {
                path.move(to: CGPoint(x: x, y: midY - radius))
                path.addLine(to: CGPoint(x: x, y: size.height))
            }

            context.stroke(
                path,
                with: .color(RowMetrics.connectorColor),
                style: StrokeStyle(lineWidth: RowMetrics.connectorLineWidth, lineCap: .round)
            )
        }
        .frame(width: RowMetrics.connectorWidth)
        .accessibilityHidden(true)
    }
}
