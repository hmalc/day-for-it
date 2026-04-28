import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let outputDirectory = URL(fileURLWithPath: "dayforitApp/Resources/Assets.xcassets/AppIcon.appiconset", isDirectory: true)

let icons: [(filename: String, pixels: Int)] = [
    ("Icon-20@2x.png", 40),
    ("Icon-20@3x.png", 60),
    ("Icon-29@2x.png", 58),
    ("Icon-29@3x.png", 87),
    ("Icon-40@2x.png", 80),
    ("Icon-40@3x.png", 120),
    ("Icon-60@2x.png", 120),
    ("Icon-60@3x.png", 180),
    ("Icon-1024.png", 1024),
]

func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(red: red, green: green, blue: blue, alpha: alpha)
}

func strokeLine(
    in context: CGContext,
    from start: CGPoint,
    to end: CGPoint,
    width: CGFloat,
    color lineColor: CGColor
) {
    context.setStrokeColor(lineColor)
    context.setLineWidth(width)
    context.setLineCap(.round)
    context.move(to: start)
    context.addLine(to: end)
    context.strokePath()
}

func drawIcon(pixels: Int) -> CGImage {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bitmapInfo = CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.noneSkipLast.rawValue
    guard let context = CGContext(
        data: nil,
        width: pixels,
        height: pixels,
        bitsPerComponent: 8,
        bytesPerRow: pixels * 4,
        space: colorSpace,
        bitmapInfo: bitmapInfo
    ) else {
        fatalError("Could not create CGContext")
    }

    let size = CGFloat(pixels)
    let bounds = CGRect(x: 0, y: 0, width: size, height: size)
    let horizonY = size * 0.43

    let sky = CGGradient(
        colorsSpace: colorSpace,
        colors: [
            color(0.22, 0.72, 0.88),
            color(0.54, 0.87, 0.94),
        ] as CFArray,
        locations: [0.0, 1.0]
    )!
    context.drawLinearGradient(
        sky,
        start: CGPoint(x: bounds.midX, y: horizonY),
        end: CGPoint(x: bounds.midX, y: bounds.maxY),
        options: []
    )

    context.setFillColor(color(0.10, 0.66, 0.79))
    context.fill(CGRect(x: bounds.minX, y: bounds.minY, width: size, height: horizonY))

    let sunRadius = size * 0.118
    let sunCenter = CGPoint(x: size * 0.50, y: horizonY)
    context.setFillColor(color(1.0, 0.86, 0.50))
    context.move(to: CGPoint(x: sunCenter.x + sunRadius, y: horizonY))
    context.addArc(center: sunCenter, radius: sunRadius, startAngle: 0, endAngle: .pi, clockwise: false)
    context.closePath()
    context.fillPath()

    strokeLine(
        in: context,
        from: CGPoint(x: bounds.minX, y: horizonY),
        to: CGPoint(x: bounds.maxX, y: horizonY),
        width: max(1, size * 0.007),
        color: color(0.96, 1.00, 1.00, 0.86)
    )

    guard let image = context.makeImage() else {
        fatalError("Could not create icon image")
    }
    return image
}

func savePNG(_ image: CGImage, to url: URL) {
    guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        fatalError("Could not create destination for \(url.path)")
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        fatalError("Could not write \(url.path)")
    }
}

try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
for icon in icons {
    let image = drawIcon(pixels: icon.pixels)
    savePNG(image, to: outputDirectory.appendingPathComponent(icon.filename))
}
