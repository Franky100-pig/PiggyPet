import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: PetWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let size = NSSize(width: 200, height: 220)
        // visibleFrame excludes the Dock and menu bar, so this sits just above the Dock.
        let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1280, height: 800)
        let origin = NSPoint(x: screen.minX + 8, y: screen.minY + 8)
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
