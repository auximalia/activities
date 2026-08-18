import Foundation

/// Den Zeitraum am Mausrad verstellen: sammeln, in Tage umrechnen, begrenzen.
///
/// **⚠️ Warum das im Kern liegt und nicht im Ereignisbehandler.** Hier stehen
/// drei Regeln, die man einer `NSView` nicht ansieht und die niemandem
/// auffallen, wenn sie leise falsch werden: wieviel Eingabe **einen Tag**
/// ergibt, wo **Schluss** ist, und wann aus einer Tageszahl der Modus **„Alle"**
/// wird. Ein Drehen, das um einen Tag danebenliegt, fühlt sich völlig richtig
/// an – genau die Sorte Fehler, gegen die Lehre 4 geschrieben ist.
///
/// **⚠️ Eine Raste ist ein Tag – Festlegung des Eigentümers, gegen meinen
/// Vorschlag.** Geplant war eine Leiter aus Haltepunkten (1, 2, 3, … 90, 365,
/// 3650), weil eine Raste je Tag **3649 Rasten** bis zum Anschlag bedeutet.
/// Entschieden wurde die feine Auflösung, und der Einwand ist damit erledigt,
/// nicht vergessen: Wer den Anschlag will, nimmt ⌘0 oder das Zahlenfeld. Das
/// Rad ist für die **Feineinstellung** da, und dafür ist ein Tag je Raste die
/// richtige Auflösung.
///
/// Das Verstellen selbst ist absichtlich **folgenlos**, bis die Geste endet:
/// ``DayScrub`` verändert nur sich selbst. Was ein angewandter Schritt kostet,
/// steht in `ReportViewModel.namePatternDidChange` – 0,6 s bei 100.000, 3,0 s
/// bei 500.000 Dateien. *Dreihundert Rasten sind dreihundert Rechnungen, wenn
/// man sie einzeln anwendet, und eine, wenn man wartet.*
public struct DayScrub: Equatable, Sendable {

    /// Was der Zeitraum an Tagen annehmen darf.
    ///
    /// **⚠️ Diese Grenze stand bis v1.19.70 an drei Stellen** – im Modell
    /// (`setDays`), im Schrittfeld der Werkzeugleiste und in dessen Hilfetext.
    /// Das Rad wäre die vierte gewesen. Drei Kopien einer Zahl sind bereits
    /// zwei zu viel; sie stehen jetzt hier.
    public static let dayRange: ClosedRange<Int> = 1...3650

    /// Wieviel stufenlose Eingabe einen Tag ergibt.
    ///
    /// **⚠️ Diese Zahl ist hergeleitet, nicht am Gerät gemessen – und das steht
    /// hier, statt als Messung ausgegeben zu werden.** Eine Maus meldet ganze
    /// Zeilen (`hasPreciseScrollingDeltas == false`), dort ist „eine Raste =
    /// ein Tag" exakt und diese Zahl unbeteiligt. Ein Trackpad meldet Punkte,
    /// stufenlos; 10 Punkte je Zeile ist AppKits eigene Umrechnung für
    /// zeilenweisen Bildlauf. *Ob sich das unter den Fingern richtig anfühlt,
    /// kann nur der Anwender beantworten – die Frage steht in der Abnahme, und
    /// wenn sie mit „zu schnell" beantwortet wird, ist es genau eine Zahl.*
    public static let pointsPerDay: Double = 10

    /// Die Eingabe, wie sie vom Gerät kommt.
    public enum Input: Equatable, Sendable {
        /// Echtes Mausrad: ganze Rasten.
        case notches(Double)
        /// Trackpad: Punkte, stufenlos.
        case points(Double)
    }

    /// Die vorgemerkte Tageszahl.
    public private(set) var days: Int

    /// Ob über den Anschlag hinaus nach „Alle" gedreht wurde.
    ///
    /// **⚠️ Ein eigener Zustand, keine 3651.** „Alle" ist kein Zeitraum von
    /// besonderer Länge, sondern die Abwesenheit eines Zeitfensters
    /// (`ignoreTimeWindow`). Es als Zahl zu führen hieße, den Modus über eine
    /// Grenze wieder hereinzuschmuggeln, die es gerade nicht gibt.
    public private(set) var isAllTime: Bool

    /// Angesammelte Eingabe, die noch keinen ganzen Tag ergeben hat.
    ///
    /// **⚠️ Seit v1.19.74 nur noch für die großen Schritte zuständig.** Vorher
    /// war er das Einzige, was ein stufenloses Gerät überhaupt vorankommen
    /// ließ – und genau daran lag die gemeldete Verzögerung, weil bis zum
    /// ersten ganzen Tag mehrere Ereignisse vergingen. Den Mindestschritt
    /// erledigt jetzt ``advance(_:)``; der Rest sorgt nur noch dafür, dass eine
    /// **schnelle** Bewegung mehr als einen Tag je Ereignis zurücklegt.
    private var carry: Double

    public init(days: Int, isAllTime: Bool = false) {
        self.days = Self.clamp(days)
        self.isAllTime = isAllTime
        self.carry = 0
    }

    public static func clamp(_ value: Int) -> Int {
        min(max(value, dayRange.lowerBound), dayRange.upperBound)
    }

    // MARK: - Verstellen

    /// Nimmt ein Eingabeereignis auf.
    ///
    /// **Vorzeichen:** positiv bedeutet **mehr Tage**. Das ist die Richtung
    /// jedes Schrittfeldes – nach oben wird der Wert größer –, und sie folgt
    /// damit von selbst der Bildlaufrichtung des Systems, weil AppKit das
    /// Vorzeichen bereits gedreht hat, wenn „natürliches Scrollen" an ist.
    ///
    /// **⚠️ Jedes Ereignis bewegt die Zahl um mindestens einen Tag –
    /// Festlegung des Eigentümers (v1.19.74): *„Die Anzeige der Tage muss sich
    /// beim Drehen unmittelbar – ohne Verzögerung – anpassen."***
    ///
    /// Das ist keine Kosmetik, sondern die Antwort auf ein Gerät ohne Rasten.
    /// Ein Rad meldet ganze Zeilen, dort war „eine Raste = ein Tag" von Anfang
    /// an exakt. Eine **Magic Mouse** und ein Trackpad melden Punkte, stufenlos
    /// – bei ``pointsPerDay`` = 10 und 1–3 Punkten je Ereignis stand die Zahl
    /// mehrere Ereignisse lang still, und genau das wurde als Verzögerung
    /// gemeldet. *Der Fehler saß nicht in der Anzeige, sondern in der
    /// Umrechnung davor: Sie hat die Bewegung verschluckt, bevor irgendetwas
    /// zu zeichnen war.*
    ///
    /// **Der Preis, offen benannt:** Auf einem stufenlosen Gerät zählt jetzt
    /// jedes Ereignis, nicht jeder zehnte Punkt – eine Wischbewegung bewegt
    /// deshalb deutlich mehr Tage als vorher. Für ein Rad ändert sich nichts.
    ///
    /// - Returns: `true`, wenn sich die Anzeige geändert hat.
    @discardableResult
    public mutating func advance(_ input: Input) -> Bool {
        let vorherTage = days
        let vorherAlle = isAllTime

        let roh: Double
        switch input {
        case let .notches(n): roh = n
        case let .points(p): roh = p / Self.pointsPerDay
        }
        guard roh != 0 else { return false }
        carry += roh

        // ⚠️ Zur Null hin abschneiden, nicht abrunden: Bei einem Wechsel der
        // Drehrichtung darf der aufgehobene Rest nicht in die neue Richtung
        // durchschlagen. `Int(-0.4)` ist 0, `floor(-0.4)` waere -1.
        var steps = Int(carry)
        if steps == 0 {
            // ⚠️ Mindestens ein Tag je Ereignis. Der Rest wird dabei
            // zurueckgesetzt und NICHT aufgehoben – sonst zaehlte dieselbe
            // Bewegung zweimal, einmal als Mindestschritt und spaeter noch
            // einmal aus dem angesparten Rest.
            steps = roh > 0 ? 1 : -1
            carry = 0
        } else {
            carry -= Double(steps)
        }

        apply(steps: steps)
        return days != vorherTage || isAllTime != vorherAlle
    }

    /// Ganze Tagesschritte anwenden – der prüfbare Kern von ``advance(_:)``.
    ///
    /// **⚠️ „Alle" liegt genau eine Raste hinter dem Anschlag und ist ein
    /// Endpunkt, kein Umlauf.** Weiterdrehen dort bleibt „Alle"; eine Raste
    /// zurück führt auf 3650 und nicht auf 3649 – sonst überspränge der Rückweg
    /// den Anschlag, den der Hinweg gerade erst erreicht hat.
    public mutating func apply(steps: Int) {
        guard steps != 0 else { return }
        var rest = steps

        if isAllTime {
            if rest > 0 { return }          // weiter geht es nicht
            isAllTime = false
            days = Self.dayRange.upperBound
            rest += 1
            if rest == 0 { return }
        }

        let target = days + rest
        if target > Self.dayRange.upperBound {
            // Der Anschlag wird nicht uebersprungen: Er ist eine eigene Raste.
            if days == Self.dayRange.upperBound {
                isAllTime = true
            } else {
                days = Self.dayRange.upperBound
            }
        } else {
            days = Self.clamp(target)
        }
    }

    // MARK: - Anzeige

    /// Was während des Drehens dasteht.
    ///
    /// **⚠️ Dieselbe Formulierung wie in der Überschrift**
    /// (``DateFormatting/spanLabel(days:)``) – bis auf „Alle". Zwei Wortlaute
    /// für dieselbe Sache in einem Fenster wären der Fehler, den die
    /// Kürzeltabelle (UX-39) schon einmal gemacht hat.
    public var label: String {
        isAllTime ? "Alle" : DateFormatting.spanLabel(days: days)
    }

    /// Ob der vorgemerkte Wert überhaupt etwas ändern würde.
    ///
    /// **⚠️ Der Modus zählt mit, nicht nur die Zahl.** Steht der Zeitraum auf
    /// „Spanne", so ändert das Anwenden **immer** etwas – es verlässt diesen
    /// Modus –, auch wenn die Tageszahl zufällig dieselbe ist. Ohne diesen Fall
    /// wäre das Rad in „Spanne" sichtbar am Zählen und wirkungslos: Die Anzeige
    /// zählte, die Prüfung sagte „nichts geändert", und es geschähe nichts.
    public func differs(fromDays currentDays: Int, isAllTime currentAll: Bool,
                        usesRange usesRange: Bool = false) -> Bool {
        if usesRange { return true }
        return isAllTime != currentAll || (!isAllTime && days != currentDays)
    }
}
