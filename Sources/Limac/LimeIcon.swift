import AppKit

/// The lime-slice menu bar icon, drawn as template images so macOS handles
/// light/dark tinting.
///
/// Geometry and state model come from Resources/lime-full.svg — bundled as
/// the design source of truth — but AppKit has no public SVG decoder, so the
/// paths are redrawn here in code. Each flesh segment is lit (opacity 1) or
/// off (0.18); the busy "wave" reproduces the 12-step table documented in
/// lime-animated.svg.
enum LimeIcon {
    static let full = image(lit: [1, 2, 3], description: "Limac: a VM is running")
    static let empty = image(lit: [], description: "Limac: no VMs running")

    /// Hold time per wave step: ~2.5× the speed documented in
    /// lime-animated.svg (420 ms), so the 12-step loop takes ~2 s.
    static let frameInterval: TimeInterval = 0.17

    /// Lit segments per wave step, from lime-animated.svg's step table.
    static let frames: [NSImage] = [
        [], [1], [1, 2], [1, 2, 3], [2, 3], [3],
        [], [3], [2, 3], [1, 2, 3], [1, 2], [1],
    ].map { image(lit: $0, description: "Limac: an operation is in progress") }

    // Everything below is in the SVG's 24×24 viewBox coordinates (y down).

    private static let viewBox: CGFloat = 24
    /// Center of the segment fan; all three outer arcs share it.
    private static let fanCenter = CGPoint(x: 12, y: 7.8)
    private static let fleshRadius: CGFloat = 6.35
    private static let offOpacity: CGFloat = 0.18

    /// One flesh segment: apex near the fan center, two straight edges out to
    /// the arc, drawn apex → arcStart → (arc) → arcEnd → close.
    private struct Segment {
        let apex: CGPoint
        let arcStart: CGPoint
        let arcEnd: CGPoint
    }

    private static let segments: [Segment] = [
        .init(apex: CGPoint(x: 13.82, y: 8.85),
              arcStart: CGPoint(x: 18.26, y: 8.85), arcEnd: CGPoint(x: 16.04, y: 12.7)),
        .init(apex: CGPoint(x: 12, y: 9.9),
              arcStart: CGPoint(x: 14.22, y: 13.75), arcEnd: CGPoint(x: 9.78, y: 13.75)),
        .init(apex: CGPoint(x: 10.18, y: 8.85),
              arcStart: CGPoint(x: 7.96, y: 12.7), arcEnd: CGPoint(x: 5.74, y: 8.85)),
    ]

    private static func image(lit: Set<Int>, description: String) -> NSImage {
        let opacities = (1...3).map { lit.contains($0) ? 1.0 : offOpacity }
        // flipped: true gives a top-left origin, matching SVG coordinates.
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: true) { rect in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            ctx.scaleBy(x: rect.width / viewBox, y: rect.height / viewBox)
            // The SVG group transform: translate(2.34 2.34) rotate(-45 12 12).
            ctx.translateBy(x: 2.34, y: 2.34)
            ctx.translateBy(x: 12, y: 12)
            ctx.rotate(by: -45 * .pi / 180)
            ctx.translateBy(x: -12, y: -12)

            ctx.setLineJoin(.round)
            ctx.setStrokeColor(.black)
            ctx.setFillColor(.black)

            // Rind: flat cut line + curved skin, one closed stroked path.
            ctx.setLineWidth(1.5)
            ctx.move(to: CGPoint(x: 2.75, y: 7))
            ctx.addLine(to: CGPoint(x: 21.25, y: 7))
            ctx.addArc(center: CGPoint(x: 12, y: 7), radius: 9.25,
                       startAngle: 0, endAngle: .pi, clockwise: false)
            ctx.closePath()
            ctx.strokePath()

            // Flesh: fill+stroke with round joins produces the SVG's fillet
            // rounding. The transparency layer applies the segment's opacity
            // to fill and stroke as one, like SVG element opacity.
            ctx.setLineWidth(1.2)
            for (segment, opacity) in zip(segments, opacities) {
                ctx.setAlpha(opacity)
                ctx.beginTransparencyLayer(auxiliaryInfo: nil)
                ctx.move(to: segment.apex)
                ctx.addLine(to: segment.arcStart)
                ctx.addArc(center: fanCenter, radius: fleshRadius,
                           startAngle: angle(of: segment.arcStart),
                           endAngle: angle(of: segment.arcEnd),
                           clockwise: false)
                ctx.closePath()
                ctx.drawPath(using: .fillStroke)
                ctx.endTransparencyLayer()
            }
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = description
        return image
    }

    private static func angle(of point: CGPoint) -> CGFloat {
        atan2(point.y - fanCenter.y, point.x - fanCenter.x)
    }
}
