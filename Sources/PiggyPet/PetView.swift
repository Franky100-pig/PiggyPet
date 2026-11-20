import AppKit

/// Placeholder drawing for phase 0; replaced by sprite rendering in phase 2.
@MainActor
final class PetView: NSView {
    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        NSColor.systemPink.withAlphaComponent(0.9).setFill()
        let body = NSRect(x: 30, y: 70, width: 140, height: 120)
        NSBezierPath(ovalIn: body).fill()
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13, weight: .medium),
            .foregroundColor: NSColor.white
        ]
        ("PiggyPet" as NSString).draw(
            at: NSPoint(x: 60, y: 118), withAttributes: attrs
        )
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
