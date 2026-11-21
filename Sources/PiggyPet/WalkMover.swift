import AppKit

/// Moves the pet window smoothly along the ground while advancing the walk
/// animation. Completion is called once the target is reached (or cancelled).
@MainActor
final class WalkMover {
    weak var view: PetView?
    weak var window: PetWindow?

    private var moveTimer: Timer?
    private var frameTimer: Timer?
    private var onComplete: (() -> Void)?

    /// Default speed in points per second. Callers can override per walk:
    /// a slow saunter for idle strolls, a fast dash when chasing the cursor.
    private let speed: CGFloat = 110
    /// Frame interval tuned for the 110 pt/s trot (20 frames ≈ 1.2 s).
    private let baseFrameInterval: TimeInterval = 0.06

    var isMoving: Bool { moveTimer != nil }

    /// - Parameters:
    ///   - speed: optional pt/s override; defaults to the normal trot speed.
    ///   - style: which animation to play; `.dash` is the angry running pig
    ///            used while chasing the cursor.
    func walk(to target: NSPoint, facingRight: Bool,
              speed overrideSpeed: CGFloat? = nil, style: WalkStyle = .trot,
              completion: @escaping () -> Void) {
        cancel()
        guard let window else { completion(); return }

        let from = window.frame.origin
        let dx = target.x - from.x
        let distance = hypot(dx, target.y - from.y)
        guard distance > 1 else { completion(); return }

        // The source art faces left; the catalog mirrors it to face right.
        view?.startWalking(facingRight: dx > 0, style: style)
        onComplete = completion

        // Legs keep pace with the body: a slow saunter cycles slower, a dash
        // faster, so the pig never looks like it is sliding across the screen.
        let actualSpeed = max(overrideSpeed ?? speed, 1)
        let interval = min(0.14, max(0.035, baseFrameInterval * speed / actualSpeed))
        startFrameTimer(interval: interval)

        let duration = TimeInterval(distance / actualSpeed)
        if ProcessInfo.processInfo.environment["PIGGY_DEBUG"] == "1"
            || ProcessInfo.processInfo.arguments.contains("--debug") {
            let label: String
            switch style {
            case .trot: label = "trot"
            case .dash: label = "dash"
            }
            NSLog("[PiggyPet] walk style=%@ speed=%.0fpt/s dist=%.0f dur=%.1fs interval=%.0fms",
                  label, actualSpeed, distance, duration, interval * 1000)
        }
        let started = Date()
        moveTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            let elapsed = Date().timeIntervalSince(started)
            let t = min(1, elapsed / max(duration, 0.001))
            let origin = NSPoint(
                x: from.x + dx * CGFloat(t),
                y: from.y + (target.y - from.y) * CGFloat(t)
            )
            self.window?.setFrameOrigin(Geometry.clampWindowOrigin(
                origin, size: self.window?.frame.size ?? NSSize(width: 200, height: 240)
            ))
            if t >= 1 {
                self.finish()
            }
        }
        RunLoop.main.add(moveTimer!, forMode: .common)
    }

    func cancel() {
        moveTimer?.invalidate()
        moveTimer = nil
        frameTimer?.invalidate()
        frameTimer = nil
        onComplete = nil
        view?.stopWalking()
    }

    private func startFrameTimer(interval: TimeInterval) {
        frameTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.view?.advanceWalkFrame()
        }
        RunLoop.main.add(frameTimer!, forMode: .common)
    }

    private func finish() {
        moveTimer?.invalidate()
        moveTimer = nil
        frameTimer?.invalidate()
        frameTimer = nil
        view?.stopWalking()
        let done = onComplete
        onComplete = nil
        done?()
    }
}
