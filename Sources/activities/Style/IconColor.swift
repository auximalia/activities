import SwiftUI
import AppKit
import CoreImage

/// Ermittelt die dominierende (mittlere) Farbe des Datei-Icons einer Endung,
/// zwischengespeichert pro Endung. Wird fuer die Balkenfarben im Diagramm genutzt.
enum IconColor {
    private static var cache: [String: Color] = [:]
    private static let context = CIContext(options: [.workingColorSpace: NSNull()])

    static func dominant(forExtension ext: String) -> Color {
        let key = ext.lowercased()
        if let cached = cache[key] { return cached }
        let base = averageColor(of: FileIconProvider.icon(forExtension: key)) ?? .gray
        let color = normalizeVividness(base)
        cache[key] = color
        return color
    }

    /// Hebt kraeftig gefaerbte Icons auf ein einheitliches Saettigungs-/Helligkeits-
    /// niveau (bessere Unterscheidbarkeit); nahezu graue Icons bleiben grau.
    private static func normalizeVividness(_ color: NSColor) -> Color {
        guard let rgb = color.usingColorSpace(.deviceRGB) else { return Color(color) }
        var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
        rgb.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)

        if saturation < 0.12 {
            // Graustufen-Icon: nur die Helligkeit in ein mittleres Band bringen.
            let b = min(max(brightness, 0.45), 0.72)
            return Color(hue: 0, saturation: 0, brightness: b)
        }
        let s = min(max(saturation, 0.55), 0.95)
        let b = min(max(brightness, 0.55), 0.9)
        return Color(hue: hue, saturation: s, brightness: b)
    }

    /// Mittlere Farbe der nicht-transparenten Bildanteile (per CIAreaAverage).
    private static func averageColor(of image: NSImage) -> NSColor? {
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let cgImage = bitmap.cgImage else { return nil }

        let ciImage = CIImage(cgImage: cgImage)
        guard let filter = CIFilter(name: "CIAreaAverage", parameters: [
            kCIInputImageKey: ciImage,
            kCIInputExtentKey: CIVector(cgRect: ciImage.extent),
        ]), let output = filter.outputImage else { return nil }

        var pixel = [UInt8](repeating: 0, count: 4)
        context.render(
            output,
            toBitmap: &pixel,
            rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8,
            colorSpace: CGColorSpaceCreateDeviceRGB()
        )

        let alpha = CGFloat(pixel[3]) / 255
        guard alpha > 0.01 else { return NSColor.gray }
        // Un-premultiplizieren, damit die Deckfarbe (nicht die Transparenz) zaehlt.
        let r = min(CGFloat(pixel[0]) / 255 / alpha, 1)
        let g = min(CGFloat(pixel[1]) / 255 / alpha, 1)
        let b = min(CGFloat(pixel[2]) / 255 / alpha, 1)
        return NSColor(deviceRed: r, green: g, blue: b, alpha: 1)
    }
}
