// Generates the app icon PNGs into Assets.xcassets/AppIcon.appiconset.
//
// Checked in so the icon is reproducible rather than a binary nobody can regenerate.
//   xcrun swiftc -O Tools/MakeAppIcon.swift -o /tmp/makeicon && /tmp/makeicon <appiconset-dir>
//
// The mark is a sigma — the summation sign — drawn as a stroked path rather than set in
// a font, so it renders identically everywhere and stays legible down to 16pt.

import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let backgroundTop = CGColor(red: 0.231, green: 0.667, blue: 0.451, alpha: 1)
let backgroundBottom = CGColor(red: 0.078, green: 0.384, blue: 0.290, alpha: 1)

func drawIcon(size: CGFloat, roundedWithMargin: Bool) -> CGImage? {
    let space = CGColorSpaceCreateDeviceRGB()
    guard let context = CGContext(
        data: nil,
        width: Int(size),
        height: Int(size),
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: space,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return nil }

    context.setAllowsAntialiasing(true)
    context.interpolationQuality = .high

    // iOS masks the icon itself, so its artwork is full-bleed and opaque. macOS expects
    // the rounded shape and its surrounding margin baked into the file.
    let plate: CGRect
    let cornerRadius: CGFloat
    if roundedWithMargin {
        let inset = size * 0.094
        plate = CGRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
        cornerRadius = plate.width * 0.225
    } else {
        plate = CGRect(x: 0, y: 0, width: size, height: size)
        cornerRadius = 0
    }

    context.saveGState()
    let path = CGPath(roundedRect: plate, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
    context.addPath(path)
    context.clip()

    if let gradient = CGGradient(colorsSpace: space, colors: [backgroundTop, backgroundBottom] as CFArray, locations: [0, 1]) {
        context.drawLinearGradient(
            gradient,
            start: CGPoint(x: plate.minX, y: plate.maxY),
            end: CGPoint(x: plate.maxX, y: plate.minY),
            options: []
        )
    }
    context.restoreGState()

    // Sigma, as a polyline: top bar, in to the waist, back out, bottom bar.
    let box = plate.insetBy(dx: plate.width * 0.26, dy: plate.height * 0.24)
    let waistX = box.minX + box.width * 0.46
    let waistY = box.midY

    let sigma = CGMutablePath()
    sigma.move(to: CGPoint(x: box.maxX, y: box.maxY))
    sigma.addLine(to: CGPoint(x: box.minX, y: box.maxY))
    sigma.addLine(to: CGPoint(x: waistX, y: waistY))
    sigma.addLine(to: CGPoint(x: box.minX, y: box.minY))
    sigma.addLine(to: CGPoint(x: box.maxX, y: box.minY))

    context.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
    context.setLineWidth(plate.width * 0.086)
    context.setLineCap(.round)
    context.setLineJoin(.round)
    context.addPath(sigma)
    context.strokePath()

    return context.makeImage()
}

func write(_ image: CGImage, to url: URL) throws {
    guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        throw NSError(domain: "MakeAppIcon", code: 1, userInfo: [NSLocalizedDescriptionKey: "could not create \(url.path)"])
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        throw NSError(domain: "MakeAppIcon", code: 2, userInfo: [NSLocalizedDescriptionKey: "could not write \(url.path)"])
    }
}

let arguments = CommandLine.arguments
guard arguments.count == 2 else {
    FileHandle.standardError.write("usage: makeicon <appiconset-directory>\n".data(using: .utf8)!)
    exit(2)
}
let outputDirectory = URL(fileURLWithPath: arguments[1])

var written: [String] = []

if let image = drawIcon(size: 1024, roundedWithMargin: false) {
    let url = outputDirectory.appendingPathComponent("icon-ios-1024.png")
    try write(image, to: url)
    written.append(url.lastPathComponent)
}

for size in [16, 32, 64, 128, 256, 512, 1024] as [CGFloat] {
    if let image = drawIcon(size: size, roundedWithMargin: true) {
        let url = outputDirectory.appendingPathComponent("icon-mac-\(Int(size)).png")
        try write(image, to: url)
        written.append(url.lastPathComponent)
    }
}

print(written.joined(separator: "\n"))
