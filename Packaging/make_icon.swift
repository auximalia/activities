import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

// Erzeugt das App-Icon in allen fuer ein macOS-.iconset benoetigten Groessen.
//
// Motiv: ein blauer **Ordner**, davor ein **Zifferblatt** – „Ordner" und
// „zuletzt" in einem Bild. Der fruehere blaue Kreis war ein Platzhalter und
// transportierte den Zweck der App nicht.
//
// Gestaltungsregeln (macOS ab Big Sur):
// - abgerundetes Quadrat, Inhalt auf rund 82 % der Flaeche (Rest ist Luft),
// - traegt bis hinunter zu 16 px – deshalb wenige, grosse Formen,
// - funktioniert auf hellem wie dunklem Dock (heller Grund, kraeftiges Blau).
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

    // --- Grundflaeche: abgerundetes Quadrat auf ~82 % der Kantenlaenge ---
    let inset = size * 0.09
    let plate = CGRect(x: inset, y: inset, width: size - 2 * inset, height: size - 2 * inset)
    let plateRadius = plate.width * 0.2237   // Apples "Squircle"-Naeherung
    let platePath = CGPath(
        roundedRect: plate, cornerWidth: plateRadius, cornerHeight: plateRadius, transform: nil
    )

    // Heller Grund: das Motiv traegt die Farbe, nicht der Hintergrund. So bleibt
    // das Icon auf dunklem wie hellem Dock erkennbar.
    guard let plateGradient = CGGradient(
        colorsSpace: colorSpace,
        colors: [
            CGColor(red: 1.00, green: 1.00, blue: 1.00, alpha: 1.0),
            CGColor(red: 0.90, green: 0.93, blue: 0.97, alpha: 1.0),
        ] as CFArray,
        locations: [0.0, 1.0]
    ) else { return }

    context.saveGState()
    context.addPath(platePath)
    context.clip()
    context.drawLinearGradient(
        plateGradient,
        start: CGPoint(x: plate.minX, y: plate.maxY),
        end: CGPoint(x: plate.maxX, y: plate.minY),
        options: []
    )
    context.restoreGState()

    // --- Ordner ---
    let blue = CGColor(red: 0.09, green: 0.45, blue: 0.92, alpha: 1.0)
    let blueDark = CGColor(red: 0.05, green: 0.33, blue: 0.75, alpha: 1.0)

    let fw = plate.width * 0.62                    // Ordnerbreite
    let fh = fw * 0.74                             // Ordnerhoehe
    let fx = plate.minX + plate.width * 0.13
    let fy = plate.minY + plate.height * 0.24
    let corner = fw * 0.10

    // Rueckenlasche (oben), etwas schmaler als der Koerper.
    let tabWidth = fw * 0.42
    let tabHeight = fh * 0.16
    let tab = CGRect(x: fx, y: fy + fh - tabHeight * 0.4, width: tabWidth, height: tabHeight)
    context.setFillColor(blueDark)
    context.addPath(CGPath(roundedRect: tab, cornerWidth: corner * 0.6, cornerHeight: corner * 0.6, transform: nil))
    context.fillPath()

    // Ordnerkoerper.
    let body = CGRect(x: fx, y: fy, width: fw, height: fh)
    context.setFillColor(blue)
    context.addPath(CGPath(roundedRect: body, cornerWidth: corner, cornerHeight: corner, transform: nil))
    context.fillPath()

    // --- Zifferblatt, rechts unten ueberlappend ---
    let dialDiameter = plate.width * 0.46
    let dialRect = CGRect(
        x: plate.maxX - plate.width * 0.11 - dialDiameter,
        y: plate.minY + plate.height * 0.10,
        width: dialDiameter,
        height: dialDiameter
    )
    let dialCenter = CGPoint(x: dialRect.midX, y: dialRect.midY)
    let dialRadius = dialDiameter / 2

    // Heller Ring als Abstand zum Ordner – sonst verschmelzen beide Formen.
    context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
    context.fillEllipse(in: dialRect.insetBy(dx: -dialDiameter * 0.07, dy: -dialDiameter * 0.07))

    context.setFillColor(blueDark)
    context.fillEllipse(in: dialRect)
    context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
    context.fillEllipse(in: dialRect.insetBy(dx: dialDiameter * 0.11, dy: dialDiameter * 0.11))

    // Zeiger: 10 Uhr / 2 Uhr waere unruhig – klassisch nach oben und rechts.
    context.setStrokeColor(blueDark)
    context.setLineCap(.round)
    context.setLineWidth(max(1, dialRadius * 0.17))
    context.move(to: dialCenter)
    context.addLine(to: CGPoint(x: dialCenter.x, y: dialCenter.y + dialRadius * 0.52))
    context.strokePath()
    context.setLineWidth(max(1, dialRadius * 0.15))
    context.move(to: dialCenter)
    context.addLine(to: CGPoint(x: dialCenter.x + dialRadius * 0.40, y: dialCenter.y))
    context.strokePath()

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
