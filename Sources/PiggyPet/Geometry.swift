import AppKit
import CoreGraphics

enum Geometry {
    /// AppKit origin is bottom-left, CoreGraphics origin is top-left.
    static func toCG(_ point: NSPoint) -> CGPoint {
        let height = NSScreen.screens.first?.frame.height ?? 0
        return CGPoint(x: point.x, y: height - point.y)
    }

    static func clampToScreens(_ point: CGPoint) -> CGPoint {
        var result = point
        var found = false
        for screen in NSScreen.screens {
            let frame = screen.frame
            if frame.contains(result) {
                found = true
                break
            }
        }
        if !found, let first = NSScreen.screens.first {
            let frame = first.frame
            result.x = min(max(result.x, frame.minX + 8), frame.maxX - 8)
            result.y = min(max(result.y, frame.minY + 8), frame.maxY - 8)
        }
        return result
    }

    /// Keeps at least part of a dragged window on a visible screen.
    static func clampWindowOrigin(_ origin: NSPoint, size: NSSize) -> NSPoint {
        let frames = NSScreen.screens.map(\.visibleFrame)
        for frame in frames {
            let minimum = NSPoint(x: frame.minX - size.width + 60, y: frame.minY - size.height + 60)
            let maximum = NSPoint(x: frame.maxX - 60, y: frame.maxY - 60)
            if origin.x >= minimum.x, origin.x <= maximum.x,
               origin.y >= minimum.y, origin.y <= maximum.y {
                return origin
            }
        }
        if let frame = frames.first {
            return NSPoint(
                x: min(max(origin.x, frame.minX), frame.maxX - size.width),
                y: min(max(origin.y, frame.minY), frame.maxY - size.height)
            )
        }
        return origin
    }

    /// Replaces every interior corner of a polyline with a quadratic fillet,
    /// so a turn is always a bend rather than a pivot. Tangents stay continuous
    /// with both legs, and the cut never eats more than 45 % of a leg, so short
    /// hops keep their straight sections instead of turning into mush.
    static func roundCorners(_ points: [NSPoint], radius: CGFloat,
                             samplesPerCorner: Int = 12) -> [NSPoint] {
        guard points.count > 2 else { return points }
        var result: [NSPoint] = [points[0]]
        for index in 1..<(points.count - 1) {
            let previous = points[index - 1]
            let corner = points[index]
            let next = points[index + 1]
            let inVec = NSPoint(x: corner.x - previous.x, y: corner.y - previous.y)
            let outVec = NSPoint(x: next.x - corner.x, y: next.y - corner.y)
            let inLength = hypot(inVec.x, inVec.y)
            let outLength = hypot(outVec.x, outVec.y)
            guard inLength > 0.5, outLength > 0.5 else { continue }

            let cut = min(radius, inLength * 0.45, outLength * 0.45)
            let start = NSPoint(x: corner.x - inVec.x / inLength * cut,
                                y: corner.y - inVec.y / inLength * cut)
            let end = NSPoint(x: corner.x + outVec.x / outLength * cut,
                              y: corner.y + outVec.y / outLength * cut)
            result.append(start)
            for step in 1...samplesPerCorner {
                let t = CGFloat(step) / CGFloat(samplesPerCorner + 1)
                let inv = 1 - t
                result.append(NSPoint(
                    x: inv * inv * start.x + 2 * inv * t * corner.x + t * t * end.x,
                    y: inv * inv * start.y + 2 * inv * t * corner.y + t * t * end.y
                ))
            }
            result.append(end)
        }
        result.append(points[points.count - 1])
        return result
    }

    static func bottomLeftOrigin(for size: NSSize) -> NSPoint {
        let frame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1280, height: 800)
        return NSPoint(x: frame.minX + 8, y: frame.minY + 8)
    }
}
