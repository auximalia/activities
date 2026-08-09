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
            .font(.system(size: RowMetrics.metaFontSize, design: .monospaced))
            .foregroundStyle(.secondary)
            .opacity(isDimmed ? RowMetrics.outOfWindowTextOpacity : 1)
            .lineLimit(1)
            .frame(width: RowMetrics.dateColumnWidth(compact: isCompact), alignment: .trailing)
    }
}

/// Die Groessenspalte einer Dateizeile (PR-37).
///
/// Steht **links vom Datum** und rechtsbuendig, damit die Zahlen untereinander
/// stehen und sich senkrecht ueberfliegen lassen.
///
/// **⚠️ Nur Dateien tragen eine Groesse – Ordnerzeilen bleiben leer.** Die
/// naheliegende Summe der sichtbaren Dateien liest jeder als „dieser Ordner ist
/// 1,2 GB gross". Tatsaechlich waere es die Summe **im Zeitfenster und nach
/// Filtern**, bei „Letzte 7 Tage" also ein Bruchteil. Eine Zahl, die etwas
/// anderes verspricht, als sie haelt, verliert beim zweiten Mal ihren Kredit –
/// dieselbe Lehre wie bei der Rueckfrage aus PR-26.
///
/// **⚠️ Im Kompakt-Layout entfaellt die Spalte.** Das ist keine neue Regel,
/// sondern die bestehende: Unterhalb von ``RowMetrics/compactThreshold`` faellt
/// bereits der Pfad weg und die Datumsspalte schrumpft, weil der Name sonst
/// nichts mehr uebrig behaelt. Die Groesse ist von allen drei Angaben die
/// entbehrlichste – sie beantwortet eine Frage der Hauswirtschaft, nicht die
/// des Wiedereinstiegs.
///
/// **Die Einheiten stehen nicht untereinander** („1 MB" gegen „999,9 MB"), und
/// das ist so belassen: Angesehen und fuer richtig befunden – der Finder macht
/// es genauso, und eine Ausrichtung der Einheit haette die Zahl selbst aus der
/// rechten Kante geloest, die man beim Ueberfliegen tatsaechlich benutzt.
struct SizeStampView: View {
    /// Groesse in Bytes; `nil` = nicht lesbar, dann bleibt die Spalte leer.
    let bytes: Int?
    /// Gedaempft darstellen – fuer Eintraege ausserhalb des Zeitraums.
    var isDimmed: Bool = false

    var body: some View {
        Text(SizeFormatting.short(bytes))
            .font(.system(size: RowMetrics.metaFontSize, design: .monospaced))
            .foregroundStyle(.secondary)
            .opacity(isDimmed ? RowMetrics.outOfWindowTextOpacity : 1)
            .lineLimit(1)
            .frame(width: RowMetrics.sizeColumnWidth, alignment: .trailing)
    }
}

/// Platzhalter in der Groessenspalte – fuer Zeilen **ohne** Groesse.
///
/// **⚠️ Ohne ihn verlieren Ordner- und Dateizeilen ihre gemeinsame
/// Datumskante.** Seit die Groesse ganz rechts steht (PR-39), sitzt das Datum
/// nicht mehr am Zeilenende. Eine Ordnerzeile, die die Groessenspalte einfach
/// weglaesst, schoebe ihr Datum um die volle Spaltenbreite nach rechts – und
/// genau die senkrechte Kante, die eine Liste ueberfliegbar macht, waere
/// zerbrochen.
///
/// Der Platzhalter ist deshalb kein Schoenheitsmittel, sondern die Bedingung
/// dafuer, dass die Groesse ueberhaupt nach rechts wandern durfte.
struct SizeStampPlaceholder: View {
    var body: some View {
        Color.clear
            .frame(width: RowMetrics.sizeColumnWidth)
            .accessibilityHidden(true)
    }
}
