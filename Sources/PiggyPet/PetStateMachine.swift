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
        scheduleAwake(seconds: .random(in: 8...15))
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
                self.startChase()
            } else {
                self.rescheduleTantrum()
            }
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
        case "stroll": startStroll()
        case "sleep": enterSleep()
        default: break
        }
    }

    // MARK: - Walking behaviors

    /// Casual short wander while idle; the pig walks a little, then sleeps.
    func startStroll() {
        guard let window, walkAvailable else { return }
        awakeTimer?.invalidate()
        zzzTimer?.invalidate()
        strollTimer?.invalidate()

        let origin = window.frame.origin
        let span: CGFloat = .random(in: 90...170)
        let direction: CGFloat = Bool.random() ? 1 : -1
        let target = Geometry.clampWindowOrigin(
            NSPoint(x: origin.x + span * direction, y: origin.y),
            size: window.frame.size
        )
        state = .walking
        mover.walk(to: target, facingRight: direction > 0) { [weak self] in
            self?.enterSleep()
            self?.rescheduleStroll()
        }
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
        mover.walk(to: goal, facingRight: goal.x > home.x) { [weak self] in
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
        mover.walk(to: home, facingRight: home.x > window.frame.origin.x) { [weak self] in
            self?.enterSleep()
            self?.rescheduleTantrum()
            self?.rescheduleStroll()
        }
    }

    private func enterTantrum(force: Bool = false) {
        state = .tantrum
        zzzTimer?.invalidate()
        view?.setZzz(0)
        view?.show(catalog.angrySprite())
        view?.setBubble(Preferences.bubbleEnabled ? "哼！别碰我！" : nil)
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

    private func rescheduleStroll() {
        strollTimer?.invalidate()
        strollTimer = schedule(seconds: .random(in: 45...90)) { [weak self] in
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
