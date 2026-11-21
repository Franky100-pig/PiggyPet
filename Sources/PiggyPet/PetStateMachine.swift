import AppKit

@MainActor
final class PetStateMachine {
    enum State {
        case sleep, idle, switching, tantrum, drag, walking
    }

    private(set) var state: State = .sleep
    weak var view: PetView?
    weak var window: PetWindow?

    private let catalog = AssetCatalog.shared
    private let pusher = MousePusher()
    private let mover = WalkMover()
    /// Strolling pace comes from the 走路速度 menu; chasing is always a sprint
    /// and is the only thing that uses the fast 快跑猪 animation.
    private var strollSpeed: CGFloat { Preferences.walkPace.pointsPerSecond }
    private let chaseSpeed: CGFloat = 170
    private var awakeTimer: Timer?
    private var tantrumTimer: Timer?
    private var strollTimer: Timer?
    private var zzzTimer: Timer?
    private var zzzPhase = 0
    /// Bumped on every direct pointer interaction so in-flight chase callbacks
    /// can tell they were interrupted and bail out.
    private var interactionToken = 0

    func start() {
        mover.view = view
        mover.window = window
        enterSleep()
        rescheduleTantrum()
        rescheduleStroll()
    }

    func stop() {
        awakeTimer?.invalidate()
        tantrumTimer?.invalidate()
        strollTimer?.invalidate()
        zzzTimer?.invalidate()
        mover.cancel()
    }

    func handleTap() {
        mover.cancel()
        let sprite = catalog.random(except: view?.currentSprite.id)
        view?.show(sprite)
        view?.setBubble(Preferences.bubbleEnabled ? sprite.bubble : nil)
        view?.setZzz(0)
        state = .switching
        // After a tap, go back to sleep if the user does nothing for 10-15 s.
        // Any pointer interaction invalidates this timer and restarts the wait.
        scheduleAwake(seconds: .random(in: 10...15))
    }

    func beginPointerInteraction() {
        interactionToken += 1
        awakeTimer?.invalidate()
        tantrumTimer?.invalidate()
        strollTimer?.invalidate()
        zzzTimer?.invalidate()
        mover.cancel()
        view?.setZzz(0)
        view?.setBubble(nil)
        state = .drag
    }

    func endPointerInteraction(wasTap: Bool) {
        if wasTap {
            handleTap()
        } else {
            enterIdle()
        }
        rescheduleTantrum()
        rescheduleStroll()
    }

    func cancelTantrum() {
        tantrumTimer?.invalidate()
        if state == .tantrum || state == .walking {
            mover.cancel()
            enterIdle()
        }
    }

    func rescheduleTantrum() {
        tantrumTimer?.invalidate()
        guard Preferences.tantrumEnabled else { return }
        let range = Preferences.tantrumInterval
        tantrumTimer = schedule(seconds: .random(in: range)) { [weak self] in
            guard let self else { return }
            if self.state == .sleep || self.state == .idle {
                self.performAutomaticActivity()
            } else {
                self.rescheduleTantrum()
            }
        }
    }

    /// An automatic activity is mostly a casual stroll; the configured
    /// probability decides whether it becomes a cursor nudge instead.
    private func shouldChase() -> Bool {
        Double.random(in: 0..<1) < Preferences.nudgeFrequency.chaseProbability
    }

    func performAutomaticActivity() {
        let chance = Preferences.nudgeFrequency.chaseProbability
        let chase = shouldChase()
        if ProcessInfo.processInfo.environment["PIGGY_DEBUG"] == "1" {
            NSLog("[PiggyPet] autoActivity=%@ freq=%@ p=%.2f",
                  chase ? "chase" : "stroll",
                  Preferences.nudgeFrequency.rawValue, chance)
        }
        if chase {
            startChase() // re-arms both timers when the walk home completes
        } else {
            startStroll()
            rescheduleTantrum() // startStroll only re-arms the stroll timer
        }
    }

    func clearBubble() {
        view?.setBubble(nil)
    }

    /// Used only by the PIGGY_DEBUG distributed-notification hook.
    func debugTrigger(_ action: String) {
        switch action {
        case "tap": handleTap()
        case "tantrum": startChase()
        case "auto": performAutomaticActivity()
        case "nudgefreq":
            let freq = Preferences.nudgeFrequency
            let sample = (0..<1000).reduce(0) { total, _ in total + (self.shouldChase() ? 1 : 0) }
            NSLog("[PiggyPet] nudgeFreq=%@ p=%.2f chase=%d/1000",
                  freq.rawValue, freq.chaseProbability, sample)
        case "stroll": startStroll()
        case "excitement":
            rescheduleStroll()
            let range = Preferences.excitement.strollInterval
            NSLog("[PiggyPet] excitement=%@ stroll=%.0f-%.0fs timer=%@",
                  Preferences.excitement.rawValue,
                  range.lowerBound, range.upperBound,
                  strollTimer.map { String(format: "%.0fs", $0.fireDate.timeIntervalSinceNow) } ?? "none")
        case "sleep": enterSleep()
        case "pace":
            NSLog("[PiggyPet] pace=%@ stroll=%.0fpt/s chase=%.0fpt/s",
                  Preferences.walkPace.rawValue, strollSpeed, chaseSpeed)
        case let action where action.hasPrefix("pace:"):
            let raw = String(action.dropFirst("pace:".count))
            if let pace = WalkPace(rawValue: raw) {
                Preferences.setWalkPace(pace)
                NSLog("[PiggyPet] pace=%@ stroll=%.0fpt/s", pace.rawValue, strollSpeed)
            }
        case "dash":
            // Visual check for the 快跑猪 run cycle, independent of the cursor.
            guard let window else { break }
            let origin = window.frame.origin
            state = .walking
            mover.walk(to: NSPoint(x: origin.x + 240, y: origin.y),
                       facingRight: true, speed: chaseSpeed, style: .dash) { [weak self] in
                self?.enterSleep()
            }
        case "dashleft":
            guard let window else { break }
            let origin = window.frame.origin
            state = .walking
            mover.walk(to: NSPoint(x: origin.x - 240, y: origin.y),
                       facingRight: false, speed: chaseSpeed, style: .dash) { [weak self] in
                self?.enterSleep()
            }
        case "where":
            if let origin = window?.frame.origin {
                NSLog("[PiggyPet] where=(%.0f,%.0f) state=%@",
                      origin.x, origin.y, String(describing: state))
            }
        case "state":
            let awake = awakeTimer.map { String(format: "%.0fs", $0.fireDate.timeIntervalSinceNow) } ?? "none"
            let stroll = strollTimer.map { String(format: "%.0fs", $0.fireDate.timeIntervalSinceNow) } ?? "none"
            NSLog("[PiggyPet] state=%@ sprite=%@ awake=%@ stroll=%@",
                  String(describing: state), view?.currentSprite.id ?? "nil", awake, stroll)
        case let action where action.hasPrefix("sprite:"):
            let id = String(action.dropFirst("sprite:".count))
            if let sprite = catalog.manifest.sprites.first(where: { $0.id == id }) {
                view?.show(sprite)
            }
        default: break
        }
    }

    // MARK: - Walking behaviors

    /// A longer wander with a proper way home. The pig trots out along one
    /// horizontal lane, cuts diagonally to a parallel lane, walks back along
    /// that different lane, then cuts diagonally onto its starting spot.
    /// The result is an irregular loop (never a circle, never a straight
    /// there-and-back on the same line).
    func startStroll() {
        guard let window, walkAvailable else { return }
        awakeTimer?.invalidate()
        zzzTimer?.invalidate()
        strollTimer?.invalidate()

        let home = window.frame.origin
        let size = window.frame.size
        let waypoints = strollRoute(from: home, size: size)
        let token = interactionToken

        if debugEnabled {
            let path = [home] + waypoints
            NSLog("[PiggyPet] strollRoute=%@", path.map {
                String(format: "(%.0f,%.0f)", $0.x, $0.y)
            }.joined(separator: " -> "))
        }

        state = .walking
        walkRoute(waypoints, token: token, speed: strollSpeed) { [weak self] in
            guard let self, self.interactionToken == token else { return }
            self.enterSleep()
            self.rescheduleStroll()
        }
    }

    /// Builds a random zig-zag walk. Turn count, span and lane heights are
    /// re-rolled every time, so no two strolls follow the same path. Two hard
    /// rules keep it looking like walking: every leg has a real horizontal
    /// travel (never a pure vertical elevator ride), and the last waypoint is
    /// always `home`, so the pig returns to where it started. Far and near
    /// turns are biased to opposite vertical lanes so it doesn't retrace a
    /// single line, and the shape is an open zig-zag, never a closed circle.
    private func strollRoute(from home: NSPoint, size: NSSize) -> [NSPoint] {
        let frame = NSScreen.main?.visibleFrame
            ?? NSRect(x: 0, y: 0, width: 1280, height: 800)
        let minX = frame.minX - size.width + 60
        let maxX = frame.maxX - 60
        let minY = frame.minY - size.height + 60
        let maxY = frame.maxY - 60

        func fit(_ p: NSPoint) -> NSPoint {
            Geometry.clampWindowOrigin(p, size: size)
        }

        // Head toward whichever side has more room so the outing can be long.
        let dir: CGFloat = (maxX - home.x) >= (home.x - minX) ? 1 : -1
        let room = max(maxX - home.x, home.x - minX)
        let span = min(CGFloat.random(in: 260...400), room * 0.9)

        // Random vertical spread. Far and near turns sit on opposite sides of
        // `home`, so the outbound and inbound paths are visibly different.
        let vdir: CGFloat = Bool.random() ? 1 : -1
        let lane = CGFloat.random(in: 35...65)
        func laneY(_ side: CGFloat) -> CGFloat {
            let raw = home.y + vdir * side * lane * CGFloat.random(in: 0.3...0.9)
            return min(max(raw, minY), maxY)
        }

        // Far turns go near the end of the span, near turns pull back to ~40%.
        // Because the two progress bands never overlap, every consecutive pair
        // (and the final leg home) keeps >= ~0.3*span of horizontal travel.
        let legs = Int.random(in: 3...4)
        var points: [NSPoint] = []
        for i in 0..<legs {
            let far = (i % 2 == 0)
            let progress: CGFloat = far
                ? CGFloat.random(in: 0.80...1.00)
                : CGFloat.random(in: 0.32...0.50)
            let x = min(max(home.x + span * dir * progress, minX), maxX)
            points.append(fit(NSPoint(x: x, y: laneY(far ? 1 : -1))))
        }
        points.append(home)
        return points
    }

    /// Walks a list of waypoints in order, honouring pointer interruption.
    private func walkRoute(_ points: [NSPoint], token: Int,
                           speed: CGFloat, completion: @escaping () -> Void) {
        guard let first = points.first else { completion(); return }
        let remaining = Array(points.dropFirst())
        let facingRight = first.x > (window?.frame.origin.x ?? first.x)
        mover.walk(to: first, facingRight: facingRight, speed: speed) { [weak self] in
            guard let self, self.interactionToken == token else { return }
            if remaining.isEmpty {
                completion()
            } else {
                self.walkRoute(remaining, token: token, speed: speed, completion: completion)
            }
        }
    }

    private var debugEnabled: Bool {
        ProcessInfo.processInfo.environment["PIGGY_DEBUG"] == "1"
            || ProcessInfo.processInfo.arguments.contains("--debug")
    }

    /// Tantrum: trot over to the cursor, poke it a few times, trot back, sleep.
    /// `force` lets the menu action nudge even if auto-tantrum is switched off.
    func startChase(force: Bool = false) {
        guard let window, walkAvailable else {
            rescheduleTantrum()
            return
        }
        tantrumTimer?.invalidate()
        strollTimer?.invalidate()
        awakeTimer?.invalidate()
        zzzTimer?.invalidate()

        let home = window.frame.origin
        let cursor = NSEvent.mouseLocation
        // Place the window so the pig's BODY center lands right beside the
        // cursor (offset by the sprite's position inside the window). Leave a
        // small gap so the snout reaches the cursor without covering it.
        let goal = Geometry.clampWindowOrigin(
            NSPoint(
                x: cursor.x - PetView.spriteCenterOffset.x + 26,
                y: cursor.y - PetView.spriteCenterOffset.y + 4
            ),
            size: window.frame.size
        )
        state = .walking
        let token = interactionToken
        mover.walk(to: goal, facingRight: goal.x > home.x,
                   speed: chaseSpeed, style: .dash) { [weak self] in
            guard let self, self.interactionToken == token else { return }
            self.enterTantrum(force: force)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                // A click/tap during the tantrum invalidates this chase.
                guard self.interactionToken == token else { return }
                self.walkHome(home)
            }
        }
    }

    private func walkHome(_ home: NSPoint) {
        guard let window, walkAvailable else {
            enterSleep()
            rescheduleTantrum()
            rescheduleStroll()
            return
        }
        state = .walking
        mover.walk(to: home, facingRight: home.x > window.frame.origin.x,
                   speed: chaseSpeed, style: .dash) { [weak self] in
            self?.enterSleep()
            self?.rescheduleTantrum()
            self?.rescheduleStroll()
        }
    }

    private func enterTantrum(force: Bool = false) {
        state = .tantrum
        zzzTimer?.invalidate()
        view?.setZzz(0)
        view?.show(catalog.chaseSprite)
        view?.setBubble(Preferences.bubbleEnabled ? "别跑！" : nil)
        view?.shake()
        if let window {
            pusher.nudgeRepeatedly(petOrigin: window.frame.origin, force: force)
        }
    }

    private func enterIdle() {
        state = .idle
        zzzTimer?.invalidate()
        view?.setZzz(0)
        view?.setBubble(nil)
        scheduleAwake(seconds: .random(in: 2...3))
    }

    private func enterSleep() {
        state = .sleep
        mover.cancel()
        view?.show(catalog.sleepSprite)
        view?.setBubble(nil)
        zzzPhase = 0
        view?.setZzz(1)
        zzzTimer?.invalidate()
        zzzTimer = schedule(seconds: 1.1) { [weak self] in
            guard let self else { return }
            self.zzzPhase += 1
            self.view?.setZzz(self.zzzPhase % 2 == 0 ? 1.0 : 0.35)
        }
    }

    func rescheduleStroll() {
        strollTimer?.invalidate()
        let range = Preferences.excitement.strollInterval
        strollTimer = schedule(seconds: .random(in: range)) { [weak self] in
            guard let self else { return }
            if self.state == .sleep || self.state == .idle {
                self.startStroll()
            } else {
                self.rescheduleStroll()
            }
        }
    }

    private func scheduleAwake(seconds: TimeInterval) {
        awakeTimer?.invalidate()
        awakeTimer = schedule(seconds: seconds) { [weak self] in
            guard let self else { return }
            if self.state == .tantrum || self.state == .switching || self.state == .idle {
                self.enterSleep()
            }
        }
    }

    @discardableResult
    private func schedule(seconds: TimeInterval, action: @escaping () -> Void) -> Timer {
        let timer = Timer.scheduledTimer(withTimeInterval: seconds, repeats: false) { _ in
            action()
        }
        timer.tolerance = min(1.0, seconds * 0.1)
        RunLoop.main.add(timer, forMode: .common)
        return timer
    }

    private var walkAvailable: Bool { WalkCatalog.shared.isAvailable }
}
