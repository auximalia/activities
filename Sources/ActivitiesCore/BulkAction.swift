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
        /// **In einen anderen Ordner verschieben** (v1.19.77).
        ///
        /// ⚠️ Der sechste Weg – und der erste, der etwas **veraendert**. Der
        /// Kommentar oben sagt seit jeher „der sechste Weg, der spaeter
        /// dazukommt, haette sie garantiert nicht"; hier ist er, und er hat sie.
        /// Bei den fuenf anderen kostet eine zu grosse Menge Zeit und Nerven,
        /// bei diesem waere sie ein Eingriff in fremde Ordner.
        case move(String)
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
        case .move(let ordner):
            return "\(objects) nach \u{201E}\(ordner)\u{201C} verschieben?"
        }
    }

    /// Erklaerender Zusatz unter der Frage.
    ///
    /// Nennt die **Folge**, nicht die Handlung: Dass geoeffnet wird, steht
    /// bereits in der Frage; was das bedeutet – so viele Fenster, so viele
    /// gestartete Programme –, ist die Information, die zur Entscheidung fehlt.
    ///
    /// **⚠️ Bei ``Kind/open`` kommt seit Sprint 17 ein zweiter Satz dazu, wenn
    /// Skripte oder Programme in der Menge liegen.** Das Argument ist dasselbe,
    /// mit dem die Zahl hier steht, nur eine Stufe weiter: Wer fünfzig Objekte
    /// öffnet, von denen zwölf ausgeführt werden, trifft ohne diese Angabe eine
    /// andere Entscheidung, als er glaubt.
    ///
    /// **⚠️ Es wird informiert, nicht blockiert.** Die Auswahl hat der Anwender
    /// selbst zusammengestellt – anders als bei „Arbeit fortsetzen", wo das
    /// Programm sie bildet und deshalb die Schranke greift. Wer die Auswahl hier
    /// beschneidet, nimmt dem Werkzeug seinen Zweck.
    public static func explanation(kind: Kind, count: Int, executables: Int = 0) -> String {
        switch kind {
        case .open:
            let grund = "Es werden \(count) Fenster geöffnet, je nach Dateityp in verschiedenen Programmen."
            guard executables > 0 else { return grund }
            let objekte = executables == 1 ? "eine Datei" : "\(executables) Dateien"
            return grund + " Darunter \(objekte), die dabei ausgeführt werden."
        case .reveal:
            return "Der Finder zeigt \(count) Objekte an."
        case .openInApp(let app):
            return "\(app) erhält \(count) Objekte auf einmal."
        case .move(let ordner):
            // ⚠️ Nennt die FOLGE: dass sie ihren bisherigen Ort verlassen.
            // „Werden verschoben" wiederholte nur die Handlung.
            return "\(count) Dateien verlassen ihren bisherigen Ordner und liegen danach "
                + "in \u{201E}\(ordner)\u{201C}. Mit \(Shortcuts.undoMove.display) rückgängig zu machen."
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
        case .move: return "Verschieben"
        }
    }
}
