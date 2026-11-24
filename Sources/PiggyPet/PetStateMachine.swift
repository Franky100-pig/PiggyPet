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
    private var flashWork: DispatchWorkItem?
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
        // Tapping wakes the pig: the sleep pulse has to stop, or it keeps
        // redrawing a faint Zzz over the face it just switched to.
        zzzTimer?.invalidate()
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
        if debugEnabled {
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

    /// Short-lived bubble used for menu feedback (e.g. the login item needing
    /// approval in System Settings). Ignored by the usual sleep/state changes,
    /// which set their own text or clear it.
    func flashBubble(_ text: String) {
        flashWork?.cancel()
        view?.setBubble(text)
        let work = DispatchWorkItem { [weak self] in
            self?.view?.setBubble(nil)
        }
        flashWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5, execute: work)
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
                       speed: chaseSpeed, style: .dash) { [weak self] in
                self?.enterSleep()
            }
        case "dashleft":
            guard let window else { break }
            let origin = window.frame.origin
            state = .walking
            mover.walk(to: NSPoint(x: origin.x - 240, y: origin.y),
                       speed: chaseSpeed, style: .dash) { [weak self] in
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
        case let action where action.hasPrefix("login"):
            let argument = action.dropFirst("login".count).drop(while: { $0 == ":" })
            if argument == "on" || argument == "off" {
                LoginItem.setEnabled(argument == "on")
            }
            NSLog("[PiggyPet] loginItem=%@", LoginItem.statusDescription)
        default: break
        }
    }

    // MARK: - Walking behaviors

    /// A wander that goes somewhere new every time. The trip ends wherever the
    /// destination happened to be, and that spot becomes the starting point of
    /// the next outing, so repeated strolls drift around the screen instead of
    /// looping over the same corner.
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
            // It stops wherever the trip ended; remember that, so relaunching
            // doesn't teleport the pig back to a position from hours ago.
            if let end = self.window?.frame.origin {
                Preferences.saveOrigin(end)
            }
            self.enterSleep()
            self.rescheduleStroll()
        }
    }

    /// Plans one random outing leg by leg.
    ///
    /// The old route was a single fixed silhouette — out on a lane, half-circle
    /// at the far end, back to exactly the same spot — so every stroll looked
    /// like the last one with slightly different numbers. Here each leg rolls
    /// its own length, heading and whether it climbs or drops, so the trip has
    /// no predetermined shape and no obligation to come home: it simply stops
    /// where the last leg ended, and the next stroll starts from there.
    ///
    /// Constraint by construction, not by clamping: a leg's heading is held
    /// within ±33° of horizontal, so nothing ever reads as a vertical lift, and
    /// the heading drifts a little each leg (turning away from the screen edges)
    /// so the route waves instead of running along a ruler line. The whole trip
    /// keeps one travel direction, which rules out hairpin retraces and circles.
    private func strollRoute(from home: NSPoint, size: NSSize) -> [NSPoint] {
        let frame = (window?.screen ?? NSScreen.main)?.visibleFrame
            ?? NSRect(x: 0, y: 0, width: 1280, height: 800)
        // Keep the whole sprite on screen, not just the window: the sprite sits
        // 20–180 pt across and 16–176 pt up inside the 200×240 window.
        let minX = frame.minX - 20
        let maxX = frame.maxX - 180
        let minY = frame.minY - 16
        let maxY = frame.maxY - 176

        func fit(_ p: NSPoint) -> NSPoint {
            Geometry.clampWindowOrigin(p, size: size)
        }

        let legs = Int.random(in: 3...5)
        // Whole outing heads one way — the pig is going for a walk, not pacing
        // in a loop. Left/right is picked from whichever side has room, so it
        // never opens with a leg that has nowhere to go.
        let roomRight = maxX - home.x
        let roomLeft = home.x - minX
        let direction: CGFloat
        if roomRight < 320 {
            direction = -1
        } else if roomLeft < 320 {
            direction = 1
        } else {
            // Weighted by open space, so it heads across the screen instead of
            // hugging whichever wall it happens to stop near, but a trip toward
            // the nearer side still happens now and then.
            let share = roomRight / (roomRight + roomLeft)
            direction = CGFloat.random(in: 0...1) < min(max(share, 0.2), 0.8) ? 1 : -1
        }

        var current = home
        var waypoints: [NSPoint] = []
        var climbSign: CGFloat = Bool.random() ? 1 : -1

        for _ in 0..<legs {
            let room = direction > 0 ? maxX - current.x : current.x - minX
            let length = min(CGFloat.random(in: 150...310), room - 30)
            guard length > 90 else { break }

            // Flip up/down most of the time, and steer away from the top and
            // bottom of the screen before the pig gets there. Magnitude is
            // re-rolled per leg, so the wave has an irregular profile instead of
            // repeating the same sawtooth.
            if Bool.random() { climbSign = -climbSign }
            if maxY - current.y < 80 { climbSign = -1 }
            else if current.y - minY < 80 { climbSign = 1 }
            let climb = climbSign * CGFloat.random(in: 0.12...0.58)

            let next = NSPoint(
                x: current.x + direction * length,
                y: min(max(current.y + length * tan(climb), minY), maxY)
            )
            waypoints.append(fit(next))
            current = waypoints[waypoints.count - 1]
        }

        if waypoints.isEmpty {
            // No room anywhere (tiny screen): one small hop is still better
            // than a stroll that goes nowhere.
            waypoints = [fit(NSPoint(x: home.x + 160, y: home.y))]
        }

        let radius = CGFloat.random(in: 40...85)
        if debugEnabled {
            NSLog("[PiggyPet] strollPlan home=%@ legs=%ld radius=%.0f waypoints=%@",
                  String(format: "(%.0f,%.0f)", home.x, home.y),
                  legs, radius,
                  ([home] + waypoints).map {
                      String(format: "(%.0f,%.0f)", $0.x, $0.y)
                  }.joined(separator: " → "))
        }
        // `home` goes in as the start so every waypoint — including the first —
        // is an interior corner and gets a fillet; the mover prepends the
        // window's current origin itself, hence the drop.
        return Geometry.roundCorners([home] + waypoints, radius: radius)
            .dropFirst()
            .map(fit)
    }

    /// Walks a whole routed path in one pass, honouring pointer interruption.
    private func walkRoute(_ points: [NSPoint], token: Int,
                           speed: CGFloat, completion: @escaping () -> Void) {
        guard !points.isEmpty else { completion(); return }
        mover.walk(path: points, speed: speed) { [weak self] in
            guard let self, self.interactionToken == token else { return }
            completion()
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
        mover.walk(to: goal, speed: chaseSpeed, style: .dash) { [weak self] in
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
        guard walkAvailable else {
            enterSleep()
            rescheduleTantrum()
            rescheduleStroll()
            return
        }
        state = .walking
        mover.walk(to: home, speed: chaseSpeed, style: .dash) { [weak self] in
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
        startZzzPulse()
    }

    /// Slow "breathing" of the Zzz text while asleep. This used to be a single
    /// one-shot timer, so the Zzz dimmed once at 1.1 s and then stayed dim for
    /// the whole nap; it now keeps alternating until the pig wakes up.
    private func startZzzPulse() {
        zzzTimer?.invalidate()
        zzzPhase = 0
        view?.setZzz(1)
        let timer = scheduleRepeating(seconds: 1.6) { [weak self] in
            guard let self else { return }
            self.zzzPhase = (self.zzzPhase + 1) % 2
            self.view?.setZzz(self.zzzPhase == 0 ? 1.0 : 0.45)
        }
        zzzTimer = timer
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
        scheduleTimer(seconds: seconds, repeats: false, action: action)
    }

    @discardableResult
    private func scheduleRepeating(seconds: TimeInterval, action: @escaping () -> Void) -> Timer {
        scheduleTimer(seconds: seconds, repeats: true, action: action)
    }

    @discardableResult
    private func scheduleTimer(seconds: TimeInterval, repeats: Bool,
                               action: @escaping () -> Void) -> Timer {
        let timer = Timer.scheduledTimer(withTimeInterval: seconds, repeats: repeats) { _ in
            action()
        }
        timer.tolerance = min(1.0, seconds * 0.1)
        RunLoop.main.add(timer, forMode: .common)
        return timer
    }

    private var walkAvailable: Bool { WalkCatalog.shared.isAvailable }
}
