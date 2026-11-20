import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: PetWindow?

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
        panel.orderFrontRegardless()
        window = panel
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
