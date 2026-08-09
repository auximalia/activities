import SwiftUI
import ActivitiesCore

/// Die Datumsspalte einer Zeile – **eine** Darstellung fuer alle Zeilentypen.
///
/// **⚠️ Warum eine eigene View und nicht drei mal derselbe Dreizeiler?**
/// Genau das war der Zustand vorher: ``FolderRowView``, ``TreeRowView`` und
/// ``FileRowView`` bauten den Zeitstempel jeweils selbst zusammen und waren
/// dabei auseinandergelaufen –
///
/// | Zeile | Farbe | Gewicht |
/// |---|---|---|
/// | Ordner (Liste) | `primary` | regular |
/// | Ordner (Baum)  | `primary` **oder** `secondary` | regular |
/// | Datei          | `secondary` | fett bei der datumstiftenden Datei |
///
/// Fuer den Anwender sah dieselbe Angabe je nach Ansicht anders aus. Solche
/// Abweichungen entstehen nicht durch eine Entscheidung, sondern durch drei
/// unabhaengige Aenderungen ueber die Zeit – deshalb liegt die Darstellung
/// jetzt an einer Stelle, an der sie gar nicht mehr driften kann.
///
/// **Farbe: durchgaengig `secondary`.** Das Datum ist die Nebenangabe, der
/// Name ist der Gegenstand. Die Ordnerzeile setzte es in `primary` und liess
/// es damit mit dem Namen konkurrieren.
///
/// **Gewicht: durchgaengig regular.** Die datumstiftende Datei bleibt
/// erkennbar – ihr **Name** steht fett (``FileRowView``). Ein Signal, ein
/// Traeger; zweimal fett in derselben Zeile betont nichts mehr.
///
/// Der frueher im Baum genutzte Farbwechsel fuer Durchgangsknoten entfaellt.
/// Er kodierte „das Datum stammt aus dem Unterbaum" allein ueber Farbe,
/// waehrend die Zeile daneben es bereits ausschreibt („… im Unterbaum").
struct DateStampView: View {
    /// Der anzuzeigende Zeitpunkt.
    let date: Date
    /// Kompakt-Layout (schmales Fenster): kuerzere Form, schmalere Spalte.
    let isCompact: Bool
    /// Gedaempft darstellen – fuer Eintraege **ausserhalb** des Zeitraums.
    ///
    /// Das ist ein Zustand, keine Formatierung: Deshalb bleibt er als
    /// Schalter erhalten, waehrend Farbe und Gewicht fest sind.
    var isDimmed: Bool = false

    var body: some View {
        Text(isCompact
             ? DateFormatting.dateTimeCompact(date)
             : DateFormatting.dateTime(date))
            .font(.system(.callout, design: .monospaced))
            .foregroundStyle(.secondary)
            .opacity(isDimmed ? RowMetrics.outOfWindowTextOpacity : 1)
            .lineLimit(1)
            .frame(width: RowMetrics.dateColumnWidth(compact: isCompact), alignment: .trailing)
    }
}
