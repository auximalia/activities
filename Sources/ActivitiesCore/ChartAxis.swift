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

    /// Ab wann ein Zeitstempel „Zukunft" heißt: der **Beginn des morgigen Tages**.
    ///
    /// Nicht „jetzt": Eine Datei, die heute um 23:50 Uhr geschrieben wird,
    /// während die Uhr auf 09:00 steht, ist eine Zeitzonen-Abweichung und keine
    /// Zeitreise.
    ///
    /// **⚠️ Eigene Funktion, damit die Grenze *einmal* gebildet werden kann.**
    /// Sie kostet zwei ICU-Kalenderoperationen (``Calendar/startOfDay(for:)``
    /// und ``Calendar/date(byAdding:value:to:)``). Bis v2.1.1 steckten beide
    /// in ``isInFuture(_:now:calendar:)`` und liefen damit **je Datei**;
    /// gemessen auf einem MacBook mit `swiftc -O`: 0,353 s bei 83.000 Dateien,
    /// 2,039 s bei 500.000. Mit vorgebildeter Grenze sind es 0,4 ms bzw. 2,4 ms
    /// – Faktor rund 840. Der Unterschied war in der Praxis eine Sekunde
    /// Tastatur-Verzögerung je Zeichen im Suchfeld (siehe ``countInFuture``).
    ///
    /// `nil`, wenn der Kalender keinen Folgetag bilden kann. Aufrufer werten das
    /// als „nichts liegt in der Zukunft" – lieber kein Hinweis als ein falscher.
    public static func futureBoundary(
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Date? {
        calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))
    }

    /// Ob dieser Zeitstempel jenseits von heute liegt.
    ///
    /// Grundlage des Hinweises. Bequemlichkeit für den Einzelfall; wer über
    /// viele Dateien läuft, nimmt ``futureBoundary(now:calendar:)`` **einmal**
    /// und vergleicht danach nur noch – oder gleich ``countInFuture``.
    public static func isInFuture(
        _ timestamp: Date,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Bool {
        guard let morgen = futureBoundary(now: now, calendar: calendar) else { return false }
        return timestamp >= morgen
    }

    /// Wie viele dieser Dateien jenseits von heute datiert sind.
    ///
    /// **⚠️ Die Schleife steht hier und nicht in der Ansicht.** Sie läuft über
    /// den **gesamten Rohbestand** – bei einer großen Quelle sechsstellig – und
    /// wird aus einem SwiftUI-Rumpf heraus gelesen, also bei jeder
    /// Neuauswertung neu. Genau daran ist v2.1.1 gescheitert: Weil das
    /// Suchfeld denselben Rumpf invalidiert, kostete **jeder Tastendruck** einen
    /// vollen Durchlauf, und die Buchstaben erschienen im Sekundentakt. Im Kern
    /// ist die Grenze einmal gebildet und ``CoreChecks`` kann es prüfen; in der
    /// Ansicht wäre beides wieder verloren.
    public static func countInFuture(
        _ files: [RelevantFile],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Int {
        guard let morgen = futureBoundary(now: now, calendar: calendar) else { return 0 }
        return files.count { $0.timestamp >= morgen }
    }
}
