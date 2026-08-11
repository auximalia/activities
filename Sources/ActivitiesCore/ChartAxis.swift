import Foundation

/// Regeln der Diagramm-Achse, die keine Ansicht kennen muss.
///
/// Sie stehen im Kern, weil sie **Zusicherungen** sind und keine Darstellung:
/// wie weit die Achse reicht und wie viele Beschriftungen sie trägt. Beides war
/// vorher in der App-Schicht verteilt und deshalb von ``CoreChecks``
/// unerreichbar – und beides ist genau dort auseinandergelaufen.
public enum ChartAxis {
    /// Der letzte Tag, den die Achse zeigt.
    ///
    /// **⚠️ Nie nach heute – auch wenn Dateien später datiert sind.** Aus der
    /// Praxis gemeldet: Eine einzige Datei mit dem Zeitstempel **2091** zog die
    /// Achse über 70 Jahre, und der gesamte echte Bestand rückte in die linken
    /// rund 5 % der Fläche. Ein Zeitstempel nach heute ist **unmöglich**.
    ///
    /// **⚠️ Nur dieses eine Ende wird gekappt.** Ein Datum von 1994 ist nicht
    /// unmöglich, sondern nur ungewöhnlich – es kann ein echtes Archiv sein. Wer
    /// beide Enden kappt, macht aus einer Tatsachenaussage eine Geschmacksfrage.
    /// *Sollte sich die ferne Vergangenheit als Problem erweisen, ist das ein
    /// eigener Befund mit eigenem Beleg.*
    ///
    /// **⚠️ Gekappt wird die Achse, nicht der Bestand.** Die betroffenen Dateien
    /// bleiben in Liste und Baum; ein Hinweis nennt ihre Zahl. Sie aus den Daten
    /// zu werfen wäre die bequemere und die unehrlichere Antwort – das Programm
    /// schwiege dann über seine eigenen Daten.
    public static func endDay(
        lastData: Date,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Date {
        min(calendar.startOfDay(for: lastData), calendar.startOfDay(for: now))
    }

    /// Der erste Tag, den die Achse zeigt.
    ///
    /// Ebenfalls nach oben begrenzt: Läge **alles** in der Zukunft, wäre der
    /// Anfang sonst später als das Ende und die Spanne negativ.
    public static func startDay(
        firstData: Date,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Date {
        min(calendar.startOfDay(for: firstData), calendar.startOfDay(for: now))
    }

    /// Ob dieser Zeitstempel jenseits von heute liegt.
    ///
    /// Grundlage des Hinweises. Die Grenze ist der **Beginn des morgigen Tages**
    /// und nicht „jetzt": Eine Datei, die heute um 23:50 Uhr geschrieben wird,
    /// während die Uhr auf 09:00 steht, ist eine Zeitzonen-Abweichung und keine
    /// Zeitreise.
    public static func isInFuture(
        _ timestamp: Date,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Bool {
        guard let morgen = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))
        else { return false }
        return timestamp >= morgen
    }
}
