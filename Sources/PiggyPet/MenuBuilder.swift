import AppKit

@MainActor
final class MenuBuilder: NSObject {
    weak var stateMachine: PetStateMachine?
    weak var window: PetWindow?

    func show(at point: NSPoint, in view: NSView) {
        let menu = NSMenu()

        let switchItem = NSMenuItem(title: "换个表情", action: #selector(switchSprite), keyEquivalent: "")
        switchItem.target = self
        menu.addItem(switchItem)

        let tantrumItem = NSMenuItem(
            title: "调皮模式",
            action: #selector(toggleTantrum), keyEquivalent: ""
        )
        tantrumItem.target = self
        tantrumItem.state = Preferences.tantrumEnabled ? .on : .off
        menu.addItem(tantrumItem)

        let bubbleItem = NSMenuItem(
            title: "气泡文字",
            action: #selector(toggleBubbles), keyEquivalent: ""
        )
        bubbleItem.target = self
        bubbleItem.state = Preferences.bubbleEnabled ? .on : .off
        menu.addItem(bubbleItem)

        let resetItem = NSMenuItem(title: "回到左下角", action: #selector(resetPosition), keyEquivalent: "")
        resetItem.target = self
        menu.addItem(resetItem)

        menu.addItem(NSMenuItem.separator())
        let quitItem = NSMenuItem(title: "退出 PiggyPet", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        menu.popUp(positioning: nil, at: point, in: view)
    }

    @objc private func switchSprite() {
        stateMachine?.handleTap()
    }

    @objc private func toggleTantrum() {
        Preferences.setTantrumEnabled(!Preferences.tantrumEnabled)
        if !Preferences.tantrumEnabled {
            stateMachine?.cancelTantrum()
        } else {
            stateMachine?.rescheduleTantrum()
        }
    }

    @objc private func toggleBubbles() {
        Preferences.setBubbleEnabled(!Preferences.bubbleEnabled)
        if !Preferences.bubbleEnabled {
            stateMachine?.clearBubble()
        }
    }

    @objc private func resetPosition() {
        guard let window else { return }
        window.setFrameOrigin(Geometry.bottomLeftOrigin(for: window.frame.size))
        Preferences.saveOrigin(window.frame.origin)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
