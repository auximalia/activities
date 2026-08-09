import Foundation

/// Wann eine stille Update-Suche faellig ist.
///
/// **⚠️ Die Regel liegt hier und nicht im Dienst, weil sie die einzige Stelle
/// ist, an der man sich vertun kann.** Ein Takt-Dienst besteht aus Warten und
/// Aufrufen – daran ist nichts zu pruefen. Ob eine Pruefung *faellig* ist,
/// haengt dagegen an einem gespeicherten Zeitpunkt, einer Zeitspanne und drei
/// Sonderfaellen (nie geprueft, Uhr zurueckgestellt, Rechner tagelang aus).
public enum UpdateSchedule {
    /// Abstand zwischen zwei stillen Pruefungen.
    ///
    /// **24 Stunden – und bewusst nicht einstellbar.** Ein Regler fuer etwas,
    /// dessen Wirkung niemand beobachten kann, ist Beschaeftigung, keine
    /// Einstellung.
    ///
    /// **⚠️ Nicht auf Minuten stellen, auch wenn es technisch ginge.** Die
    /// GitHub-API ohne Token ist auf 60 Anfragen je Stunde und IP gedeckelt.
    /// Bei 24 h ist das weit weg; bei einem Minutentakt teilte man sich das
    /// Kontingent mit jedem anderen Programm im selben Netz.
    public static let interval: TimeInterval = 24 * 60 * 60

    /// Ob jetzt geprueft werden soll.
    ///
    /// - `lastCheck == nil` → ja. Beim allerersten Start ist die Pruefung
    ///   faellig, sonst erfuehre man 24 Stunden lang nichts.
    /// - **⚠️ Ein Zeitpunkt in der Zukunft gilt als faellig.** Das passiert,
    ///   wenn jemand die Systemuhr zurueckstellt oder ein Rechner mit falscher
    ///   Zeit startet. Rechnete man stur weiter, waere die naechste Pruefung
    ///   erst faellig, wenn die Zukunft eingeholt ist – bei einem Fehlgriff um
    ///   ein Jahr also nie. Lieber einmal zu frueh pruefen als nie wieder.
    public static func isDue(
        lastCheck: Date?,
        now: Date,
        interval: TimeInterval = interval
    ) -> Bool {
        guard let lastCheck else { return true }
        let elapsed = now.timeIntervalSince(lastCheck)
        return elapsed < 0 || elapsed >= interval
    }
}
