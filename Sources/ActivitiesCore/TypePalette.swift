import Foundation

/// Eine Farbe der kategorialen Palette, plattformunabhaengig als HSB abgelegt.
///
/// Bewusst **ohne** AppKit/SwiftUI, damit die Palette im Kern liegt und in
/// ``CoreChecks`` automatisiert auf Unterscheidbarkeit geprueft werden kann.
public struct PaletteColor: Sendable, Equatable {
    /// Farbton 0…1 (entspricht 0…360°).
    public let hue: Double
    /// Saettigung 0…1.
    public let saturation: Double
    /// Helligkeit 0…1.
    public let brightness: Double

    public init(hue: Double, saturation: Double, brightness: Double) {
        self.hue = hue
        self.saturation = saturation
        self.brightness = brightness
    }

    /// Bequemer Konstruktor mit Grad-Angabe.
    public init(degrees: Double, saturation: Double, brightness: Double) {
        self.init(hue: degrees / 360, saturation: saturation, brightness: brightness)
    }

    /// Ob die Farbe neutral (grau) ist. Nur **eine** Palettenfarbe darf das sein.
    public var isNeutral: Bool { saturation < 0.05 }

    /// sRGB-Komponenten 0…1.
    public var rgb: (red: Double, green: Double, blue: Double) {
        let h = (hue - hue.rounded(.down)) * 6
        let sector = Int(h)
        let f = h - Double(sector)
        let p = brightness * (1 - saturation)
        let q = brightness * (1 - saturation * f)
        let t = brightness * (1 - saturation * (1 - f))
        switch sector {
        case 0: return (brightness, t, p)
        case 1: return (q, brightness, p)
        case 2: return (p, brightness, t)
        case 3: return (p, q, brightness)
        case 4: return (t, p, brightness)
        default: return (brightness, p, q)
        }
    }

    /// CIELAB-Koordinaten (D65) – Grundlage der Abstandsmessung.
    public var lab: (l: Double, a: Double, b: Double) {
        func linear(_ v: Double) -> Double {
            v <= 0.04045 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
        }
        let (r0, g0, b0) = rgb
        let r = linear(r0), g = linear(g0), b = linear(b0)
        let x = (0.4124 * r + 0.3576 * g + 0.1805 * b) / 0.95047
        let y = 0.2126 * r + 0.7152 * g + 0.0722 * b
        let z = (0.0193 * r + 0.1192 * g + 0.9505 * b) / 1.08883
        func f(_ v: Double) -> Double { v > 0.008856 ? pow(v, 1.0 / 3) : (7.787 * v) + 16.0 / 116 }
        let fx = f(x), fy = f(y), fz = f(z)
        return (116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz))
    }

    /// Wahrnehmungsabstand nach CIE76 zu einer anderen Farbe.
    ///
    /// Als Schwelle fuer **kategoriale** Unterscheidbarkeit gilt hier ΔE ≥ 25;
    /// darunter verschwimmen zwei Flaechen im Diagramm miteinander.
    public func deltaE(to other: PaletteColor) -> Double {
        let a = lab, b = other.lab
        return ((a.l - b.l) * (a.l - b.l) + (a.a - b.a) * (a.a - b.a) + (a.b - b.b) * (a.b - b.b)).squareRoot()
    }
}

/// Kategoriale Farbpalette fuer Dateitypen.
///
/// **Warum eine feste Palette statt der Icon-Farbe?** Die Farbe aus dem
/// Datei-Icon abzuleiten schlaegt systematisch fehl: macOS-Dokumentsymbole sind
/// bewusst einheitlich gestaltet (weisses Blatt, kleiner blauer Akzent). Sieben
/// gaengige Endungen liefern dadurch **exakt** denselben Grauton, mehrere
/// weitere denselben Blauton. Man greift ein System ab, das auf *Aehnlichkeit*
/// optimiert ist, und braucht *Unterscheidbarkeit*.
///
/// **Warum genau 11 Farben?** Fuer kategoriale Kodierung gelten rund 11–12
/// Farben als Obergrenze der zuverlaessigen Unterscheidbarkeit. Das deckt sich
/// mit der Anzeige: 10 Einzeltypen + Sammel-Eintrag "Sonstige".
///
/// **Schichten:** Diese Palette bildet die **Datenschicht** (ΔE ≥ 25 zueinander
/// und zum Hintergrund). Wochenend-Baender und Rasterlinien gehoeren zur
/// **Kontextschicht** und bleiben bewusst dicht am Hintergrund (ΔE ≤ 15), damit
/// sie nie als Datum gelesen werden.
public enum TypePalette {
    /// Die zehn bunten Farben. Reihenfolge = Index der Zuordnung.
    public static let chromatic: [PaletteColor] = [
        PaletteColor(degrees: 358, saturation: 0.72, brightness: 0.86), // 0 Rot
        PaletteColor(degrees:  26, saturation: 0.85, brightness: 0.90), // 1 Orange
        PaletteColor(degrees:  44, saturation: 0.88, brightness: 0.80), // 2 Amber
        PaletteColor(degrees:  72, saturation: 0.70, brightness: 0.72), // 3 Limette
        PaletteColor(degrees: 142, saturation: 0.70, brightness: 0.68), // 4 Gruen
        PaletteColor(degrees: 172, saturation: 0.75, brightness: 0.70), // 5 Tuerkis
        PaletteColor(degrees: 199, saturation: 0.72, brightness: 0.86), // 6 Himmelblau
        PaletteColor(degrees: 224, saturation: 0.72, brightness: 0.82), // 7 Blau
        PaletteColor(degrees: 274, saturation: 0.55, brightness: 0.80), // 8 Violett
        PaletteColor(degrees: 322, saturation: 0.62, brightness: 0.82), // 9 Magenta
    ]

    /// Reserviertes Neutralgrau fuer "Sonstige". **Die einzige** graue Flaeche
    /// der Datenschicht – deshalb darf keine bunte Farbe nahezu grau sein.
    public static let neutral = PaletteColor(hue: 0, saturation: 0, brightness: 0.62)

    /// Alle Farben der Datenschicht (bunt + neutral).
    public static var all: [PaletteColor] { chromatic + [neutral] }

    /// Kuratierte Vorzugsplaetze: nur dort, wo eine Erwartung besteht
    /// (Dokumenttypen) oder die Zuordnung im Alltag hilft (Programmiersprachen).
    ///
    /// Mehrere Endungen duerfen denselben Vorzug haben (z. B. `xlsx`/`xls`/`csv`);
    /// sind sie gleichzeitig sichtbar, weicht die zweite ueber
    /// ``assignment(for:)`` deterministisch auf den naechsten freien Platz aus.
    private static let preferred: [String: Int] = [
        // Dokumente – starke Erwartungshaltung
        "pdf": 0,
        "xlsx": 4, "xls": 4, "csv": 4, "numbers": 4,
        "docx": 7, "doc": 7, "pages": 7,
        "png": 9, "jpg": 9, "jpeg": 9, "heic": 9, "gif": 9, "svg": 9, "webp": 9,
        // Programmiersprachen und Konfiguration
        "swift": 1,
        "py": 2,
        "js": 3, "mjs": 3, "ts": 3, "tsx": 3, "jsx": 3,
        "md": 5, "markdown": 5, "txt": 5,
        "json": 6, "yaml": 6, "yml": 6, "toml": 6,
        "sh": 8, "command": 8, "zsh": 8, "bash": 8,
    ]

    /// Vorzugsplatz einer Endung, falls kuratiert.
    public static func preferredIndex(forExtension ext: String) -> Int? {
        preferred[ext.lowercased()]
    }

    /// Stabiler Index fuer nicht kuratierte Endungen (FNV-1a).
    ///
    /// **Nicht** ``Hasher`` verwenden: Swifts Standard-Hash ist pro Prozess
    /// zufaellig initialisiert – die Farbe wuerde sich bei jedem Start aendern.
    public static func fallbackIndex(forExtension ext: String) -> Int {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in ext.lowercased().utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01b3
        }
        return Int(hash % UInt64(chromatic.count))
    }

    /// Ordnet einer Menge von Endungen eindeutige Farbplaetze zu.
    ///
    /// **Zielkonflikt:** Eindeutigkeit verlangt den Blick auf die sichtbare
    /// Menge, Stabilitaet verlangt Unabhaengigkeit davon. Beides zugleich ist
    /// bei begrenzter Palette unmoeglich. Der Kompromiss:
    /// - **Eindeutigkeit ist garantiert** (nie zwei gleiche Farben im Bild),
    /// - **Stabilitaet ist bestmoeglich**: kuratierte Endungen werden zuerst
    ///   bedient und behalten ihren Platz; die Reihenfolge ist alphabetisch und
    ///   damit unabhaengig von der Haeufigkeit. Ein Wechsel des Zeitraums
    ///   aendert die Farbe also nicht, solange die Typmenge gleich bleibt.
    public static func assignment(for extensions: [String]) -> [String: Int] {
        let normalized = Array(Set(extensions.map { $0.lowercased() }))
        let curated = normalized.filter { preferred[$0] != nil }.sorted()
        let others = normalized.filter { preferred[$0] == nil }.sorted()

        var used = Set<Int>()
        var result: [String: Int] = [:]
        for ext in curated + others {
            let base = preferred[ext] ?? fallbackIndex(forExtension: ext)
            var index = base
            var steps = 0
            while used.contains(index) && steps < chromatic.count {
                index = (index + 1) % chromatic.count
                steps += 1
            }
            used.insert(index)
            result[ext] = index
        }
        return result
    }

    /// Farbe zu einem Platz; ausserhalb des Bereichs faellt sie auf Neutral zurueck.
    public static func color(at index: Int) -> PaletteColor {
        guard chromatic.indices.contains(index) else { return neutral }
        return chromatic[index]
    }
}
