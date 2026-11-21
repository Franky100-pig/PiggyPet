import AppKit

@MainActor
final class MenuBuilder: NSObject {
    weak var stateMachine: PetStateMachine?
    weak var window: PetWindow?

    func show(at point: NSPoint, in view: NSView) {
        makeMenu().popUp(positioning: nil, at: point, in: view)
    }

    /// Menu titles in order, separators included as `---`. Used by the debug
    /// hook so the structure can be checked without driving the UI by hand.
    func titles() -> [String] {
        makeMenu().items.map { $0.isSeparatorItem ? "---" : $0.title }
    }

    private func makeMenu() -> NSMenu {
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

        let loginItemEntry = NSMenuItem(
            title: "开机自启",
            action: #selector(toggleLoginItem), keyEquivalent: ""
        )
        loginItemEntry.target = self
        // Read live from the system, so switching it off in System Settings is
        // reflected here instead of showing a stale check mark.
        loginItemEntry.state = LoginItem.isEnabled ? .on : .off
        menu.addItem(loginItemEntry)

        let resetItem = NSMenuItem(title: "回到左下角", action: #selector(resetPosition), keyEquivalent: "")
        resetItem.target = self
        menu.addItem(resetItem)

        menu.addItem(NSMenuItem.separator())
        let aboutItem = NSMenuItem(title: "关于 PiggyPet", action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)
        let quitItem = NSMenuItem(title: "退出 PiggyPet", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        return menu
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

    @objc private func toggleLoginItem() {
        let turnOn = !LoginItem.isEnabled
        let enabled = LoginItem.setEnabled(turnOn)
        // A manual decision sticks: the launch-time bootstrap must not re-enable
        // it behind the user's back after they switch it off here.
        Preferences.setLoginItemAsked(true)
        guard turnOn, !enabled else { return }
        // Registering can land in "requires approval" on macOS 13+, in which
        // case the user has to allow it once in System Settings.
        stateMachine?.flashBubble(LoginItem.needsApproval
            ? "请在系统设置里允许开机自启"
            : "开机自启没设上，稍后再试")
    }

    @objc private func resetPosition() {
        guard let window else { return }
        window.setFrameOrigin(Geometry.bottomLeftOrigin(for: window.frame.size))
        Preferences.saveOrigin(window.frame.origin)
    }

    @objc func showAbout() {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "PiggyPet \(version)"
        alert.informativeText = """
        build \(build)

        一只住在桌面上的小猪。左键换表情，拖拽搬家，右键打开菜单。
        开机自启可以在菜单里随时关掉。

        github.com/Franky100-pig/PiggyPet
        """
        alert.addButton(withTitle: "好")
        alert.addButton(withTitle: "打开项目主页")
        // The pet panel floats above normal windows, so a plain alert would end
        // up behind the pig. Match the panel's level.
        alert.window.level = .floating
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertSecondButtonReturn,
           let url = URL(string: "https://github.com/Franky100-pig/PiggyPet") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
