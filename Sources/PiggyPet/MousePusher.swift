import AppKit
import CoreGraphics

/// Briefly pushes the cursor away from the pet using CGWarpMouseCursorPosition.
/// This needs no Accessibility permission and posts no synthetic click events.
@MainActor
final class MousePusher {
    /// A single short nudge of the cursor away from the pet.
    /// `force` lets an explicit menu action nudge even when auto-tantrum is off.
    func nudge(petOrigin: NSPoint, delay: TimeInterval = 0, force: Bool = false) {
        guard force || Preferences.tantrumEnabled else { return }
        // Push along the line from the pig's BODY (not the window origin) to
        // the cursor, so the shove appears to come from the snout.
        let bodyOrigin = NSPoint(
            x: petOrigin.x + PetView.spriteCenterOffset.x,
            y: petOrigin.y + PetView.spriteCenterOffset.y
        )
        let pet = Geometry.toCG(bodyOrigin)
        guard let start = CGEvent(source: nil)?.location else { return }

        let dx = start.x - pet.x
        let dy = start.y - pet.y
        let length = max(hypot(dx, dy), 1)
        let unit = CGPoint(x: dx / length, y: dy / length)
        let steps: [CGFloat] = [6, 10, 12, 9, 5]

        var cancelled = false
        // Initialised on the FIRST scheduled step, not at call time: a burst
        // schedules several nudges up front, and seeding `previous` here would
        // make later rounds mistake the earlier round's warp for user movement.
        var previous: CGPoint?
        for (index, step) in steps.enumerated() {
            DispatchQueue.main.asyncAfter(
                deadline: .now() + delay + 0.1 * Double(index)
            ) {
                guard (force || Preferences.tantrumEnabled), !cancelled,
                      let current = CGEvent(source: nil)?.location else { return }
                // The user moved the mouse deliberately - don't fight them.
                // Skip this check on the first step, which has no baseline yet.
                if let prior = previous,
                   hypot(current.x - prior.x, current.y - prior.y) > 24 {
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
    func nudgeRepeatedly(petOrigin: NSPoint, force: Bool = false) {
        for burst in 0..<3 {
            nudge(petOrigin: petOrigin, delay: 0.45 * Double(burst), force: force)
        }
    }

    private static func debug(_ message: String) {
        guard ProcessInfo.processInfo.environment["PIGGY_DEBUG"] == "1" else { return }
        NSLog("[PiggyPet] \(message)")
    }
}
