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

    /// Speed in points per second along the path.
    private let speed: CGFloat = 110
    /// Walk-frame advance interval; ~19 frames over ~1.1s reads as a brisk trot.
    private let frameInterval: TimeInterval = 0.06

    var isMoving: Bool { moveTimer != nil }

    func walk(to target: NSPoint, facingRight: Bool, completion: @escaping () -> Void) {
        cancel()
        guard let window else { completion(); return }

        let from = window.frame.origin
        let dx = target.x - from.x
        let distance = hypot(dx, target.y - from.y)
        guard distance > 1 else { completion(); return }

        // The walk art faces left in its source frames; move right -> mirror.
        view?.startWalking(facingRight: dx > 0)
        onComplete = completion

        startFrameTimer()

        let duration = TimeInterval(distance / speed)
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

    private func startFrameTimer() {
        frameTimer = Timer.scheduledTimer(withTimeInterval: frameInterval, repeats: true) { [weak self] _ in
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
