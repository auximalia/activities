import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

// Erzeugt einen Xcode-App-Icon-Satz (AppIcon.appiconset) mit dem blauen LED-Kreis.
//
// Aufruf: swift make_appiconset.swift <ziel-appiconset-verzeichnis>

guard CommandLine.arguments.count >= 2 else {
    FileHandle.standardError.write(Data("Aufruf: swift make_appiconset.swift <appiconset-dir>\n".utf8))
    exit(2)
}

let outputDir = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try? FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

func renderIcon(pixelSize: Int, to url: URL) {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard let context = CGContext(
        data: nil, width: pixelSize, height: pixelSize, bitsPerComponent: 8,
        bytesPerRow: 0, space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return }

    let size = CGFloat(pixelSize)
    context.clear(CGRect(x: 0, y: 0, width: size, height: size))

    let inset = size * 0.12
    let circleRect = CGRect(x: inset, y: inset, width: size - 2 * inset, height: size - 2 * inset)
    let center = CGPoint(x: circleRect.midX, y: circleRect.midY)
    let radius = circleRect.width / 2

    let colors = [
        CGColor(red: 0.55, green: 0.80, blue: 1.00, alpha: 1.0),
        CGColor(red: 0.00, green: 0.40, blue: 0.95, alpha: 1.0),
        CGColor(red: 0.00, green: 0.20, blue: 0.60, alpha: 1.0),
    ] as CFArray
    guard let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0.0, 0.55, 1.0]) else { return }

    context.saveGState()
    context.addEllipse(in: circleRect)
    context.clip()
    let highlight = CGPoint(x: center.x - radius * 0.18, y: center.y + radius * 0.22)
    context.drawRadialGradient(gradient, startCenter: highlight, startRadius: 0, endCenter: center, endRadius: radius, options: [.drawsAfterEndLocation])
    context.restoreGState()

    guard let image = context.makeImage(),
          let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)
    else { return }
    CGImageDestinationAddImage(destination, image, nil)
    CGImageDestinationFinalize(destination)
}

// (Dateiname, Pixelgroesse, idiom-size, scale) fuer macOS.
struct Entry { let file: String; let px: Int; let size: String; let scale: String }
let entries: [Entry] = [
    Entry(file: "icon_16.png", px: 16, size: "16x16", scale: "1x"),
    Entry(file: "icon_32.png", px: 32, size: "16x16", scale: "2x"),
    Entry(file: "icon_32b.png", px: 32, size: "32x32", scale: "1x"),
    Entry(file: "icon_64.png", px: 64, size: "32x32", scale: "2x"),
    Entry(file: "icon_128.png", px: 128, size: "128x128", scale: "1x"),
    Entry(file: "icon_256.png", px: 256, size: "128x128", scale: "2x"),
    Entry(file: "icon_256b.png", px: 256, size: "256x256", scale: "1x"),
    Entry(file: "icon_512.png", px: 512, size: "256x256", scale: "2x"),
    Entry(file: "icon_512b.png", px: 512, size: "512x512", scale: "1x"),
    Entry(file: "icon_1024.png", px: 1024, size: "512x512", scale: "2x"),
]

// Bilder rendern (gleiche Pixelgroesse nur einmal, aber je Eintrag eigene Datei).
for entry in entries {
    renderIcon(pixelSize: entry.px, to: outputDir.appendingPathComponent(entry.file))
}

// Contents.json schreiben.
let images = entries.map { entry in
    "    { \"filename\" : \"\(entry.file)\", \"idiom\" : \"mac\", \"scale\" : \"\(entry.scale)\", \"size\" : \"\(entry.size)\" }"
}.joined(separator: ",\n")

let contents = """
{
  "images" : [
\(images)
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
"""
try? contents.write(to: outputDir.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)

print("AppIcon.appiconset erzeugt in \(outputDir.path)")
