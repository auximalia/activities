import SwiftUI
import AppKit

/// Ermittelt eine kraeftige, unterscheidbare Farbe aus dem Datei-Icon einer
/// Endung – bevorzugt die farbigen Bildanteile (nicht den grau/weiss dominierten
/// Durchschnitt). Ergebnisse werden pro Endung zwischengespeichert.
enum IconColor {
    private static var cache: [String: Color] = [:]

    static func dominant(forExtension ext: String) -> Color {
        let key = ext.lowercased()
        if let cached = cache[key] { return cached }
        let color = colorfulColor(of: FileIconProvider.icon(forExtension: key)) ?? .gray
        cache[key] = color
        return color
    }

    /// Sucht die dominierende farbige Bildfarbe. Fehlt Farbe (Graustufen-Icon),
    /// wird ein normalisierter Grauton zurueckgegeben.
    private static func colorfulColor(of image: NSImage) -> Color? {
        let size = 32
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        var data = [UInt8](repeating: 0, count: size * size * 4)
        guard let context = CGContext(
            data: &data,
            width: size,
            height: size,
            bitsPerComponent: 8,
            bytesPerRow: size * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        context.clear(CGRect(x: 0, y: 0, width: size, height: size))
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: size, height: size))

        // Sättigungsgewichteter Mittelwert der farbigen Pixel (+ Fallback: Deckfarbe).
        var cr = 0.0, cg = 0.0, cb = 0.0, cw = 0.0
        var orr = 0.0, org = 0.0, orb = 0.0, ow = 0.0

        for i in stride(from: 0, to: data.count, by: 4) {
            let a = Double(data[i + 3]) / 255
            if a < 0.3 { continue }
            let r = min(Double(data[i]) / 255 / a, 1)
            let g = min(Double(data[i + 1]) / 255 / a, 1)
            let b = min(Double(data[i + 2]) / 255 / a, 1)

            orr += r * a; org += g * a; orb += b * a; ow += a

            let maxc = max(r, g, b), minc = min(r, g, b)
            let saturation = maxc <= 0 ? 0 : (maxc - minc) / maxc
            if saturation >= 0.22 && maxc >= 0.15 && maxc <= 0.99 {
                let weight = saturation * a
                cr += r * weight; cg += g * weight; cb += b * weight; cw += weight
            }
        }

        if cw > 0.75 {
            return normalizeVividness(NSColor(deviceRed: cr / cw, green: cg / cw, blue: cb / cw, alpha: 1))
        }
        if ow > 0 {
            return normalizeVividness(NSColor(deviceRed: orr / ow, green: org / ow, blue: orb / ow, alpha: 1))
        }
        return nil
    }

    /// Hebt farbige Icons auf ein einheitliches Saettigungs-/Helligkeitsniveau
    /// (bessere Unterscheidbarkeit); nahezu graue Icons bleiben grau.
    private static func normalizeVividness(_ color: NSColor) -> Color {
        guard let rgb = color.usingColorSpace(.deviceRGB) else { return Color(color) }
        var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
        rgb.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)

        if saturation < 0.12 {
            let b = min(max(brightness, 0.45), 0.72)
            return Color(hue: 0, saturation: 0, brightness: b)
        }
        let s = min(max(saturation, 0.6), 0.95)
        let b = min(max(brightness, 0.55), 0.9)
        return Color(hue: hue, saturation: s, brightness: b)
    }
}
