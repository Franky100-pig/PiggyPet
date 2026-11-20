import AppKit

@MainActor
final class PetStateMachine {
    enum State {
        case sleep, idle, switching, tantrum, drag
    }

    private(set) var state: State = .sleep
    weak var view: PetView?
    weak var window: PetWindow?

    private let catalog = AssetCatalog.shared
    private let pusher = MousePusher()
    private var awakeTimer: Timer?
    private var tantrumTimer: Timer?
    private var zzzTimer: Timer?
    private var zzzPhase = 0

    func start() {
        enterSleep()
        rescheduleTantrum()
    }

    func stop() {
        awakeTimer?.invalidate()
        tantrumTimer?.invalidate()
        zzzTimer?.invalidate()
    }

    func handleTap() {
        let sprite = catalog.random(except: view?.currentSprite.id)
        view?.show(sprite)
        view?.setBubble(Preferences.bubbleEnabled ? sprite.bubble : nil)
        view?.setZzz(0)
        state = .switching
        scheduleAwake(seconds: .random(in: 8...15))
    }

    func beginPointerInteraction() {
        awakeTimer?.invalidate()
        zzzTimer?.invalidate()
        tantrumTimer?.invalidate()
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
    }

    func cancelTantrum() {
        tantrumTimer?.invalidate()
        if state == .tantrum {
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
                self.enterTantrum()
            }
            self.rescheduleTantrum()
        }
    }

    func clearBubble() {
        view?.setBubble(nil)
    }

    /// Used only by the PIGGY_DEBUG distributed-notification hook.
    func debugTrigger(_ action: String) {
        switch action {
        case "tap": handleTap()
        case "tantrum": enterTantrum()
        case "sleep": enterSleep()
        default: break
        }
    }

    private func enterTantrum() {
        state = .tantrum
        zzzTimer?.invalidate()
        view?.setZzz(0)
        view?.show(catalog.angrySprite())
        view?.setBubble(Preferences.bubbleEnabled ? "哼！别碰我！" : nil)
        view?.shake()
        if let window {
            pusher.nudge(petOrigin: window.frame.origin)
        }
        scheduleAwake(seconds: 1.4)
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
}
