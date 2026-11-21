import AppKit
import CoreGraphics

/// Briefly pushes the cursor away from the pet using CGWarpMouseCursorPosition.
/// This needs no Accessibility permission and posts no synthetic click events.
@MainActor
final class MousePusher {
    /// A single short nudge of the cursor away from the pet.
    func nudge(petOrigin: NSPoint, delay: TimeInterval = 0) {
        guard Preferences.tantrumEnabled else { return }
        let pet = Geometry.toCG(petOrigin)
        guard let start = CGEvent(source: nil)?.location else { return }

        let dx = start.x - pet.x
        let dy = start.y - pet.y
        let length = max(hypot(dx, dy), 1)
        let unit = CGPoint(x: dx / length, y: dy / length)
        let steps: [CGFloat] = [6, 10, 12, 9, 5]

        var cancelled = false
        var previous = start
        for (index, step) in steps.enumerated() {
            DispatchQueue.main.asyncAfter(
                deadline: .now() + delay + 0.1 * Double(index)
            ) {
                guard Preferences.tantrumEnabled, !cancelled,
                      let current = CGEvent(source: nil)?.location else { return }
                // The user moved the mouse deliberately - don't fight them.
                if hypot(current.x - previous.x, current.y - previous.y) > 24 {
                    cancelled = true
                    return
                }
                let target = Geometry.clampToScreens(
                    CGPoint(x: current.x + unit.x * step, y: current.y + unit.y * step)
                )
                if CGWarpMouseCursorPosition(target) == .success {
                    previous = target
                    Self.debug("nudge step \(index) -> \(target)")
                }
            }
        }
    }

    /// Three short nudges in a row - the "keep poking you" tantrum burst.
    func nudgeRepeatedly(petOrigin: NSPoint) {
        for burst in 0..<3 {
            nudge(petOrigin: petOrigin, delay: 0.45 * Double(burst))
        }
    }

    private static func debug(_ message: String) {
        guard ProcessInfo.processInfo.environment["PIGGY_DEBUG"] == "1" else { return }
        NSLog("[PiggyPet] \(message)")
    }
}
