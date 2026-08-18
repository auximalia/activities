import Foundation

/// Wie das Programm dem Anwender etwas sagt — und **welche** Form dafür gilt.
///
/// **⚠️ Diese Wahl war bis v2.0.10 keine Regel, sondern eine Gewohnheit.** Es
/// gab vier Meldekanäle: `errorMessage` ersetzte die ganze Ansicht, `actionError`
/// und `moveReport` waren Blätter, `sourceNotice` ein Streifen. Welche Form ein
/// neuer Fall bekam, wurde **jedes Mal neu und ohne Maßstab** entschieden — und
/// bei drei von ihnen lautete der Inhalt dasselbe: „etwas ging schief".
///
/// **⚠️ Zwei Blätter können nicht gleichzeitig stehen.** Löste ein Handgriff
/// zwei davon aus, verschluckte SwiftUI eines — **wortlos**. Das ist der Grund,
/// warum daraus eine Regel im Kern wurde und nicht nur ein aufgeräumter
/// Datentyp: Eine Warteschlange kann man zusichern, eine Gewohnheit nicht.
public enum NoticeKind: String, Sendable, Hashable, CaseIterable {
    /// Läuft weiter, verlangt keine Antwort. Für Auskünfte am Rand.
    case banner
    /// Hält an, verlangt Kenntnisnahme. Für Fehlschläge einzelner Handgriffe.
    case alert
    /// Ersetzt die Ansicht. Nur, wenn es **nichts zu sehen** gibt.
    case blocking
}

/// Eine Meldung, so wie sie gezeigt wird.
public struct Notice: Identifiable, Sendable, Equatable {
    public let id: UUID
    public let kind: NoticeKind
    public let title: String
    public let detail: String?

    public init(id: UUID = UUID(), kind: NoticeKind, title: String, detail: String? = nil) {
        self.id = id
        self.kind = kind
        self.title = title
        self.detail = detail
    }
}

/// Die Regel, welche Form eine Meldung bekommt — und in welcher Reihenfolge.
public enum NoticeRule {

    /// **⚠️ Die Form folgt der Frage „was kann der Anwender jetzt noch tun?", nicht
    /// der Schwere.**
    ///
    /// - `blocking`, wenn **nichts** mehr zu sehen ist — dann wäre ein Blatt über
    ///   einer leeren Fläche eine Meldung über nichts.
    /// - `alert`, wenn ein Handgriff fehlschlug, die Ansicht aber steht — der
    ///   Anwender hat etwas ausgelöst und muss die Antwort darauf sehen.
    /// - `banner` sonst — Auskünfte, die niemand angefordert hat, dürfen nicht
    ///   anhalten.
    ///
    /// *Vorher war das eine Ermessensfrage je Fall. Der Unterschied zwischen
    /// „gibt es noch etwas zu sehen" und „wie schlimm ist es" ist genau der,
    /// an dem `errorMessage` und `actionError` auseinandergelaufen sind.*
    public static func kind(hasContent: Bool, wasRequested: Bool) -> NoticeKind {
        if !hasContent { return .blocking }
        return wasRequested ? .alert : .banner
    }

    /// Welche Meldung als **nächste** gezeigt wird.
    ///
    /// **⚠️ Blockierendes zuerst, dann Blätter, dann Streifen.** Nicht weil es
    /// wichtiger wäre, sondern weil es die anderen ohnehin verdeckt: Ein Blatt
    /// über einer ersetzten Ansicht fragt nach etwas, das nicht mehr da ist.
    ///
    /// **⚠️ Bei gleicher Form gewinnt die ältere.** Sonst verdrängt ein zweiter
    /// Fehlschlag den ersten, und der Anwender liest nie, was zuerst schiefging —
    /// genau das tat SwiftUI bisher mit zwei gleichzeitigen Blättern, nur
    /// unbeabsichtigt.
    public static func next(from queue: [Notice]) -> Notice? {
        let order: [NoticeKind] = [.blocking, .alert, .banner]
        for kind in order {
            if let found = queue.first(where: { $0.kind == kind }) { return found }
        }
        return nil
    }

    /// Nimmt eine Meldung auf — **ohne Dopplung**.
    ///
    /// **⚠️ Derselbe Text zweimal ist keine zweite Meldung.** Ein Handgriff über
    /// fünf Dateien, der fünfmal an derselben Rechteschranke scheitert, erzeugt
    /// sonst fünf Blätter hintereinander.
    public static func appending(_ notice: Notice, to queue: [Notice]) -> [Notice] {
        guard !queue.contains(where: { $0.kind == notice.kind && $0.title == notice.title
                                        && $0.detail == notice.detail }) else { return queue }
        return queue + [notice]
    }
}
