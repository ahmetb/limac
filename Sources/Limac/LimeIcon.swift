import AppKit

/// The lime-wedge menu bar icon, drawn as template images so macOS handles
/// light/dark tinting.
///
/// Geometry and state model come from Resources/lime-noto-full.svg — a
/// monochrome conversion of the Noto Emoji lime (U+1F34B ZWJ U+1F7E9),
/// bundled as the design source of truth — but AppKit has no public SVG
/// decoder, so the same path data is parsed into CGPaths here. Each of the
/// four flesh segments is lit (opacity 1) or off (0.24); the busy "wave"
/// reproduces the 16-step table documented in lime-noto-animated.svg.
/// Transparency tiers were tuned in Resources/lime-noto-assets.html.
enum LimeIcon {
    static let full = image(lit: [1, 2, 3, 4], description: "Limac: a VM is running")
    static let empty = image(lit: [], description: "Limac: no VMs running")

    /// Hold time per wave step: ~3.4× the speed documented in
    /// lime-noto-animated.svg (420 ms), so the 16-step loop takes ~2 s.
    static let frameInterval: TimeInterval = 0.125

    /// Lit segments per wave step, from lime-noto-animated.svg's step table.
    static let frames: [NSImage] = [
        [], [1], [1, 2], [1, 2, 3], [1, 2, 3, 4], [2, 3, 4], [3, 4], [4],
        [], [4], [3, 4], [2, 3, 4], [1, 2, 3, 4], [1, 2, 3], [1, 2], [1],
    ].map { image(lit: $0, description: "Limac: an operation is in progress") }

    // Everything below is in the SVG's 128×128 viewBox coordinates (y down).

    /// Alpha tiers from the SVG's color mapping (the rind is opaque).
    /// At these values the cut face, juice streaks and pores vanish; the
    /// wedge reads as a solid rind plus four solid segments.
    private static let fleshAlpha: CGFloat = 1
    private static let pithAlpha: CGFloat = 0
    private static let offOpacity: CGFloat = 0.24

    // Path data lifted verbatim from lime-noto-full.svg. Segment fan order
    // (p1 at the cut's upper-left corner → p4 at its pointed right corner)
    // matches the SVG's state API; paint order doesn't matter, the shapes
    // are disjoint.
    private static let silhouetteData = "M22.5,14.8c2.9,1.3,99,44,99,44c2.7,1.2,2.9,3.1,2,12.4c-1,10.5-1.9,37.8-40.2,42.9c-24.6,3.2-55.9-4.3-70.9-27.2C-6,58.8,11,23.4,14.8,17.7C17.2,14.2,19.6,13.5,22.5,14.8z"
    private static let cutFaceData = "M121.5,58.8c-0.3-0.2-92-40.8-98.9-43.9C9.6,31.5-3.8,76,27.9,96.2C61.5,117.7,106.6,86,121.5,58.8z"

    /// One flesh segment: its fill path and, for p2…p4, the juice streak
    /// that dims with it.
    private struct Segment {
        let flesh: CGPath
        let streak: CGPath?
    }

    private static let segments: [Segment] = [
        Segment( // p1
            flesh: path("M57.6,30.3c-8.3-3.7-24.4-10.7-29.6-13c-3.6,2.2-9.7,11.4-11.2,21.2c-0.6,3.6,1.7,5.9,5.3,4.9c0,0,33.7-9.3,35.3-9.7C59,33.2,59.4,31.1,57.6,30.3z"),
            streak: nil),
        Segment( // p2
            flesh: path("M56.2,37.6L19.5,48.2c-2.5,0.8-4.4,2.8-5,5.3c-1.9,8.5,0.8,23.3,8.9,29.8c3.5,2.7,8.6,1.8,10.8-2.1L58.5,41C59.8,39.3,59,36.8,56.2,37.6z"),
            streak: path("M52.2,42.2c-1.4,0.4-10.1,3-11.1,3.4c-1.4,0.5-2.2,1.7-1.9,2.5c0.3,0.9,1.7,1.1,3.1,0.6c0.8-0.3,7.1-3.9,9.5-5.2c-3.1,2.4-10.2,9.4-11.1,10.3c-1.4,1.5-1.7,3.4-0.8,4.3c1,0.9,2.9,0.5,4.3-1c1.2-1.3,8.5-12.8,9.1-13.9S53.7,41.8,52.2,42.2z")),
        Segment( // p3
            flesh: path("M61.9,42.4C60.3,45.1,39.5,81,37.6,84.1c-1.9,3.2-0.7,7.5,2.7,9.2c12.3,6.5,30.9,0.4,39.6-7c2.2-1.9,4.5-5.1,3.2-8.2S68.9,44.6,67.8,42.3C66.6,39.6,63.7,39.5,61.9,42.4z"),
            streak: path("M62.3,58.6c0-2.2,1.4-10.3,1.8-12.3c0.4-1.6,1.5-1.8,1.8,0.5s1.7,9.7,1.7,11.8s-1.2,3.3-2.7,3.3C63.5,61.9,62.3,60.8,62.3,58.6z")),
        Segment( // p4
            flesh: path("M70.5,40.5c0,0,14.6,30.1,16,33s6.3,4.7,9.9,2.8c10.7-5.6,15.5-12.4,19.2-20.2c-8.9-3.9-42.4-18.8-42.4-18.8C70.8,36.2,69.2,37.9,70.5,40.5z"),
            streak: path("M79.9,49c-1.2-1.8-3.3-4.9-4.1-6.1c-0.7-1.2,0.1-2.1,1.8-0.9c1.7,1.2,4,2.9,5.4,4c1.6,1.3,1.9,3,0.8,4S81.1,50.8,79.9,49z")),
    ]

    /// The three rind pores: rotated ellipses. (The SVG bakes the same
    /// rotations into arc segments; here they stay ellipses.)
    private static let porePaths: [CGPath] = [
        (center: CGPoint(x: 87.3, y: 103.12), degrees: -27.08),
        (center: CGPoint(x: 98.89, y: 103.82), degrees: -30.65),
        (center: CGPoint(x: 102.02, y: 93.8), degrees: -37.16),
    ].map { pore in
        var transform = CGAffineTransform(translationX: pore.center.x, y: pore.center.y)
            .rotated(by: pore.degrees * .pi / 180)
        return CGPath(ellipseIn: CGRect(x: -3.4, y: -2.3, width: 6.8, height: 4.6),
                      transform: &transform)
    }

    private static let cutFacePath = path(cutFaceData)

    /// Rind: the silhouette with the cut face and pores punched out
    /// (even-odd), so every tier keeps its real transparency instead of
    /// stacking translucent paint over opaque black.
    private static let rindPath: CGPath = {
        let rind = CGMutablePath()
        rind.addPath(path(silhouetteData))
        rind.addPath(cutFacePath)
        for pore in porePaths { rind.addPath(pore) }
        return rind
    }()

    private static func image(lit: Set<Int>, description: String) -> NSImage {
        // flipped: true gives a top-left origin, matching SVG coordinates.
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: true) { rect in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            // Scale the 128-unit viewBox as if it sat in a 140 box, centered:
            // the wedge's ~120-unit width then lands at ~15.4 pt, the same
            // footprint the previous 24-box icon had.
            let scale = rect.width / 140
            ctx.translateBy(x: rect.width / 2, y: rect.height / 2)
            ctx.scaleBy(x: scale, y: scale)
            ctx.translateBy(x: -64, y: -64)

            ctx.setFillColor(.black)
            ctx.addPath(rindPath)
            ctx.fillPath(using: .evenOdd)

            ctx.setFillColor(CGColor(gray: 0, alpha: pithAlpha))
            ctx.addPath(cutFacePath)
            ctx.fillPath()

            ctx.setFillColor(CGColor(gray: 0, alpha: fleshAlpha))
            for pore in porePaths { ctx.addPath(pore) }
            ctx.fillPath()

            // Flesh: a segment and its juice streak dim as one group, like
            // the SVG's per-segment <g opacity>. The transparency layer
            // applies the segment's opacity to both fills at once.
            for (index, segment) in segments.enumerated() {
                ctx.setAlpha(lit.contains(index + 1) ? 1 : offOpacity)
                ctx.beginTransparencyLayer(auxiliaryInfo: nil)
                ctx.setFillColor(CGColor(gray: 0, alpha: fleshAlpha))
                ctx.addPath(segment.flesh)
                ctx.fillPath()
                if let streak = segment.streak {
                    ctx.setFillColor(CGColor(gray: 0, alpha: pithAlpha))
                    ctx.addPath(streak)
                    ctx.fillPath()
                }
                ctx.endTransparencyLayer()
            }
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = description
        return image
    }

    /// Parses the subset of SVG path syntax the lime-noto assets use:
    /// M/L/C/S commands (absolute or relative) and Z.
    private static func path(_ data: String) -> CGPath {
        let path = CGMutablePath()
        let chars = Array(data)
        var i = 0
        var command: Character = " "
        var current = CGPoint.zero
        var subpathStart = CGPoint.zero
        var lastCubicControl: CGPoint?

        func skipSeparators() {
            while i < chars.count, chars[i] == "," || chars[i] == " " { i += 1 }
        }
        func number() -> CGFloat {
            skipSeparators()
            let start = i
            if i < chars.count, chars[i] == "-" || chars[i] == "+" { i += 1 }
            var seenDot = false
            while i < chars.count, chars[i].isNumber || (chars[i] == "." && !seenDot) {
                if chars[i] == "." { seenDot = true }
                i += 1
            }
            return CGFloat(Double(String(chars[start..<i]))!)
        }
        // For relative commands every pair is offset from where the
        // command started, so the origin is fixed before reading points.
        func point(relativeTo origin: CGPoint?) -> CGPoint {
            let x = number(), y = number()
            guard let origin else { return CGPoint(x: x, y: y) }
            return CGPoint(x: origin.x + x, y: origin.y + y)
        }

        while i < chars.count {
            skipSeparators()
            guard i < chars.count else { break }
            if chars[i].isLetter {
                command = chars[i]
                i += 1
            } // else: another coordinate group for the previous command
            let origin: CGPoint? = command.isLowercase ? current : nil
            switch command {
            case "M", "m":
                current = point(relativeTo: origin)
                path.move(to: current)
                subpathStart = current
                lastCubicControl = nil
                command = command == "M" ? "L" : "l"
            case "L", "l":
                current = point(relativeTo: origin)
                path.addLine(to: current)
                lastCubicControl = nil
            case "C", "c":
                let control1 = point(relativeTo: origin)
                let control2 = point(relativeTo: origin)
                let end = point(relativeTo: origin)
                path.addCurve(to: end, control1: control1, control2: control2)
                lastCubicControl = control2
                current = end
            case "S", "s":
                // Smooth cubic: first control mirrors the previous one.
                let control1 = lastCubicControl.map {
                    CGPoint(x: 2 * current.x - $0.x, y: 2 * current.y - $0.y)
                } ?? current
                let control2 = point(relativeTo: origin)
                let end = point(relativeTo: origin)
                path.addCurve(to: end, control1: control1, control2: control2)
                lastCubicControl = control2
                current = end
            case "Z", "z":
                path.closeSubpath()
                current = subpathStart
                lastCubicControl = nil
            default:
                assertionFailure("unsupported SVG path command: \(command)")
                return path
            }
        }
        return path
    }
}
