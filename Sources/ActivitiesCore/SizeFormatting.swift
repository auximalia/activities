import Foundation

/// Dateigroessen fuer die Oberflaeche.
public enum SizeFormatting {
    /// Hoechstlaenge der Kurzform in Zeichen.
    ///
    /// Die Spalte steht am **rechten Rand** und ist fest; sechs Zeichen sind
    /// die Vorgabe, an der sich die Formatierung auszurichten hat – nicht
    /// umgekehrt. Wird gerundet, ist das der Preis.
    public static let maxLength = 6

    /// Einheiten in Tausenderschritten – **dezimal wie der Finder**
    /// (1 MB = 1.000.000 Bytes), nicht binaer.
    ///
    /// Die App steht neben dem Finder; zwei verschiedene Zahlen fuer dieselbe
    /// Datei waeren unerklaerlich.
    private static let units = ["B", "kB", "MB", "GB", "TB", "PB"]

    /// Kurzform fuer die Groessenspalte – „1,2 MB" · „999 kB" · „12 MB".
    ///
    /// **⚠️ Hoechstens ``maxLength`` Zeichen, zugesichert und geprueft.** Die
    /// Regel dahinter ist eine einzige: **eine Nachkommastelle nur unterhalb
    /// von 10.** Damit ist die laengste moegliche Ausgabe „999 kB" bzw.
    /// „1,2 MB" – beide genau sechs Zeichen. Ohne diese Regel entstuenden
    /// „12,3 MB" (sieben) und „1,23 GB" (sieben), und die feste Spalte
    /// schnitte ab.
    ///
    /// **⚠️ Hier wurde eine fruehere Entscheidung umgestossen.** In PR-37 stand
    /// bei einer leeren Datei „0 Bytes", ausdruecklich weil der Finder das so
    /// zeigt. Mit sechs Zeichen ist dafuer kein Platz mehr – es heisst jetzt
    /// „0 B", wie jede andere Byte-Angabe auch. Die Begruendung von damals war
    /// nicht falsch, sie ist nur einer engeren Vorgabe gewichen; einheitlich
    /// innerhalb der Spalte wiegt hier schwerer als die Anlehnung an den Finder.
    ///
    /// - Parameter bytes: `nil`, wenn die Groesse nicht gelesen werden konnte.
    ///   Dann bleibt die Spalte **leer**. Ein „–" oder „?" waere eine Angabe
    ///   ueber etwas, worueber wir nichts wissen; Leere ist ehrlicher.
    public static func short(_ bytes: Int?) -> String {
        guard let bytes else { return "" }
        let (number, unit) = parts(bytes)
        // ⚠️ Festes Raster: Zahl **rechts** in drei Zellen, Einheit **links** in
        // zwei – zusammen mit dem Trennzeichen immer genau ``maxLength``.
        //
        // Rechtsbuendigkeit allein genuegt nicht: Sie richtet nur die rechte
        // Kante aus. „999 B" und „1,2 MB" haben verschieden lange Einheiten,
        // wodurch die Ziffern von Zeile zu Zeile versetzt sitzen – in einer
        // langen Liste ein sichtbares Flimmern. Erst wenn auch die Einheit eine
        // feste Zelle bekommt, stehen die Zahlen untereinander.
        let paddedNumber = String(repeating: pad, count: max(0, 3 - number.count)) + number
        let paddedUnit = unit + String(repeating: pad, count: max(0, 2 - unit.count))
        return "\(paddedNumber) \(paddedUnit)"
    }

    /// **⚠️ Geschuetztes Leerzeichen als Fuellung, kein gewoehnliches.**
    /// Fuehrende und nachgestellte Leerzeichen sind das Erste, was
    /// Textdarstellung und Zwischenablage wegwerfen – und mit ihnen ginge genau
    /// das Raster verloren, um dessentwillen sie da sind. U+00A0 ueberlebt das
    /// und ist in dieser Schrift gleich breit.
    private static let pad = "\u{00A0}"

    /// Zahl und Einheit getrennt – die eigentliche Rechnung.
    private static func parts(_ bytes: Int) -> (String, String) {
        guard bytes > 0 else { return ("0", units[0]) }

        var value = Double(bytes)
        var unit = 0
        while value >= 1000, unit < units.count - 1 {
            value /= 1000
            unit += 1
        }

        while true {
            // Bytes sind ganzzahlig – „1,0 B" waere eine Genauigkeit, die es
            // nicht gibt.
            if unit > 0, value < decimalCeiling {
                let text = String(format: "%.1f", value).replacingOccurrences(of: ".", with: ",")
                return (text, units[unit])
            }
            let whole = value.rounded()
            if whole < 1000 || unit == units.count - 1 {
                return (String(Int(whole)), units[unit])
            }
            // ⚠️ Ueberlauf durch Runden: 999 950 Bytes ergaeben „1000 kB" –
            // sieben Zeichen und die falsche Einheit dazu.
            value /= 1000
            unit += 1
        }
    }

    /// Ab hier entfaellt die Nachkommastelle.
    ///
    /// **⚠️ 9,95 und nicht 10.** Die Entscheidung „eine Nachkommastelle?" muss
    /// gegen den **gerundeten** Wert fallen, nicht gegen den rohen. Bei 9,99 GB
    /// ist der rohe Wert kleiner als 10, die Ausgabe aber „10,0 GB" – sieben
    /// Zeichen, und die feste Spalte schnitte ab. Gefunden hat das nicht das
    /// Auge, sondern ein Prueflauf ueber den ganzen Wertebereich; an
    /// Beispielwerten waere es durchgerutscht.
    private static let decimalCeiling = 9.95
}
