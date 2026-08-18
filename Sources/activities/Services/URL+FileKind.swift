import Foundation

extension URL {
    /// Ob unter diesem Pfad **auf der Platte** ein Ordner liegt.
    ///
    /// **⚠️ Nicht zu verwechseln mit `hasDirectoryPath`.** Jenes ist eine
    /// Eigenschaft der **URL** und nicht des Ordners: Es fehlt, wenn die URL
    /// ohne Schrägstrich am Ende gebildet wurde — etwa bei Verweisen, Aliassen
    /// oder eingehängten Laufwerken. Genau daran ist v1.19.51 einmal
    /// gescheitert; die Begründung steht bis heute in
    /// ``ReportViewModel/addSources(_:)``: *„Gefragt wird die Platte, nicht die
    /// Zeichenkette."*
    ///
    /// **⚠️ Im Zweifel `false`, und das ist eine Entscheidung.** Existiert der
    /// Pfad nicht oder ist er nicht lesbar, gilt er als **Datei**. Für jeden
    /// Aufrufer in diesem Programm ist das die vorsichtigere Antwort: Ordner
    /// dürfen weniger (nicht in sich selbst verschoben werden, nur leer in den
    /// Papierkorb), und wer irrtümlich als Datei gilt, wird strenger behandelt,
    /// nicht lockerer.
    ///
    /// *Diese Zeile stand bis v2.0.6 **neunmal** im Programm — siebenmal im
    /// Modell, zweimal im Verschiebedienst. Damit stand auch das `?? false`
    /// neunmal da: eine Entscheidung, die man achtmal richtig ändert.*
    var isDirectoryOnDisk: Bool {
        (try? resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
    }
}
