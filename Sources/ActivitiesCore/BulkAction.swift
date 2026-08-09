import Foundation

/// Regeln fuer Handgriffe, die auf **mehrere** Objekte gleichzeitig wirken.
///
/// **Warum es diesen Typ ueberhaupt gibt.** ⌘A markiert jede sichtbare Datei,
/// Enter oeffnet die Markierung – bis hierher ohne jede Obergrenze. Im
/// Alltagsfall sind das drei Dateien. Im „Alle"-Modus ueber einen grossen Baum
/// ist es der **gesamte Bestand**; fuer den gemessenen Baum sind das ~83.000
/// Dateien, also ~83.000 Programmstarts auf eine Tastenfolge hin. Ein
/// Handgriff, der sich um vier Groessenordnungen unterscheiden kann, je nachdem
/// welcher Schalter gerade steht, braucht eine Bremse.
///
/// **⚠️ Die Bremse gehoert hierher, nicht zu den Aufrufern.** Es gibt heute
/// fuenf Wege, die mehrere Objekte auf einmal loslassen (Enter, „Oeffnen (n)",
/// „Im Finder anzeigen (n)", Editor, Terminal). Laege die Grenze bei ihnen,
/// gaebe es fuenf Gelegenheiten, sie zu vergessen – und der sechste Weg, der
/// spaeter dazukommt, haette sie garantiert nicht.
public enum BulkAction {
    /// Was mit der Menge geschehen soll. Bestimmt **nur die Formulierung** der
    /// Rueckfrage, nicht die Schwelle: Fuenfzig Fenster im Finder sind genauso
    /// laestig wie fuenfzig gestartete Programme.
    public enum Kind: Sendable, Hashable {
        /// Mit der jeweiligen Standard-Anwendung oeffnen.
        case open
        /// Im Finder anzeigen.
        case reveal
        /// In einem benannten Programm oeffnen (Editor, Terminal).
        case openInApp(String)
    }

    /// Ab **wie vielen** Objekten zurueckgefragt wird.
    ///
    /// **⚠️ Diese Zahl ist gesetzt, nicht gemessen – und das soll man ihr
    /// ansehen.** Messen liesse sich hier nichts Sinnvolles: Es gibt keinen
    /// Schwellenwert, ab dem das Oeffnen „objektiv" zu viel wird. Die Zahl
    /// trennt zwei *Absichten*:
    ///
    /// - Bis etwa zehn Dateien hat man jede einzelne angeklickt. Wer so
    ///   auswaehlt, weiss, was er tut – eine Rueckfrage waere Bevormundung und
    ///   wuerde bei taeglichem Gebrauch weggeklickt, ohne gelesen zu werden.
    ///   Genau so verliert eine Rueckfrage ihre Wirkung.
    /// - Darueber stammt die Menge fast immer aus einem **Befehl** (⌘A) und
    ///   nicht aus Klicks. Dort ist die Zahl eine Ueberraschung, und genau die
    ///   soll die Rueckfrage sichtbar machen.
    ///
    /// Wer sie aendern will, sollte also nicht ueber Systemlast nachdenken,
    /// sondern darueber, ab wann eine Auswahl nicht mehr von Hand entstanden
    /// sein kann.
    public static let confirmationThreshold = 10

    /// Ob vor dem Ausfuehren zurueckgefragt werden muss.
    ///
    /// Die Schwelle ist eine **Ober**grenze fuer das stille Ausfuehren: Genau
    /// ``confirmationThreshold`` Objekte laufen noch durch, erst das naechste
    /// fragt.
    public static func needsConfirmation(
        count: Int,
        threshold: Int = confirmationThreshold
    ) -> Bool {
        count > threshold
    }

    /// Die Rueckfrage im Wortlaut – **mit der Anzahl**.
    ///
    /// Die Zahl ist der ganze Zweck der Rueckfrage. „Moechten Sie die Dateien
    /// wirklich oeffnen?" beantwortet die einzige Frage nicht, auf die es
    /// ankommt: *wie viele?* Ohne sie waere der Dialog nur eine Verzoegerung.
    public static func question(kind: Kind, count: Int) -> String {
        let objects = "\(count) \(count == 1 ? "Objekt" : "Objekte")"
        switch kind {
        case .open:
            return "\(objects) öffnen?"
        case .reveal:
            return "\(objects) im Finder anzeigen?"
        case .openInApp(let app):
            return "\(objects) in \(app) öffnen?"
        }
    }

    /// Erklaerender Zusatz unter der Frage.
    ///
    /// Nennt die **Folge**, nicht die Handlung: Dass geoeffnet wird, steht
    /// bereits in der Frage; was das bedeutet – so viele Fenster, so viele
    /// gestartete Programme –, ist die Information, die zur Entscheidung fehlt.
    public static func explanation(kind: Kind, count: Int) -> String {
        switch kind {
        case .open:
            return "Es werden \(count) Fenster geöffnet, je nach Dateityp in verschiedenen Programmen."
        case .reveal:
            return "Der Finder zeigt \(count) Objekte an."
        case .openInApp(let app):
            return "\(app) erhält \(count) Objekte auf einmal."
        }
    }

    /// Beschriftung des bestaetigenden Knopfes.
    ///
    /// Benennt die **Handlung**, nicht „OK". Wer nur „OK" liest, hat die Frage
    /// unter Umstaenden nicht gelesen – der Knopf soll fuer sich sagen, was
    /// gleich geschieht.
    public static func confirmLabel(kind: Kind) -> String {
        switch kind {
        case .open: return "Öffnen"
        case .reveal: return "Anzeigen"
        case .openInApp(let app): return "In \(app) öffnen"
        }
    }
}
