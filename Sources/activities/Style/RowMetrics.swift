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
    static let folderIconSize: CGFloat = 18
    /// Innenabstand um das Ordnersymbol herum (Klickflaeche).
    static let folderIconPadding: CGFloat = 2

    /// Breite der Rinne, in der die Baumlinien gezeichnet werden.
    static let connectorWidth: CGFloat = 22
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
    static let dateColumnWidthCompact: CGFloat = 108

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
    /// Hintergrund jeder zweiten Dateizeile (Zebra, als Lesehilfe).
    static let zebraColor = Color.secondary.opacity(0.07)

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
