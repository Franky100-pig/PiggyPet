import AppKit

@MainActor
final class PetView: NSView {
    weak var stateMachine: PetStateMachine?
    weak var menuBuilder: MenuBuilder?

    private(set) var currentSprite: Sprite = AssetCatalog.shared.sleepSprite
    private var spriteImage: NSImage = AssetCatalog.shared.image(for: AssetCatalog.shared.sleepSprite)
    private var alphaRep: NSBitmapImageRep?

    private var walkFrames: [NSImage] = []
    private var walkReps: [NSBitmapImageRep] = []
    private var walkIndex = 0
    private var walkFacing = false
    private var walkStyle: WalkStyle = .trot
    private(set) var isWalking = false

    private var activeImage: NSImage {
        isWalking && walkIndex < walkFrames.count ? walkFrames[walkIndex] : spriteImage
    }
    private var activeRep: NSBitmapImageRep? {
        isWalking ? walkReps[safe: walkIndex] : alphaRep
    }

    private var bubbleText: String?
    private var zzzAlpha: CGFloat = 1
    private var shakeOffset: CGFloat = 0
    /// Slop for near-edge clicks so a few points of wobble never land on a
    /// transparent pixel and make the pet look unresponsive.
    private let hitTolerance: CGFloat = 6

    private var debugEnabled: Bool {
        ProcessInfo.processInfo.environment["PIGGY_DEBUG"] == "1"
            || ProcessInfo.processInfo.arguments.contains("--debug")
    }

    private let spriteSize = NSSize(width: 160, height: 160)
    private var spriteRect: NSRect {
        NSRect(x: 20 + shakeOffset, y: 64, width: spriteSize.width, height: spriteSize.height)
    }
    /// Sprite center in window coordinates (bottom-left origin). The view is
    /// flipped and the sprite rect is (20, 64, 160, 160) inside a 200x240 view,
    /// so the center sits at x=20+80, y=240-64-80.
    static let spriteCenterOffset = NSPoint(x: 100, y: 96)
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

    // MARK: - Walking animation

    func startWalking(facingRight: Bool, style: WalkStyle = .trot) {
        // A curved path is walked in one pass, but a turn swaps the frame set.
        // Keeping the index across that swap is what stops the legs from
        // restarting at pose 0 every time the pig turns around.
        if isWalking, walkStyle == style, !walkFrames.isEmpty {
            if walkFacing != facingRight {
                let catalog = WalkCatalog.shared
                walkFrames = catalog.frames(style: style, facingRight: facingRight)
                walkReps = catalog.alphaReps(style: style)
                walkFacing = facingRight
            }
            needsDisplay = true
            return
        }
        let catalog = WalkCatalog.shared
        let frames = catalog.frames(style: style, facingRight: facingRight)
        guard !frames.isEmpty else { return }
        walkFrames = frames
        walkReps = catalog.alphaReps(style: style)
        walkIndex = 0
        walkFacing = facingRight
        walkStyle = style
        isWalking = true
        zzzAlpha = 0
        bubbleText = nil
        needsDisplay = true
    }

    func advanceWalkFrame() {
        guard isWalking, !walkFrames.isEmpty else { return }
        walkIndex = (walkIndex + 1) % walkFrames.count
        if walkIndex == 0, debugEnabled {
            NSLog("[PiggyPet] walkCycle done frames=%d", walkFrames.count)
        }
        needsDisplay = true
    }

    func stopWalking() {
        isWalking = false
        walkFrames = []
        walkReps = []
        walkIndex = 0
        needsDisplay = true
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        NSGraphicsContext.current?.cgContext.clear(bounds)

        if zzzAlpha > 0 && !isWalking {
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 22, weight: .bold),
                .foregroundColor: NSColor.systemPink.withAlphaComponent(zzzAlpha),
            ]
            ("Zzz" as NSString).draw(at: NSPoint(x: 132, y: 42), withAttributes: attributes)
        }

        activeImage.draw(in: spriteRect)

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

    // MARK: - Pixel-accurate hit testing

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard super.hitTest(point) != nil else { return nil }
        if bubbleText != nil && bubbleRect.contains(point) { return self }

        let rect = spriteRect
        guard rect.contains(point), let rep = activeRep else { return nil }

        // The torso core is always clickable. A few memes have fully
        // transparent pixels in the middle (e.g. pig_0002); without this the
        // click passes through and even the right-click menu cannot be opened
        // to escape that sprite. Corners stay pixel-accurate for click-through.
        if rect.insetBy(dx: 40, dy: 40).contains(point) { return self }

        let scaleX = CGFloat(rep.pixelsWide) / rect.width
        let scaleY = CGFloat(rep.pixelsHigh) / rect.height
        let center = NSPoint(
            x: (point.x - rect.minX) * scaleX,
            y: (point.y - rect.minY) * scaleY
        )
        let step = hitTolerance * min(scaleX, scaleY) / 2
        for dx in [-step, 0, step] {
            for dy in [-step, 0, step] {
                let x = Int((center.x + dx).rounded())
                let y = Int((center.y + dy).rounded())
                guard x >= 0, x < rep.pixelsWide, y >= 0, y < rep.pixelsHigh else { continue }
                if let color = rep.colorAt(x: x, y: y), color.alphaComponent > 0.15 {
                    return self
                }
            }
        }
        return nil
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    // MARK: - Mouse interaction

    private var downPoint: NSPoint = .zero
    private var originAtDown: NSPoint = .zero
    private var didMoveWindow = false

    /// The window follows the cursor only beyond this dead zone, so a few
    /// points of hand jitter while clicking never nudges the pet.
    private let dragDeadZone: CGFloat = 8
    /// At mouseUp the NET displacement (down point -> release point) decides
    /// tap vs drag. This tolerates wobble that returns near the start.
    private let tapMaxNetDisplacement: CGFloat = 10

    override func mouseDown(with event: NSEvent) {
        downPoint = NSEvent.mouseLocation
        originAtDown = window?.frame.origin ?? .zero
        didMoveWindow = false
        stateMachine?.beginPointerInteraction()
    }

    override func mouseDragged(with event: NSEvent) {
        let current = NSEvent.mouseLocation
        let dx = current.x - downPoint.x
        let dy = current.y - downPoint.y
        if hypot(dx, dy) > dragDeadZone { didMoveWindow = true }
        guard didMoveWindow, let window else { return }
        let origin = NSPoint(x: originAtDown.x + dx, y: originAtDown.y + dy)
        window.setFrameOrigin(Geometry.clampWindowOrigin(origin, size: window.frame.size))
    }

    override func mouseUp(with event: NSEvent) {
        let release = NSEvent.mouseLocation
        let net = hypot(release.x - downPoint.x, release.y - downPoint.y)
        let wasTap = net <= tapMaxNetDisplacement

        if wasTap {
            // A jittery tap may have moved the window past the dead zone; put
            // it back so the pet never visibly jumps and position stays stable.
            if didMoveWindow { window?.setFrameOrigin(originAtDown) }
        } else if didMoveWindow, let window {
            Preferences.saveOrigin(window.frame.origin)
        }
        stateMachine?.endPointerInteraction(wasTap: wasTap)
    }

    override func rightMouseDown(with event: NSEvent) {
        menuBuilder?.show(at: event.locationInWindow, in: self)
    }
}
