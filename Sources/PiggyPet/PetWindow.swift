import AppKit

/// Borderless, transparent, non-activating floating panel that hosts the pet.
@MainActor
final class PetWindow: NSPanel {
    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        isMovableByWindowBackground = false
        hidesOnDeactivate = false
        worksWhenModal = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // Needed together with PetView.acceptsFirstMouse for the first click to register.
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
