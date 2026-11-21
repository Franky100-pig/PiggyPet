import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: PetWindow?
    private var petView: PetView?
    private let stateMachine = PetStateMachine()
    private let menuBuilder = MenuBuilder()

    func applicationDidFinishLaunching(_ notification: Notification) {
        Preferences.register()

        let size = NSSize(width: 200, height: 240)
        let origin: NSPoint
        if let saved = Preferences.savedOrigin {
            origin = Geometry.clampWindowOrigin(saved, size: size)
        } else {
            origin = Geometry.bottomLeftOrigin(for: size)
        }

        let panel = PetWindow(contentRect: NSRect(origin: origin, size: size))
        let view = PetView(frame: NSRect(origin: .zero, size: size))
        panel.contentView = view
        petView = view

        view.stateMachine = stateMachine
        view.menuBuilder = menuBuilder
        stateMachine.view = view
        stateMachine.window = panel
        menuBuilder.stateMachine = stateMachine
        menuBuilder.window = panel

        panel.orderFrontRegardless()
        window = panel
        stateMachine.start()

        // Unplugging a display (or mirroring) can strand the pig outside the
        // new desktop. Pull it back as soon as the screens change instead of
        // waiting for the next launch.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screensChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )

        let debugEnabled = ProcessInfo.processInfo.environment["PIGGY_DEBUG"] == "1"
            || ProcessInfo.processInfo.arguments.contains("--debug")
        if debugEnabled {
            // Also mirror NSLog to a file: handy when the app is started with
            // `open` and the unified log is awkward to query.
            freopen("/tmp/piggy-debug.log", "a", stderr)
            DistributedNotificationCenter.default().addObserver(
                self,
                selector: #selector(debugNotification(_:)),
                name: NSNotification.Name("PiggyPetDebug"),
                object: nil
            )
        }

        // First launch turns launch-at-login on once. If that fails — the app is
        // sitting in a random folder, say — the flag stays unset so a later
        // launch can try again; either way the menu can switch it off, and that
        // choice is final because we never ask twice.
        if !Preferences.loginItemAsked {
            let enabled = LoginItem.setEnabled(true)
            if enabled || LoginItem.needsApproval {
                Preferences.setLoginItemAsked(true)
            }
            NSLog("[PiggyPet] login item bootstrap=%@", LoginItem.statusDescription)
            if LoginItem.needsApproval {
                stateMachine.flashBubble("请在系统设置里允许开机自启")
            }
        }
    }

    @objc private func screensChanged() {
        guard let window else { return }
        let current = window.frame.origin
        let safe = Geometry.clampWindowOrigin(current, size: window.frame.size)
        guard safe != current else { return }
        window.setFrameOrigin(safe)
        Preferences.saveOrigin(safe)
        NSLog("[PiggyPet] screen change: moved pet from %@ to %@",
              NSStringFromPoint(current), NSStringFromPoint(safe))
    }

    @objc private func debugNotification(_ note: Notification) {
        guard let action = note.object as? String else { return }
        switch action {
        case "move":
            let origin = NSPoint(x: 420, y: 280)
            window?.setFrameOrigin(origin)
            Preferences.saveOrigin(origin)
        case "menu":
            if let petView {
                menuBuilder.show(at: NSPoint(x: 60, y: 60), in: petView)
            }
        case "about":
            menuBuilder.showAbout()
        case "menutitles":
            NSLog("[PiggyPet] menu=%@", menuBuilder.titles().joined(separator: " | "))
        case "hittest":
            NSLog("[PiggyPet] hitTest body=%@ corner=%@",
                  petView?.hitTest(NSPoint(x: 100, y: 140)) != nil ? "hit" : "pass",
                  petView?.hitTest(NSPoint(x: 4, y: 4)) != nil ? "hit" : "pass")
        case "where":
            if let origin = window?.frame.origin {
                let body = NSPoint(
                    x: origin.x + PetView.spriteCenterOffset.x,
                    y: origin.y + PetView.spriteCenterOffset.y
                )
                let cursor = NSEvent.mouseLocation
                NSLog("[PiggyPet] window=%@ body=%@ cursor=%@ delta=(%.0f, %.0f)",
                      NSStringFromPoint(origin), NSStringFromPoint(body),
                      NSStringFromPoint(cursor),
                      body.x - cursor.x, body.y - cursor.y)
            }
        default:
            stateMachine.debugTrigger(action)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationWillTerminate(_ notification: Notification) {
        stateMachine.stop()
    }
}
