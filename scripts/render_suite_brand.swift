import AppKit
import Foundation

/// Composites Snap viewfinder frame (density B, no coral) + Kadr NeonIris (~50%)
/// into suite App Icon + Menu Bar template assets.
enum SuiteBrandRenderer {
    static let canvas: CGFloat = 1024
    static let irisScale: CGFloat = 0.50
    /// Zoom NeonIris inside the circular crop so Kadr squircle/border is clipped away.
    static let neonZoom: CGFloat = 1.22
    static let frameInsetFraction: CGFloat = 0.195
    static let frameCornerFraction: CGFloat = 0.085
    static let frameLineFraction: CGFloat = 0.022
    static let gapFraction: CGFloat = 0.055

    static let iconsetSizes: [(name: String, pixels: Int)] = [
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

    static func main() {
        do {
            try render()
            fputs("OK: suite brand assets written to Resources/\n", stderr)
        } catch {
            fputs("error: \(error)\n", stderr)
            exit(1)
        }
    }

    static func render() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let resources = root.appendingPathComponent("Resources")
        let neonURL = resources.appendingPathComponent("Brand/NeonIris.png")
        guard let neon = NSImage(contentsOf: neonURL) else {
            throw RenderError.missingNeonIris(neonURL.path)
        }

        let fm = FileManager.default
        try fm.createDirectory(at: resources, withIntermediateDirectories: true)
        let iconset = resources.appendingPathComponent("AppIcon.iconset", isDirectory: true)
        try fm.createDirectory(at: iconset, withIntermediateDirectories: true)

        try writePNG(renderMaster(neon: neon, pixels: Int(canvas), mode: .color), to: resources.appendingPathComponent("AppIcon.png"))

        for icon in iconsetSizes {
            try writePNG(
                renderMaster(neon: neon, pixels: icon.pixels, mode: .color),
                to: iconset.appendingPathComponent(icon.name)
            )
        }
        try runIconutil(iconset: iconset, output: resources.appendingPathComponent("AppIcon.icns"))

        try writePNG(renderMaster(neon: neon, pixels: 18, mode: .template), to: resources.appendingPathComponent("MenuBarIcon.png"))
        try writePNG(renderMaster(neon: neon, pixels: 36, mode: .template), to: resources.appendingPathComponent("MenuBarIcon@2x.png"))
    }

    enum Mode { case color, template }

    static func renderMaster(neon: NSImage, pixels: Int, mode: Mode) -> NSBitmapImageRep {
        let size = CGFloat(pixels)
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixels,
            pixelsHigh: pixels,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )!
        rep.size = NSSize(width: size, height: size)

        NSGraphicsContext.saveGraphicsState()
        let ctx = NSGraphicsContext(bitmapImageRep: rep)!
        NSGraphicsContext.current = ctx
        ctx.imageInterpolation = .high
        ctx.shouldAntialias = true

        let bounds = NSRect(x: 0, y: 0, width: size, height: size)
        NSColor.clear.setFill()
        bounds.fill()

        switch mode {
        case .color:
            drawDockBackground(in: bounds)
            drawIrisPhoto(neon: neon, in: bounds)
            drawSnapFrame(in: bounds, color: NSColor(calibratedWhite: 0.965, alpha: 1))
        case .template:
            drawIrisTemplate(in: bounds)
            drawSnapFrame(in: bounds, color: .black)
        }

        NSGraphicsContext.restoreGraphicsState()
        return rep
    }

    static func drawDockBackground(in bounds: NSRect) {
        NSGraphicsContext.saveGraphicsState()
        let path = NSBezierPath(roundedRect: bounds, xRadius: bounds.width * 0.223, yRadius: bounds.height * 0.223)
        path.addClip()
        let colors = [
            NSColor(calibratedRed: 0.11, green: 0.11, blue: 0.125, alpha: 1),
            NSColor(calibratedRed: 0.02, green: 0.02, blue: 0.025, alpha: 1),
        ]
        if let gradient = NSGradient(colors: colors) {
            gradient.draw(in: bounds, relativeCenterPosition: NSPoint(x: 0, y: 0.08))
        } else {
            colors[1].setFill()
            bounds.fill()
        }
        NSGraphicsContext.restoreGraphicsState()
    }

    static func drawIrisPhoto(neon: NSImage, in bounds: NSRect) {
        let side = bounds.width * irisScale
        let irisRect = NSRect(
            x: bounds.midX - side / 2,
            y: bounds.midY - side / 2,
            width: side,
            height: side
        )
        let zoomedSide = side * neonZoom
        let drawRect = NSRect(
            x: bounds.midX - zoomedSide / 2,
            y: bounds.midY - zoomedSide / 2,
            width: zoomedSide,
            height: zoomedSide
        )

        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(ovalIn: irisRect).addClip()
        neon.draw(in: drawRect, from: .zero, operation: .sourceOver, fraction: 1)
        NSGraphicsContext.restoreGraphicsState()
    }

    /// Black silhouette: outer iris ring + inner aperture hole, readable at 18pt.
    static func drawIrisTemplate(in bounds: NSRect) {
        let side = bounds.width * irisScale
        let irisRect = NSRect(
            x: bounds.midX - side / 2,
            y: bounds.midY - side / 2,
            width: side,
            height: side
        )
        let outer = NSBezierPath(ovalIn: irisRect)
        let holeInset = side * 0.28
        let hole = NSBezierPath(ovalIn: irisRect.insetBy(dx: holeInset, dy: holeInset))
        outer.append(hole)
        outer.windingRule = .evenOdd
        NSColor.black.setFill()
        outer.fill()

        // Six petal hints (short arcs) so it doesn't read as a plain donut
        let cx = bounds.midX
        let cy = bounds.midY
        let r = side * 0.38
        for i in 0..<6 {
            let a0 = CGFloat(i) * (.pi / 3) - .pi / 2
            let a1 = a0 + .pi / 8
            let p = NSBezierPath()
            p.lineWidth = max(1.0, side * 0.08)
            p.lineCapStyle = .round
            p.move(to: NSPoint(x: cx + cos(a0) * r, y: cy + sin(a0) * r))
            p.line(to: NSPoint(x: cx + cos(a1) * r * 0.72, y: cy + sin(a1) * r * 0.72))
            NSColor.black.setStroke()
            p.stroke()
        }
    }

    static func drawSnapFrame(in bounds: NSRect, color: NSColor) {
        let s = bounds.width
        let inset = s * frameInsetFraction
        let corner = s * frameCornerFraction
        let line = max(1.0, s * frameLineFraction)
        let gap = s * gapFraction

        let outer = bounds.insetBy(dx: inset, dy: inset)
        let x0 = outer.minX
        let x1 = outer.maxX
        let y0 = outer.minY
        let y1 = outer.maxY
        let midX = outer.midX
        let midY = outer.midY

        color.setStroke()

        func stroke(_ build: (NSBezierPath) -> Void) {
            let p = NSBezierPath()
            p.lineWidth = line
            p.lineCapStyle = .round
            p.lineJoinStyle = .round
            build(p)
            p.stroke()
        }

        stroke { p in
            p.move(to: NSPoint(x: x0 + corner, y: y1))
            p.line(to: NSPoint(x: midX - gap, y: y1))
        }
        stroke { p in
            p.move(to: NSPoint(x: midX + gap, y: y1))
            p.line(to: NSPoint(x: x1 - corner, y: y1))
        }
        stroke { p in
            p.move(to: NSPoint(x: x0 + corner, y: y0))
            p.line(to: NSPoint(x: midX - gap, y: y0))
        }
        stroke { p in
            p.move(to: NSPoint(x: midX + gap, y: y0))
            p.line(to: NSPoint(x: x1 - corner, y: y0))
        }
        stroke { p in
            p.move(to: NSPoint(x: x0, y: y0 + corner))
            p.line(to: NSPoint(x: x0, y: midY - gap))
        }
        stroke { p in
            p.move(to: NSPoint(x: x0, y: midY + gap))
            p.line(to: NSPoint(x: x0, y: y1 - corner))
        }
        stroke { p in
            p.move(to: NSPoint(x: x1, y: y0 + corner))
            p.line(to: NSPoint(x: x1, y: midY - gap))
        }
        stroke { p in
            p.move(to: NSPoint(x: x1, y: midY + gap))
            p.line(to: NSPoint(x: x1, y: y1 - corner))
        }
        stroke { p in
            p.appendArc(withCenter: NSPoint(x: x0 + corner, y: y1 - corner), radius: corner, startAngle: 90, endAngle: 180)
        }
        stroke { p in
            p.appendArc(withCenter: NSPoint(x: x1 - corner, y: y1 - corner), radius: corner, startAngle: 0, endAngle: 90)
        }
        stroke { p in
            p.appendArc(withCenter: NSPoint(x: x0 + corner, y: y0 + corner), radius: corner, startAngle: 180, endAngle: 270)
        }
        stroke { p in
            p.appendArc(withCenter: NSPoint(x: x1 - corner, y: y0 + corner), radius: corner, startAngle: 270, endAngle: 360)
        }
    }

    static func writePNG(_ rep: NSBitmapImageRep, to url: URL) throws {
        guard let data = rep.representation(using: .png, properties: [:]) else {
            throw RenderError.pngEncodingFailed(url.path)
        }
        try data.write(to: url, options: .atomic)
    }

    static func runIconutil(iconset: URL, output: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
        process.arguments = ["-c", "icns", iconset.path, "-o", output.path]
        try process.run()
        process.waitUntilExit()
        if process.terminationStatus != 0 {
            throw RenderError.iconutilFailed(process.terminationStatus)
        }
    }

    enum RenderError: Error, CustomStringConvertible {
        case missingNeonIris(String)
        case pngEncodingFailed(String)
        case iconutilFailed(Int32)

        var description: String {
            switch self {
            case .missingNeonIris(let path): return "Missing NeonIris at \(path)"
            case .pngEncodingFailed(let path): return "PNG encode failed: \(path)"
            case .iconutilFailed(let s): return "iconutil failed (\(s))"
            }
        }
    }
}

SuiteBrandRenderer.main()
