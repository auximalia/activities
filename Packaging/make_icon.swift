import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

// Erzeugt das App-Icon (blauer, gefuellter Kreis mit LED-Glanz) in allen fuer
// ein macOS-.iconset benoetigten Groessen.
//
// Aufruf: swift make_icon.swift <ziel-iconset-verzeichnis>

guard CommandLine.arguments.count >= 2 else {
    FileHandle.standardError.write(Data("Aufruf: swift make_icon.swift <iconset-dir>\n".utf8))
    exit(2)
}

let outputDir = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try? FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

/// Zeichnet das Icon in der angegebenen Pixelgroesse und schreibt eine PNG-Datei.
func renderIcon(pixelSize: Int, to url: URL) {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard let context = CGContext(
        data: nil,
        width: pixelSize,
        height: pixelSize,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return }

    let size = CGFloat(pixelSize)
    context.clear(CGRect(x: 0, y: 0, width: size, height: size))

    // Kreis mit etwas Rand.
    let inset = size * 0.12
    let circleRect = CGRect(x: inset, y: inset, width: size - 2 * inset, height: size - 2 * inset)
    let center = CGPoint(x: circleRect.midX, y: circleRect.midY)
    let radius = circleRect.width / 2

    // Radialverlauf fuer den LED-Effekt (heller Kern -> kraeftiges Blau -> dunkler Rand).
    let colors = [
        CGColor(red: 0.55, green: 0.80, blue: 1.00, alpha: 1.0),
        CGColor(red: 0.00, green: 0.40, blue: 0.95, alpha: 1.0),
        CGColor(red: 0.00, green: 0.20, blue: 0.60, alpha: 1.0),
    ] as CFArray
    guard let gradient = CGGradient(
        colorsSpace: colorSpace,
        colors: colors,
        locations: [0.0, 0.55, 1.0]
    ) else { return }

    context.saveGState()
    context.addEllipse(in: circleRect)
    context.clip()
    // Glanzpunkt leicht nach oben versetzt (in CG zeigt y nach oben).
    let highlight = CGPoint(x: center.x - radius * 0.18, y: center.y + radius * 0.22)
    context.drawRadialGradient(
        gradient,
        startCenter: highlight,
        startRadius: 0,
        endCenter: center,
        endRadius: radius,
        options: [.drawsAfterEndLocation]
    )
    context.restoreGState()

    guard let image = context.makeImage(),
          let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)
    else { return }
    CGImageDestinationAddImage(destination, image, nil)
    CGImageDestinationFinalize(destination)
}

// (Dateiname, Pixelgroesse) gemaess Apple-.iconset-Konvention.
let variants: [(String, Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]

for (name, pixels) in variants {
    renderIcon(pixelSize: pixels, to: outputDir.appendingPathComponent(name))
}

print("Icon erzeugt in \(outputDir.path)")
