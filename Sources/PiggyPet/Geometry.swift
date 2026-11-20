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

    static func bottomLeftOrigin(for size: NSSize) -> NSPoint {
        let frame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1280, height: 800)
        return NSPoint(x: frame.minX + 8, y: frame.minY + 8)
    }
}
