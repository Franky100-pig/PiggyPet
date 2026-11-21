import AppKit

/// A polyline with cumulative arc lengths, evaluated by distance. Kept as a
/// plain value type so timer callbacks can use it without touching the pet.
private struct WalkPath: Sendable {
    let vertices: [NSPoint]
    let cumulative: [CGFloat]

    var total: CGFloat { cumulative.last ?? 0 }

    init(start: NSPoint, points: [NSPoint]) {
        var nodes: [NSPoint] = [start]
        for point in points {
            guard let last = nodes.last else { break }
            if hypot(point.x - last.x, point.y - last.y) > 0.5 {
                nodes.append(point)
            }
        }
        vertices = nodes

        var lengths: [CGFloat] = [0]
        for index in 1..<max(nodes.count, 1) {
            let previous = nodes[index - 1], current = nodes[index]
            lengths.append(lengths[index - 1] +
                           hypot(current.x - previous.x, current.y - previous.y))
        }
        cumulative = lengths
    }

    func position(at distance: CGFloat) -> NSPoint {
        guard vertices.count > 1 else { return vertices.first ?? .zero }
        let clamped = min(max(distance, 0), total)
        var index = 1
        while index < cumulative.count - 1, cumulative[index] < clamped {
            index += 1
        }
        let span = cumulative[index] - cumulative[index - 1]
        let t = span > 0.0001 ? (clamped - cumulative[index - 1]) / span : 0
        let a = vertices[index - 1], b = vertices[index]
        return NSPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
    }
}

/// Moves the pet window smoothly along a path while advancing the walk
/// animation. Completion is called once the end is reached (or cancelled).
@MainActor
final class WalkMover {
    weak var view: PetView?
    weak var window: PetWindow?

    private var moveTimer: Timer?
    private var frameTimer: Timer?
    private var onComplete: (() -> Void)?
    /// Which way the sprite currently faces; survives across a turn so the
    /// flip happens once instead of on every sample.
    private var facingRight = false

    /// Default speed in points per second. Callers can override per walk:
    /// a slow saunter for idle strolls, a fast dash when chasing the cursor.
    private let speed: CGFloat = 110
    /// Frame interval tuned for the 110 pt/s trot (20 frames ≈ 1.2 s).
    private let baseFrameInterval: TimeInterval = 0.06
    /// How far ahead to look when deciding which way the pig faces. Without
    /// this a path built from short segments flips direction on every sample
    /// near a turn, which reads as twitching.
    private let lookAhead: CGFloat = 26

    var isMoving: Bool { moveTimer != nil }

    /// Straight-line walk, used by chases and one-off moves.
    func walk(to target: NSPoint, facingRight: Bool = true,
              speed overrideSpeed: CGFloat? = nil, style: WalkStyle = .trot,
              completion: @escaping () -> Void) {
        walk(path: [target], speed: overrideSpeed, style: style, completion: completion)
    }

    /// Follows a whole polyline in one pass: one movement timer, one frame
    /// timer, one uninterrupted animation. Curved routes are passed as many
    /// close-together points; nothing restarts between them, so the legs keep
    /// pedalling through the bend.
    func walk(path points: [NSPoint], speed overrideSpeed: CGFloat? = nil,
              style: WalkStyle = .trot, completion: @escaping () -> Void) {
        // Keep the current pose: this may be a continuation of the same walk.
        cancel(resetAnimation: false)
        guard let window else { completion(); return }

        let start = window.frame.origin
        let path = WalkPath(start: start, points: points)
        let total = path.total
        guard total > 1 else { completion(); return }

        let actualSpeed = max(overrideSpeed ?? speed, 1)
        // Legs keep pace with the body: a slow saunter cycles slower, a dash
        // faster, so the pig never looks like it is sliding across the screen.
        let interval = min(0.14, max(0.035, baseFrameInterval * speed / actualSpeed))
        startFrameTimer(interval: interval)

        facingRight = path.position(at: min(lookAhead, total)).x - start.x >= 0
        view?.startWalking(facingRight: facingRight, style: style)
        onComplete = completion

        if ProcessInfo.processInfo.environment["PIGGY_DEBUG"] == "1"
            || ProcessInfo.processInfo.arguments.contains("--debug") {
            let label: String
            switch style {
            case .trot: label = "trot"
            case .dash: label = "dash"
            }
            NSLog("[PiggyPet] walk style=%@ speed=%.0fpt/s pts=%d len=%.0f dur=%.1fs interval=%.0fms",
                  label, actualSpeed, path.vertices.count, total, total / actualSpeed,
                  interval * 1000)
        }

        let started = Date()
        moveTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] timer in
            MainActor.assumeIsolated {
                guard let self else { timer.invalidate(); return }
                let elapsed = Date().timeIntervalSince(started)
                let travelled = min(total, CGFloat(elapsed) * actualSpeed)
                let origin = path.position(at: travelled)
                if let window = self.window {
                    window.setFrameOrigin(Geometry.clampWindowOrigin(
                        origin, size: window.frame.size
                    ))
                }

                // Face where the path goes a little later, and only turn once
                // the horizontal component is decisive — no per-sample flicker.
                let ahead = path.position(at: min(total, travelled + self.lookAhead))
                let dx = ahead.x - origin.x
                if abs(dx) > 6 {
                    let shouldFaceRight = dx > 0
                    if shouldFaceRight != self.facingRight {
                        self.facingRight = shouldFaceRight
                        self.view?.startWalking(facingRight: shouldFaceRight, style: style)
                    }
                }

                if travelled >= total {
                    self.finish()
                }
            }
        }
        RunLoop.main.add(moveTimer!, forMode: .common)
    }

    func cancel(resetAnimation: Bool = true) {
        moveTimer?.invalidate()
        moveTimer = nil
        frameTimer?.invalidate()
        frameTimer = nil
        onComplete = nil
        if resetAnimation {
            view?.stopWalking()
        }
    }

    private func startFrameTimer(interval: TimeInterval) {
        frameTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.view?.advanceWalkFrame()
            }
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
