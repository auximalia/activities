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
        let color = averageColor(of: FileIconProvider.icon(forExtension: key)) ?? .gray
        cache[key] = color
        return color
    }

    /// Mittlere Farbe der nicht-transparenten Bildanteile (per CIAreaAverage).
    private static func averageColor(of image: NSImage) -> Color? {
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
        guard alpha > 0.01 else { return .gray }
        // Un-premultiplizieren, damit die Deckfarbe (nicht die Transparenz) zaehlt.
        let r = min(CGFloat(pixel[0]) / 255 / alpha, 1)
        let g = min(CGFloat(pixel[1]) / 255 / alpha, 1)
        let b = min(CGFloat(pixel[2]) / 255 / alpha, 1)
        return Color(red: r, green: g, blue: b)
    }
}
