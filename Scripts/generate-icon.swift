// Recreates the original line-and-note app icon without external artwork or dependencies.
import AppKit

let root = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? ".")
let folder = root.appendingPathComponent("Lyrx/Assets.xcassets/AppIcon.appiconset")
try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

@MainActor func drawIcon(size: Int, filename: String) throws {
    guard
        let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
            isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
        let context = NSGraphicsContext(bitmapImageRep: bitmap)
    else { fatalError("Cannot allocate icon image") }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    let scale = CGFloat(size) / 1024
    context.cgContext.scaleBy(x: scale, y: scale)
    NSColor(srgbRed: 0.10, green: 0.25, blue: 0.58, alpha: 1).setFill()
    NSBezierPath(rect: NSRect(x: 0, y: 0, width: 1024, height: 1024)).fill()
    NSColor.white.setFill()
    // Three readable lines and a musical note make the purpose recognizable at small sizes.
    for (y, width) in [(650.0, 390.0), (480.0, 310.0), (310.0, 470.0)] {
        NSBezierPath(roundedRect: NSRect(x: 170, y: y, width: width, height: 56), xRadius: 28, yRadius: 28).fill()
    }
    NSBezierPath(roundedRect: NSRect(x: 730, y: 455, width: 50, height: 290), xRadius: 20, yRadius: 20).fill()
    NSBezierPath(ovalIn: NSRect(x: 626, y: 405, width: 154, height: 104)).fill()
    let flag = NSBezierPath()
    flag.move(to: NSPoint(x: 750, y: 744))
    flag.curve(
        to: NSPoint(x: 850, y: 607), controlPoint1: NSPoint(x: 875, y: 730), controlPoint2: NSPoint(x: 890, y: 665))
    flag.line(to: NSPoint(x: 824, y: 612))
    flag.curve(
        to: NSPoint(x: 750, y: 680), controlPoint1: NSPoint(x: 840, y: 656), controlPoint2: NSPoint(x: 800, y: 678))
    flag.close()
    flag.fill()
    NSGraphicsContext.restoreGraphicsState()
    guard let data = bitmap.representation(using: .png, properties: [:]) else { fatalError("Cannot encode icon") }
    try data.write(to: folder.appendingPathComponent(filename))
}

var images: [[String: String]] = []
for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let filename = "mac-\(points)@\(scale)x.png"
        try drawIcon(size: points * scale, filename: filename)
        images.append(["idiom": "mac", "size": "\(points)x\(points)", "scale": "\(scale)x", "filename": filename])
    }
}
try drawIcon(size: 1024, filename: "ios-1024.png")
images.append(["idiom": "universal", "platform": "ios", "size": "1024x1024", "filename": "ios-1024.png"])
let json: [String: Any] = ["images": images, "info": ["author": "Lyrx", "version": 1]]
try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]).write(
    to: folder.appendingPathComponent("Contents.json"))
