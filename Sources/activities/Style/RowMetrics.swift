import SwiftUI

/// Zentrale Masse fuer die Zeilendarstellung (Ordner-/Dateizeilen und Baumlinien).
///
/// Die Werte sind bewusst an einer Stelle gebuendelt, damit Einrueckung,
/// Konnektor-Rinne und Datumsspalte zueinander passen.
enum RowMetrics {
    /// Waagerechter Innenabstand einer Zeile (links wie rechts).
    static let horizontalPadding: CGFloat = 8
    /// Breite des Aufklapp-Zeichens in der Ordnerzeile.
    ///
    /// **⚠️ Ein Kreis mit `+` und `−`, und das ist die zweite Aenderung an dieser
    /// Stelle innerhalb eines Tages – beide Male aus der Praxis gemeldet.** Die
    /// Geschichte gehoert hierher, damit niemand einen der Schritte
    /// zurueckdreht:
    ///
    /// 1. Urspruenglich `chevron.right`/`chevron.down` – eine *Strichzeichnung*
    ///    von 10 pt, deren beide Zustaende sich **nur durch Drehung**
    ///    unterschieden. Gemeldet als „nicht eindeutig und gut erfassbar".
    /// 2. Dann `arrowtriangle.*.fill` (v1.19.46), mit dem Argument der
    ///    Plattform-Konvention fuer Baumansichten (Finder, `NSOutlineView`).
    ///    Das behob die *Flaeche*, aber die Zustaende unterschieden sich
    ///    weiterhin nur durch die **Richtung** desselben Zeichens.
    /// 3. Jetzt `plus.circle`/`minus.circle`: **zwei verschiedene Zeichen**
    ///    statt eines gedrehten. Das ist der Unterschied, den das Auge ohne
    ///    Vergleich erfasst – und der Punkt, den die ersten beiden Fassungen
    ///    beide verfehlt haben.
    ///
    /// **⚠️ Der Einwand dagegen wurde geprueft und nicht bloss abgewogen:** Auf
    /// macOS bedeuten ⊕/⊖ ueblicherweise *hinzufuegen* und *entfernen*. In
    /// **diesem** Programm aber nicht – Quellen und Regeln werden ueber
    /// Textknoepfe hinzugefuegt und entfernt („Quelle hinzufuegen …",
    /// „Entfernen"), und `plus.circle` kommt sonst nirgends vor. Es gibt also
    /// keine Kollision im eigenen Vokabular. *Waere eine da, gaelte die
    /// Entscheidung nicht.*
    ///
    /// **⚠️ Der Kontrast war nie das Problem** – gemessen 4,51:1 auf der hellen
    /// Zeile und 4,25:1 auf der Zebrazeile, bei einer Schwelle von 3:1 fuer
    /// Bedienelemente. Wer hier an der Farbe dreht, behebt etwas, das nie kaputt
    /// war, und macht das Zeichen lauter als den Ordnernamen, den es ordnet.
    ///
    /// **⚠️ Das Plus traegt mehr Gewicht als das Minus, und das ist keine
    /// Verzierung.** Zugeklappt **verbirgt** der Knoten etwas – das Zeichen ist
    /// eine Aufforderung. Aufgeklappt verbirgt er nichts mehr, und das Zeichen
    /// darf zuruecktreten. Das ungleiche Gewicht kodiert also, welcher der
    /// beiden Zustaende noch etwas hinter sich hat; gleiches Gewicht wuerde
    /// diese Auskunft wegwerfen.
    ///
    /// **⚠️ Der Unterschied liegt allein im GEWICHT, nicht in der Farbe – und
    /// das ist gemessen, nicht abgewogen.** Die Vorlage aus der Praxis (XMind)
    /// zeichnet das Minus zusaetzlich deutlich heller. Nachgerechnet erreicht
    /// `tertiaryLabel` aber nur **2,20 / 2,07 : 1** (hell, beide Zebratoene) und
    /// **2,84 / 2,47 : 1** (dunkel) – durchweg **unter der 3:1-Schwelle fuer
    /// Bedienelemente**. Beide Zeichen bleiben deshalb auf `secondaryLabel`
    /// (4,51 / 4,25 : 1). *Wer das Minus nachtraeglich aufhellt, macht es
    /// unzugaenglich, und es sieht dabei besser aus – das ist die gefaehrliche
    /// Sorte Verbesserung.*
    ///
    /// Dieselbe Logik benutzt die Baumzeile bereits an anderer Stelle: Ein
    /// Knoten ohne Kinder und ohne sichtbare Dateien zeichnet sein Zeichen mit
    /// 0,25 Deckkraft – nichts dahinter, also kaum Gewicht.
    ///
    /// Der Zustand wird ausserdem **nicht nur** ueber das Zeichen getragen:
    /// ``FolderRowView`` sagt ihn als „, aufgeklappt" / „, zugeklappt" an.
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
    /// Hoehe **jeder** Zeile – Ordner wie Datei, Baum wie Liste.
    ///
    /// **⚠️ Feste Hoehe statt Innenabstand.** Vorher hatte die Ordnerzeile 3 pt
    /// und die Dateizeile 2 pt Innenabstand; bei gleichem Symbol ergab das 24
    /// gegen 22 pt. Der Unterschied faellt in einer langen Liste als Stocken
    /// auf. Mit einer festen Hoehe bleibt es gleich, auch wenn spaeter jemand
    /// eine Schrift oder ein Symbol aendert – der haeufigste Weg, wie so eine
    /// Angleichung wieder verlorengeht.
    static let rowHeight: CGFloat = 22

    /// Hoehe eines Abschnittskopfs in der Zeitansicht.
    ///
    /// Bewusst hoeher als eine Zeile: Der Kopf gliedert die Liste, er ist kein
    /// Eintrag darin. Gleiche Hoehe liesse ihn als eine weitere Zeile lesen.
    static let sectionHeaderHeight: CGFloat = 30
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
    ///
    /// **⚠️ Aus der laengsten Angabe gemessen, nicht geschaetzt.** In
    /// monospaced **12 pt** misst „Mi., 05.08.2025 14:32" **155,8 pt**; mit
    /// gut 3 pt Luft ergibt das 159.
    ///
    /// Die Werte sind **dreimal** gewandert und jedes Mal aus demselben Grund:
    /// Eine Maßangabe, die zu ihrer Zeit stimmte, und eine Änderung, die ihr
    /// die Grundlage entzog. 150 pt galten, solange das Jahr im laufenden Jahr
    /// entfiel (PR-32 → 158), 158 pt galten bei 12 pt Schrift (PR-38 → 146),
    /// 146 pt galten bei 11 pt Nebenangaben (UX-50 → 159).
    static let dateColumnWidth: CGFloat = 159
    /// Schmalere Datumsspalte im Kompakt-Layout.
    ///
    /// Ebenso gemessen: „Mi. 05.08.25 14:32" misst bei 12 pt 133,5 pt.
    static let dateColumnWidthCompact: CGFloat = 137

    /// Feste Breite der Groessenspalte (PR-37, verschmaelert in PR-39).
    ///
    /// **⚠️ Hier bestimmt die Spalte die Formatierung, nicht umgekehrt.** Die
    /// Vorgabe lautet sechs Zeichen; ``SizeFormatting`` richtet sich danach und
    /// rundet, wo es sonst nicht passt. Gemessen bei 11 pt monospaced sind
    /// sechs Zeichen **40,8 pt**, plus gut 3 pt Luft.
    ///
    /// Die vorherige Fassung (58 pt) stammte aus der umgekehrten Richtung: Dort
    /// gab die Systemformatierung die Breite vor, und die laengste Ausgabe
    /// („999,9 MB") bestimmte die Spalte. Am rechten Rand ist eine ruhige,
    /// schmale Kante mehr wert als die zweite Nachkommastelle.
    ///
    /// Bei 12 pt (UX-50) messen sechs Zeichen **44,5 pt** → 48.
    static let sizeColumnWidth: CGFloat = 48

    /// Farbe des senkrechten Trenners zwischen Datums- und Groessenspalte.
    ///
    /// **⚠️ Gemessen, nicht gewaehlt.** ΔE an den gezeichneten Pixeln: **7,1**
    /// im hellen, **8,6** im dunklen Erscheinungsbild. Das Zebra liegt bei
    /// 2,5/4,7, der Abschnittskopf bei 11,6/15,1. Die Linie liegt bewusst
    /// dazwischen: ueber dem Zebra, sonst waere sie keine Linie, sondern eine
    /// Ahnung – und klar unter dem Abschnittskopf, sonst konkurrierte ein
    /// Spaltendetail mit der Gliederung der Liste.
    static let columnRuleColor = Color.primary.opacity(0.08)

    /// Abstand des Trenners vom rechten Zeilenrand.
    ///
    /// Genau die Mitte zwischen Datums- und Groessenspalte: Innenabstand der
    /// Zeile + Spaltenbreite + halber Elementabstand.
    static var columnRuleInset: CGFloat {
        horizontalPadding + sizeColumnWidth + itemSpacing / 2
    }

    /// Schriftgroesse des **Inhalts** einer Zeile – Datei- und Ordnername.
    ///
    /// **⚠️ 12 pt lagen UNTER der Plattform-Norm.** `NSFont.systemFontSize` ist
    /// **13 pt**; die Namen standen also kleiner als alles, was macOS selbst
    /// als Inhalt setzt. Gemeldet als „strengt sehr an" – und der Anwender hatte
    /// nicht einen Geschmack, sondern einen Messwert auf seiner Seite.
    ///
    /// **⚠️ Diese Groesse ist umsonst zu haben, und das ist der Grund fuer 14
    /// statt 13.** Gemessen:
    ///
    /// - **Senkrecht:** ``rowHeight`` haengt am 16-pt-Symbol (18 pt Block). Die
    ///   Systemschrift misst 14,1 pt Zeilenhoehe bei 12 pt, 16,5 bei 14 pt und
    ///   17,7 bei 15 pt – **alle unter 18**. Die Zeile wird nicht hoeher, die
    ///   Liste zeigt gleich viele Eintraege.
    /// - **Waagerecht:** Der Name ist die *flexible* Spalte. Er nimmt, was
    ///   uebrig ist, und kostet keine feste Breite.
    ///
    /// Der Preis der Aenderung steckt allein in ``metaFontSize``. Wer den Namen
    /// weiter vergroessern will, hat bis 15 pt freie Bahn; darueber muss
    /// ``rowHeight`` mit.
    static let nameFontSize: CGFloat = 14

    /// Schriftgroesse aller **Nebenangaben** in einer Zeile (Datum, Groesse, Pfad).
    ///
    /// **⚠️ 12 pt ist die Regel, nicht der Einzelfall.** Statuszeile,
    /// Filterhinweis, Pfad, Datum und Groesse teilen sich diese Groesse; der
    /// Inhalt steht bei ``nameFontSize``. Damit bleibt die Rangordnung
    /// **Inhalt 14 pt, Nebenangabe 12 pt.**
    ///
    /// **⚠️ Diese Zahl ist die teure.** Sie bestimmt ueber die gemessene
    /// Textbreite die festen Spalten, und die gehen dem Dateinamen ab:
    ///
    /// | Nebenangabe | Datumsspalte | Groessenspalte | fest gesamt |
    /// |---|---|---|---|
    /// | 11 pt (bis UX-50) | 146 | 44 | – |
    /// | **12 pt** | **159** | **48** | **+17 pt** |
    /// | 13 pt | 172 | 52 | +34 pt |
    ///
    /// **⚠️ Nach unten ist bei 11 pt der Boden**, nicht Luft: In PR-33 wurde die
    /// Statuszeile von 10 auf 11 pt *angehoben*, weil `secondary` nur 3,82:1
    /// erreicht (hell) und dann nicht auch noch die kleinste Schrift tragen
    /// darf. Die Erhoehung auf 12 folgt derselben Richtung.
    ///
    /// **⚠️ Am Kontrast aendert die Groesse nichts.** `secondaryLabel` bleibt
    /// bei 3,82:1 und damit unter AA (4,5:1); die Erleichterung auf 3:1 gilt
    /// erst ab 18 pt. Wirkt es zu **blass**, ist der Hebel die Farbe.
    static let metaFontSize: CGFloat = 12

    /// Ab welcher Fensterbreite auf das Kompakt-Layout umgeschaltet wird.
    ///
    /// Darunter kostet die Zeile zu viel an feste Bestandteile (Datumsspalte,
    /// Einrueckung, Pfad) und fuer den Dateinamen bleibt kaum Platz. Statt alles
    /// zu quetschen, entfaellt dann der Pfad (bleibt im Tooltip) und die
    /// Datumsspalte wird kuerzer.
    ///
    /// **⚠️ Mitgewandert von 940 auf 957 (UX-50).** Die festen Bestandteile sind
    /// mit ``metaFontSize`` um 17 pt gewachsen; bliebe die Schwelle stehen,
    /// bekaeme der Dateiname bei schmalem Fenster genau diese 17 pt weniger als
    /// vorher – die Schwelle waere dann eine Zahl ohne Bezug.
    static let compactThreshold: CGFloat = 957

    /// Datumsspaltenbreite je Layout.
    static func dateColumnWidth(compact: Bool) -> CGFloat {
        compact ? dateColumnWidthCompact : dateColumnWidth
    }

    /// Farbe der Baumlinien.
    static let connectorColor = Color.secondary.opacity(0.45)

    /// Hintergrund einer Zeile – abwechselnd, als Lesehilfe fuer die
    /// waagerechte Zuordnung (welches Datum am rechten Rand gehoert hierher?).
    ///
    /// **Warum nicht ``NSColor.alternatingContentBackgroundColors[1]``?** Die
    /// Systemfarbe ist fuer genau diesen Zweck gedacht und voellig in Ordnung –
    /// fuer **diese** Liste aber zu kraeftig. An den gezeichneten Pixeln
    /// gemessen: im dunklen Erscheinungsbild `#282828` gegen `#454545`,
    /// ΔE ≈ 12,3. UX-12 hatte fuer das fruehere Zebra ΔE 7,6 gemessen und als
    /// „deutlich genug, ohne zu dominieren" bewertet. Der helle Streifen sticht
    /// dadurch hervor, statt nur zu gliedern.
    ///
    /// Deshalb wird der Wechselton **selbst gemischt**: Grundfarbe plus ein
    /// kleiner Anteil der Textfarbe. Der Anteil ist je Erscheinungsbild
    /// verschieden, weil die Textfarbe einmal schwarz und einmal weiss ist –
    /// derselbe Anteil ergaebe verschiedene Abstaende.
    ///
    /// *Lehre, schon zum zweiten Mal (nach UX-12): Kontrast messen, nicht
    /// schaetzen – und zwar am Bildschirm, nicht am Farbwert.*
    static func rowBackground(alternate: Bool) -> Color {
        Color(nsColor: alternate ? alternateRowColor : baseRowColor)
    }

    /// Anteil der Textfarbe im Wechselton – je Erscheinungsbild.
    ///
    /// Bewusst niedrig: Das Zebra soll die Zeile fuehren, nicht auffallen.
    /// Gemessen (ΔE zum Grundton) gegenueber den Systemfarben:
    ///
    /// | | vorher (System) | jetzt |
    /// |---|---|---|
    /// | hell   | 3,6 | ~2,5 |
    /// | dunkel | 12,3 | ~5,3 |
    ///
    /// Die beiden Anteile unterscheiden sich, weil die Textfarbe einmal schwarz
    /// und einmal weiss ist – derselbe Anteil ergaebe verschiedene Abstaende.
    private static let alternateBlendDark: CGFloat = 0.030
    private static let alternateBlendLight: CGFloat = 0.035

    /// Grundton der Zeilen (weiss im hellen, sehr dunkles Grau im dunklen Modus).
    private static let baseRowColor = NSColor.alternatingContentBackgroundColors[0]

    /// Der Wechselton, aus dem Grundton gemischt.
    private static let alternateRowColor = NSColor(name: "activitiesAlternateRow") { appearance in
        var result = NSColor.alternatingContentBackgroundColors[0]
        appearance.performAsCurrentDrawingAppearance {
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            guard let base = NSColor.alternatingContentBackgroundColors[0].usingColorSpace(.sRGB),
                  let label = NSColor.labelColor.usingColorSpace(.sRGB)
            else { return }
            result = base.blended(
                withFraction: isDark ? alternateBlendDark : alternateBlendLight,
                of: label
            ) ?? base
        }
        return result
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
    ///
    /// **Gemessen, damit die Zusicherung nachpruefbar bleibt** (ΔE zu den
    /// beiden Zeilentoenen, an den gezeichneten Pixeln):
    ///
    /// | | gegen Grundton | gegen Wechselton | Zebra zum Vergleich |
    /// |---|---|---|---|
    /// | hell   | 11,6 | 9,1  | 2,5 |
    /// | dunkel | 15,1 | 10,4 | 4,7 |
    ///
    /// Die Flaeche ist damit **deutlich** abgesetzt – deshalb wurde sie beim
    /// Nachschaerfen der Abschnittskoepfe (PR-33) auch nicht angefasst. Wer
    /// hier drehen will, sollte vorher nachmessen: Der gemeldete „graue
    /// Schleier" lag an der Schriftgroesse, nicht an dieser Farbe.
    static let sectionHeaderOverlay = Color.primary.opacity(0.06)

    /// Feine Oberlinie am Abschnittskopf – schliesst den vorigen Abschnitt ab.
    ///
    /// Eine Linie ist die staerkste Zaesur je aufgewendeter Tinte: Sie wirkt,
    /// ohne eine weitere Graustufe in die Liste zu bringen.
    static let sectionHeaderRule = Color.primary.opacity(0.14)

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
