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
    /// Schriftgroesse der Liste – **durchgereicht**, nicht global gelesen.
    ///
    /// **⚠️ Sonst zeichnet SwiftUI nicht neu.** Diese Ansicht beobachtet das
    /// Modell nicht; laege die Groesse als statischer Wert in ``RowMetrics``,
    /// aenderte sich beim Umschalten kein gespeicherter Wert dieser Ansicht –
    /// und ob sie neu gezeichnet wird, waere Glueckssache.
    let size: RowSize
    /// Gedaempft darstellen – fuer Eintraege **ausserhalb** des Zeitraums.
    ///
    /// Das ist ein Zustand, keine Formatierung: Deshalb bleibt er als
    /// Schalter erhalten, waehrend Farbe und Gewicht fest sind.
    var isDimmed: Bool = false

    var body: some View {
        Text(isCompact
             ? DateFormatting.dateTimeCompact(date)
             : DateFormatting.dateTime(date))
            .font(.system(size: size.metaFontSize, design: .monospaced))
            .foregroundStyle(.secondary)
            .opacity(isDimmed ? RowMetrics.outOfWindowTextOpacity : 1)
            .lineLimit(1)
            .frame(width: size.dateColumnWidth(compact: isCompact), alignment: .trailing)
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
    /// Schriftgroesse der Liste (siehe ``DateStampView/size``).
    let size: RowSize
    /// Gedaempft darstellen – fuer Eintraege ausserhalb des Zeitraums.
    var isDimmed: Bool = false

    var body: some View {
        Text(SizeFormatting.short(bytes))
            .font(.system(size: size.metaFontSize, design: .monospaced))
            .foregroundStyle(.secondary)
            .opacity(isDimmed ? RowMetrics.outOfWindowTextOpacity : 1)
            .lineLimit(1)
            .frame(width: size.sizeColumnWidth, alignment: .trailing)
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
    /// Schriftgroesse der Liste – die Spaltenbreite haengt daran.
    let size: RowSize

    var body: some View {
        Color.clear
            .frame(width: size.sizeColumnWidth)
            .accessibilityHidden(true)
    }
}

/// Senkrechter Trenner zwischen Datums- und Groessenspalte (PR-40).
///
/// **⚠️ Warum das UX-09 nicht widerspricht.** Dort wurde entschieden: *ein*
/// Trennsystem in der Tabelle – Zebra statt waagerechter Linien, weil beides
/// zusammen Unruhe erzeugt. Diese Linie steht **senkrecht** und beantwortet
/// eine andere Frage: nicht „wo endet die Zeile", sondern „wo endet die
/// Spalte". Baumlinien duerfen aus demselben Grund bleiben (Hierarchie).
///
/// **⚠️ Gemessen, damit sie nicht lauter wird als das, was sie ordnet.**
/// `Color.primary.opacity(0.08)` ergibt an den gezeichneten Pixeln:
///
/// | | Linie gegen Zeile | Zebra zum Vergleich | Abschnittskopf |
/// |---|---|---|---|
/// | hell   | ΔE 7,1 | 2,5 | 11,6 |
/// | dunkel | ΔE 8,6 | 4,7 | 15,1 |
///
/// Ueber dem Zebra – sonst waere sie keine Linie, sondern eine Ahnung. Klar
/// unter dem Abschnittskopf – sonst konkurrierte ein Spaltendetail mit der
/// Gliederung der Liste (Lehre aus UX-11: *Kontext darf nie lauter sein als
/// Inhalt*).
///
/// **⚠️ Sie wird auf die **Zeile** gelegt, nicht in die Spalte.** Als Element
/// im `HStack` kostete sie zusaetzlich zweimal ``RowMetrics/itemSpacing`` an
/// Breite und waere nur so hoch wie ihr Text. Als Ueberlagerung der fertigen
/// Zeile kostet sie nichts und reicht ueber die volle Zeilenhoehe – erst
/// dadurch entsteht aus den Einzelstuecken eine durchgehende senkrechte Kante.
private struct ColumnRule: ViewModifier {
    /// Im Kompakt-Layout gibt es keine Groessenspalte – dann auch keinen Trenner.
    let isVisible: Bool
    /// Schriftgroesse – die Groessenspalte und damit die Lage des Trenners
    /// haengen daran.
    let size: RowSize

    func body(content: Content) -> some View {
        content.overlay(alignment: .trailing) {
            if isVisible {
                Rectangle()
                    .fill(RowMetrics.columnRuleColor)
                    .frame(width: 1)
                    .offset(x: -RowMetrics.columnRuleInset(size))
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
    }
}

extension View {
    /// Legt den Spaltentrenner zwischen Datum und Groesse ueber die Zeile.
    ///
    /// **Muss nach dem Innenabstand der Zeile stehen**, damit der Abstand zum
    /// rechten Rand derselbe ist wie der der Groessenspalte.
    func columnRule(isVisible: Bool, size: RowSize) -> some View {
        modifier(ColumnRule(isVisible: isVisible, size: size))
    }
}
