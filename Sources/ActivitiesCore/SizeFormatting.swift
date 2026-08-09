import Foundation

/// Dateigroessen fuer die Oberflaeche.
public enum SizeFormatting {
    /// **⚠️ Dezimal wie der Finder** (1 MB = 1.000.000 Bytes), nicht binaer.
    /// Die App steht neben dem Finder; zwei verschiedene Zahlen fuer dieselbe
    /// Datei waeren unerklaerlich. `.file` trifft genau die Zaehlweise, die
    /// macOS im Informationsfenster zeigt.
    ///
    /// **⚠️ Sprache fest auf `de_DE`, wie bei ``DateFormatting``.** Ohne das
    /// richtete sich die Ausgabe nach der Systemsprache – neben einem deutschen
    /// „Mi., 05.08.2025" stuende dann ein englisches „1.2 MB", mit Punkt statt
    /// Komma. Und die Pruefungen in `CoreChecks` haetten je nach Rechner ein
    /// anderes Ergebnis, waeren also gar keine.
    private static let locale = Locale(identifier: "de_DE")

    /// Kurzform fuer die Groessenspalte – „1,2 MB" · „999,9 MB" · „0 Bytes".
    ///
    /// - Parameter bytes: `nil`, wenn die Groesse nicht gelesen werden konnte.
    ///   Dann bleibt die Spalte **leer**. Ein „–" oder „?" waere eine Angabe
    ///   ueber etwas, worueber wir nichts wissen; Leere ist ehrlicher und
    ///   ruhiger.
    ///
    /// **⚠️ Das Trennzeichen wird vereinheitlicht, und der Grund ist ein Fund.**
    /// `ByteCountFormatStyle` setzt zwischen Zahl und Einheit **mal** ein
    /// geschuetztes Leerzeichen (U+00A0), **mal** ein gewoehnliches (U+0020) –
    /// gemessen in derselben Sprache mit demselben Stil:
    ///
    /// | Wert | Trennzeichen |
    /// |---|---|
    /// | `1` → „1 Byte" | U+00A0 |
    /// | `1_000_000` → „1 MB" | U+0020 |
    /// | `12_300_000` → „12,3 MB" | U+0020 |
    /// | `1_230_000_000` → „1,23 GB" | U+00A0 |
    ///
    /// Auf dem Bildschirm sieht man keinen Unterschied – beide sind in dieser
    /// Schrift gleich breit. Aber es sind zwei Formen fuer dieselbe Sache, und
    /// die Lehre aus PR-32 gilt hier genauso: Jeder Vergleich, jede Suche und
    /// jede Pruefung waere sonst ein Gluecksspiel, je nach Groessenordnung.
    public static func short(_ bytes: Int?) -> String {
        guard let bytes else { return "" }
        // ⚠️ Sonderfall Null: Die Systemformatierung liefert „0 kB". Eine leere
        // Datei ist aber keine Angelegenheit von Kilobytes – „0 Bytes" ist das,
        // was der Finder zeigt und was man erwartet.
        guard bytes != 0 else { return "0 Bytes" }
        let formatted = Int64(bytes).formatted(.byteCount(style: .file).locale(locale))
        return formatted.replacingOccurrences(of: "\u{00A0}", with: " ")
    }
}
