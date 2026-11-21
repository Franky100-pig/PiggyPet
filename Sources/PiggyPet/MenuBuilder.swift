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

        let strollItem = NSMenuItem(title: "到处逛逛", action: #selector(goStroll), keyEquivalent: "")
        strollItem.target = self
        menu.addItem(strollItem)

        let chaseItem = NSMenuItem(title: "追着鼠标", action: #selector(goChase), keyEquivalent: "")
        chaseItem.target = self
        menu.addItem(chaseItem)

        menu.addItem(NSMenuItem.separator())

        let tantrumItem = NSMenuItem(
            title: "调皮模式",
            action: #selector(toggleTantrum), keyEquivalent: ""
        )
        tantrumItem.target = self
        tantrumItem.state = Preferences.tantrumEnabled ? .on : .off
        menu.addItem(tantrumItem)

        let nudgeItem = NSMenuItem(title: "拱鼠标频率", action: nil, keyEquivalent: "")
        let nudgeMenu = NSMenu()
        for freq in NudgeFrequency.allCases {
            let freqItem = NSMenuItem(
                title: freq.title,
                action: #selector(setNudgeFrequency(_:)),
                keyEquivalent: ""
            )
            freqItem.target = self
            freqItem.representedObject = freq
            freqItem.state = freq == Preferences.nudgeFrequency ? .on : .off
            nudgeMenu.addItem(freqItem)
        }
        nudgeItem.submenu = nudgeMenu
        menu.addItem(nudgeItem)

        let bubbleItem = NSMenuItem(
            title: "气泡文字",
            action: #selector(toggleBubbles), keyEquivalent: ""
        )
        bubbleItem.target = self
        bubbleItem.state = Preferences.bubbleEnabled ? .on : .off
        menu.addItem(bubbleItem)

        let excitementItem = NSMenuItem(title: "兴奋程度", action: nil, keyEquivalent: "")
        let excitementMenu = NSMenu()
        for level in Excitement.allCases {
            let levelItem = NSMenuItem(
                title: level.title,
                action: #selector(setExcitement(_:)),
                keyEquivalent: ""
            )
            levelItem.target = self
            levelItem.representedObject = level
            levelItem.state = level == Preferences.excitement ? .on : .off
            excitementMenu.addItem(levelItem)
        }
        excitementItem.submenu = excitementMenu
        menu.addItem(excitementItem)

        let paceItem = NSMenuItem(title: "走路速度", action: nil, keyEquivalent: "")
        let paceMenu = NSMenu()
        for pace in WalkPace.allCases {
            let paceEntry = NSMenuItem(
                title: pace.title,
                action: #selector(setWalkPace(_:)),
                keyEquivalent: ""
            )
            paceEntry.target = self
            paceEntry.representedObject = pace
            paceEntry.state = pace == Preferences.walkPace ? .on : .off
            paceMenu.addItem(paceEntry)
        }
        paceItem.submenu = paceMenu
        menu.addItem(paceItem)

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

    @objc private func goStroll() {
        stateMachine?.startStroll()
    }

    @objc private func goChase() {
        // Explicit menu action: always poke the cursor, even with auto off.
        stateMachine?.startChase(force: true)
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

    @objc private func setExcitement(_ sender: NSMenuItem) {
        guard let level = sender.representedObject as? Excitement else { return }
        Preferences.setExcitement(level)
        stateMachine?.rescheduleStroll()
    }

    @objc private func setNudgeFrequency(_ sender: NSMenuItem) {
        guard let freq = sender.representedObject as? NudgeFrequency else { return }
        Preferences.setNudgeFrequency(freq)
    }

    @objc private func setWalkPace(_ sender: NSMenuItem) {
        guard let pace = sender.representedObject as? WalkPace else { return }
        Preferences.setWalkPace(pace)
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
