import AppKit

@MainActor
final class PetView: NSView {
    private(set) var currentSprite: Sprite = AssetCatalog.shared.sleepSprite
    private var spriteImage: NSImage = AssetCatalog.shared.image(for: AssetCatalog.shared.sleepSprite)
    private var alphaRep: NSBitmapImageRep?

    private var bubbleText: String?
    private var zzzAlpha: CGFloat = 1
    private var shakeOffset: CGFloat = 0

    private let spriteSize = NSSize(width: 160, height: 160)
    private var spriteRect: NSRect {
        NSRect(x: 20 + shakeOffset, y: 64, width: spriteSize.width, height: spriteSize.height)
    }
    private let bubbleRect = NSRect(x: 14, y: 12, width: 172, height: 44)

    override var isFlipped: Bool { true }

    func show(_ sprite: Sprite) {
        currentSprite = sprite
        spriteImage = AssetCatalog.shared.image(for: sprite)
        alphaRep = NSBitmapImageRep(cgImage: spriteImage.cgImage(
            forProposedRect: nil, context: nil, hints: nil
        )!)
        needsDisplay = true
    }

    func setBubble(_ text: String?) {
        bubbleText = text
        needsDisplay = true
    }

    func setZzz(_ alpha: CGFloat) {
        zzzAlpha = alpha
        needsDisplay = true
    }

    func shake() {
        for (delay, offset) in [(0.0, -4.0), (0.08, 4.0), (0.16, -3.0), (0.24, 0.0)] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.shakeOffset = offset
                self?.needsDisplay = true
            }
        }
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        NSGraphicsContext.current?.cgContext.clear(bounds)

        if zzzAlpha > 0 {
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 22, weight: .bold),
                .foregroundColor: NSColor.systemPink.withAlphaComponent(zzzAlpha),
            ]
            ("Zzz" as NSString).draw(at: NSPoint(x: 132, y: 42), withAttributes: attributes)
        }

        spriteImage.draw(in: spriteRect)

        if let bubbleText {
            drawBubble(bubbleText)
        }
    }

    private func drawBubble(_ text: String) {
        let path = NSBezierPath(roundedRect: bubbleRect, xRadius: 12, yRadius: 12)
        NSColor.controlBackgroundColor.withAlphaComponent(0.96).setFill()
        path.fill()
        NSColor.separatorColor.setStroke()
        path.lineWidth = 1
        path.stroke()

        let tail = NSBezierPath()
        tail.move(to: NSPoint(x: bubbleRect.midX - 7, y: bubbleRect.maxY - 1))
        tail.line(to: NSPoint(x: bubbleRect.midX, y: bubbleRect.maxY + 9))
        tail.line(to: NSPoint(x: bubbleRect.midX + 7, y: bubbleRect.maxY - 1))
        tail.close()
        NSColor.controlBackgroundColor.withAlphaComponent(0.96).setFill()
        tail.fill()

        let style = NSMutableParagraphStyle()
        style.alignment = .center
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 14),
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: style,
        ]
        (text as NSString).draw(in: bubbleRect.insetBy(dx: 8, dy: 6), withAttributes: attributes)
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
