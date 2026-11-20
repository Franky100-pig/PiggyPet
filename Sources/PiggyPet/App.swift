import AppKit

@main
@MainActor
struct PiggyPetApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        // accessory = no Dock icon, no main menu; the pet lives purely as a floating panel
        app.setActivationPolicy(.accessory)
        app.run()
    }
}
