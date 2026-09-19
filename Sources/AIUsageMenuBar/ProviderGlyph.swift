import AppKit
import UsageCore

/// Menu bar marks for each provider, drawn as vector paths.
///
/// Vectors rather than the shipped app icons: a full-colour icon cannot take the
/// severity tint, does not invert between light and dark menu bars, and loses
/// its detail at ~13pt anyway. At this size the silhouette is the whole signal,
/// so each mark is reduced to the shape that identifies it.
enum ProviderGlyph {
    private static let side: CGFloat = 13

    static func image(for provider: ProviderID, tint: NSColor) -> NSImage {
        let size = NSSize(width: side, height: side)
        let image = NSImage(size: size, flipped: false) { rect in
            tint.setFill()
            tint.setStroke()
            switch provider {
            case .claudeCode: drawBurst(in: rect)
            case .codex: drawKnot(in: rect)
            case .cursor: drawCursor(in: rect)
            }
            return true
        }
        image.isTemplate = false
        return image
    }

    /// Claude: a radial burst of tapered rays.
    ///
    /// Ray width is absolute rather than angular. An angular wedge converges to
    /// nothing at the hub and renders as hairlines that disappear at 13pt; a
    /// fixed half-width keeps each ray solid all the way in.
    private static func drawBurst(in rect: NSRect) {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = rect.width * 0.5
        let rays = 11
        let hubRadius = radius * 0.06
        let halfWidth = radius * 0.085

        let path = NSBezierPath()
        for ray in 0..<rays {
            let angle = (CGFloat(ray) / CGFloat(rays)) * 2 * .pi + .pi / 2
            let direction = CGPoint(x: cos(angle), y: sin(angle))
            let perpendicular = CGPoint(x: -sin(angle), y: cos(angle))

            path.move(to: CGPoint(x: center.x + direction.x * hubRadius + perpendicular.x * halfWidth,
                                  y: center.y + direction.y * hubRadius + perpendicular.y * halfWidth))
            path.line(to: CGPoint(x: center.x + direction.x * radius,
                                  y: center.y + direction.y * radius))
            path.line(to: CGPoint(x: center.x + direction.x * hubRadius - perpendicular.x * halfWidth,
                                  y: center.y + direction.y * hubRadius - perpendicular.y * halfWidth))
            path.close()
        }
        // Fills the gap the rays leave at the centre.
        let hub = radius * 0.11
        path.appendOval(in: NSRect(x: center.x - hub, y: center.y - hub,
                                   width: hub * 2, height: hub * 2))
        path.fill()
    }

    /// Codex: the six-fold rosette of the OpenAI mark, as three crossed loops.
    private static func drawKnot(in rect: NSRect) {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radiusX = rect.width * 0.44
        let radiusY = rect.width * 0.215

        let path = NSBezierPath()
        path.lineWidth = rect.width * 0.075
        path.lineJoinStyle = .round

        for step in 0..<3 {
            let angle = CGFloat(step) * .pi / 3
            let loop = NSBezierPath(ovalIn: NSRect(x: -radiusX, y: -radiusY,
                                                   width: radiusX * 2, height: radiusY * 2))
            var transform = AffineTransform(translationByX: center.x, byY: center.y)
            transform.rotate(byRadians: angle)
            loop.transform(using: transform)
            path.append(loop)
        }
        path.stroke()
    }

    /// Cursor: the mark is a cursor triangle; drawn plainly until the provider ships.
    private static func drawCursor(in rect: NSRect) {
        let path = NSBezierPath()
        path.move(to: CGPoint(x: rect.width * 0.5, y: rect.height * 0.92))
        path.line(to: CGPoint(x: rect.width * 0.9, y: rect.height * 0.22))
        path.line(to: CGPoint(x: rect.width * 0.5, y: rect.height * 0.4))
        path.line(to: CGPoint(x: rect.width * 0.1, y: rect.height * 0.22))
        path.close()
        path.fill()
    }
}
