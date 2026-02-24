import AppKit

let outputDir: String
let variant: String
if CommandLine.arguments.count > 1 {
    outputDir = CommandLine.arguments[1]
} else {
    outputDir = FileManager.default.currentDirectoryPath
}
if CommandLine.arguments.count > 2 {
    variant = CommandLine.arguments[2]
} else {
    variant = "v1"
}

let fm = FileManager.default
try fm.createDirectory(atPath: outputDir, withIntermediateDirectories: true)

func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1.0) -> NSColor {
    NSColor(calibratedRed: r / 255.0, green: g / 255.0, blue: b / 255.0, alpha: a)
}

func makeBaseIconV1(size: CGFloat = 1024) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()

    let rect = NSRect(x: 0, y: 0, width: size, height: size)

    let bgPath = NSBezierPath(roundedRect: rect, xRadius: size * 0.22, yRadius: size * 0.22)
    let bgGradient = NSGradient(colors: [
        color(18, 23, 37),
        color(29, 44, 74),
        color(43, 84, 160)
    ])!
    bgGradient.draw(in: bgPath, angle: 320)

    let glowPath = NSBezierPath(ovalIn: NSRect(x: size * 0.1, y: size * 0.55, width: size * 0.9, height: size * 0.6))
    color(143, 203, 255, 0.22).setFill()
    glowPath.fill()

    let plateRect = NSRect(x: size * 0.17, y: size * 0.18, width: size * 0.66, height: size * 0.58)
    let platePath = NSBezierPath(roundedRect: plateRect, xRadius: size * 0.12, yRadius: size * 0.12)
    let plateGradient = NSGradient(colors: [
        color(238, 245, 255, 0.97),
        color(206, 224, 246, 0.95)
    ])!
    plateGradient.draw(in: platePath, angle: 270)

    color(255, 255, 255, 0.7).setStroke()
    platePath.lineWidth = size * 0.006
    platePath.stroke()

    let tabRect = NSRect(x: size * 0.28, y: size * 0.67, width: size * 0.26, height: size * 0.12)
    let tabPath = NSBezierPath(roundedRect: tabRect, xRadius: size * 0.05, yRadius: size * 0.05)
    color(227, 237, 250, 0.98).setFill()
    tabPath.fill()

    let pauseLeft = NSBezierPath(roundedRect: NSRect(x: size * 0.42, y: size * 0.39, width: size * 0.055, height: size * 0.22), xRadius: size * 0.02, yRadius: size * 0.02)
    let pauseRight = NSBezierPath(roundedRect: NSRect(x: size * 0.53, y: size * 0.39, width: size * 0.055, height: size * 0.22), xRadius: size * 0.02, yRadius: size * 0.02)
    color(70, 103, 170, 0.9).setFill()
    pauseLeft.fill()
    pauseRight.fill()

    let ringPath = NSBezierPath(ovalIn: NSRect(x: size * 0.37, y: size * 0.34, width: size * 0.28, height: size * 0.33))
    color(88, 126, 196, 0.28).setStroke()
    ringPath.lineWidth = size * 0.012
    ringPath.stroke()

    image.unlockFocus()
    return image
}

func makeBaseIconV2(size: CGFloat = 1024) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()

    let rect = NSRect(x: 0, y: 0, width: size, height: size)

    let bg = NSBezierPath(roundedRect: rect, xRadius: size * 0.22, yRadius: size * 0.22)
    let gradient = NSGradient(colors: [
        color(232, 244, 255),
        color(186, 215, 249),
        color(132, 175, 236)
    ])!
    gradient.draw(in: bg, angle: 310)

    let accent = NSBezierPath(ovalIn: NSRect(x: size * -0.05, y: size * 0.62, width: size * 0.85, height: size * 0.38))
    color(255, 255, 255, 0.45).setFill()
    accent.fill()

    let folderRect = NSRect(x: size * 0.2, y: size * 0.2, width: size * 0.6, height: size * 0.54)
    let folder = NSBezierPath(roundedRect: folderRect, xRadius: size * 0.11, yRadius: size * 0.11)
    color(248, 252, 255, 0.94).setFill()
    folder.fill()
    color(91, 132, 193, 0.22).setStroke()
    folder.lineWidth = size * 0.008
    folder.stroke()

    let tabRect = NSRect(x: size * 0.31, y: size * 0.67, width: size * 0.22, height: size * 0.09)
    let tab = NSBezierPath(roundedRect: tabRect, xRadius: size * 0.04, yRadius: size * 0.04)
    color(242, 248, 255, 0.98).setFill()
    tab.fill()

    let idleRing = NSBezierPath(ovalIn: NSRect(x: size * 0.39, y: size * 0.37, width: size * 0.22, height: size * 0.25))
    color(74, 125, 197, 0.35).setStroke()
    idleRing.lineWidth = size * 0.012
    idleRing.stroke()

    let idleDot = NSBezierPath(ovalIn: NSRect(x: size * 0.475, y: size * 0.455, width: size * 0.05, height: size * 0.05))
    color(74, 125, 197, 0.75).setFill()
    idleDot.fill()

    image.unlockFocus()
    return image
}

func writePNG(_ image: NSImage, to path: String, size: Int) throws {
    let canvas = NSImage(size: NSSize(width: size, height: size))
    canvas.lockFocus()
    image.draw(in: NSRect(x: 0, y: 0, width: size, height: size),
               from: NSRect(x: 0, y: 0, width: image.size.width, height: image.size.height),
               operation: .copy,
               fraction: 1.0)
    canvas.unlockFocus()

    guard
        let tiff = canvas.tiffRepresentation,
        let rep = NSBitmapImageRep(data: tiff),
        let pngData = rep.representation(using: .png, properties: [:])
    else {
        throw NSError(domain: "IconGen", code: 1)
    }
    try pngData.write(to: URL(fileURLWithPath: path))
}

let base: NSImage
switch variant {
case "v2":
    base = makeBaseIconV2(size: 1024)
default:
    base = makeBaseIconV1(size: 1024)
}
let sizes = [20, 29, 40, 58, 60, 76, 80, 87, 120, 152, 167, 180, 1024]
for size in sizes {
    let filename = "Icon-\(size).png"
    try writePNG(base, to: (outputDir as NSString).appendingPathComponent(filename), size: size)
}

print("Generated app icon set in: \(outputDir) [\(variant)]")
