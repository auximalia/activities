import Foundation

/// Verlauf der besuchten **Wurzelordner** – vor und zurück wie im Browser.
///
/// **⚠️ Der erste zustandsbehaftete Typ in `ActivitiesCore`.** Alles andere hier
/// ist entweder ein zustandsloser Namensraum (`RowNavigation`, `FolderTree`,
/// `TimeBucket`) oder ein unveraenderlicher Wert (`RelevantFile`, `TreeRow`).
/// Das Backlog nannte `RowNavigation` als Vorbild – es ist keins: Dessen
/// `move(cursor:in:by:)` bekommt den Cursor herein und gibt ihn zurueck, es
/// haelt nichts.
///
/// Hier ist es anders, und zwar mit Absicht: Ein Verlauf **ist** Zustand. Ihn im
/// `ReportViewModel` zu fuehren hiesse, ihn in 1795 Zeilen und einer
/// asynchronen Ladekette zu verstecken, wo `CoreChecks` nicht hinkommt –
/// ausgerechnet die Logik, die erfahrungsgemaess falsch gebaut wird (siehe
/// ``visit(_:)``).
public struct FolderHistory: Equatable, Sendable {
    /// Die besuchten Ordner in Besuchsreihenfolge, aeltester zuerst.
    public private(set) var entries: [URL] = []
    /// Wo im Stapel wir gerade stehen; `nil`, solange nichts besucht wurde.
    public private(set) var position: Int?

    /// Obergrenze des Stapels.
    ///
    /// Dieselbe Zahl wie bei „Zuletzt benutzt" (`SettingsStore.maxRecent`).
    /// Bewusst dieselbe: Zwei verschiedene Obergrenzen fuer zwei Listen
    /// derselben Ordner waeren eine Erklaerung, die niemand hoeren will.
    public static let maxEntries = 8

    public init() {}

    /// Verlauf, der bereits auf einem Ordner steht (Start der Sitzung).
    public init(visiting url: URL) {
        visit(url)
    }

    /// Der Ordner, auf dem der Verlauf gerade steht.
    public var current: URL? {
        guard let position, entries.indices.contains(position) else { return nil }
        return entries[position]
    }

    public var canGoBack: Bool {
        guard let position else { return false }
        return position > 0
    }

    public var canGoForward: Bool {
        guard let position else { return false }
        return position < entries.count - 1
    }

    /// Ein neues Ziel wurde angesteuert.
    ///
    /// **⚠️ Der Vorwaertszweig wird abgeschnitten.** Wer zurueckgeht und dann
    /// woanders hin abbiegt, hat die alte Zukunft verlassen – sie stehen zu
    /// lassen fuehrte „Vorwaerts" in eine Vergangenheit, die es nicht mehr
    /// gibt. Das ist der Punkt, an dem Verlaufsstapel ueblicherweise falsch
    /// sind, und der Grund, warum dieser Typ geprueft wird und nicht nur
    /// geschrieben.
    ///
    /// **Derselbe Ordner erneut angesteuert aendert nichts.** Sonst fuellte ein
    /// wiederholtes ⌘R oder ein Klick auf den bereits offenen Ordner den Stapel
    /// mit Dubletten, durch die man sich anschliessend hindurchtippt.
    public mutating func visit(_ url: URL) {
        if current == url { return }

        if let position {
            entries.removeSubrange((position + 1)...)
        }
        entries.append(url)

        // ⚠️ Gekappt wird am ALTEN Ende. Der juengste Besuch ist der, zu dem
        // man zurueckkehrt; ihn zu verlieren waere das Gegenteil des Zwecks.
        if entries.count > Self.maxEntries {
            entries.removeFirst(entries.count - Self.maxEntries)
        }
        position = entries.count - 1
    }

    /// Einen Schritt zurueck; `nil`, wenn es nichts mehr gibt.
    public mutating func goBack() -> URL? {
        guard canGoBack, let position else { return nil }
        self.position = position - 1
        return current
    }

    /// Einen Schritt vorwaerts; `nil`, wenn es nichts mehr gibt.
    public mutating func goForward() -> URL? {
        guard canGoForward, let position else { return nil }
        self.position = position + 1
        return current
    }
}
