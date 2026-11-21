import AppKit

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

/// Mirrors an image horizontally (both source GIFs face left).
private func mirroredImage(_ image: NSImage) -> NSImage {
    let result = NSImage(size: image.size)
    result.lockFocus()
    let flip = NSAffineTransform()
    flip.translateX(by: image.size.width, yBy: 0)
    flip.scaleX(by: -1, yBy: 1)
    flip.concat()
    image.draw(at: .zero, from: NSRect(origin: .zero, size: image.size),
               operation: .sourceOver, fraction: 1)
    result.unlockFocus()
    return result
}

/// Which animation plays while the window moves.
enum WalkStyle {
    case trot  // normal walk cycle (猪溜达)
    case dash  // angry running pig (快跑猪), used while chasing the cursor
}

/// A loaded PNG sequence with left/right facing variants and alpha masks.
private struct FrameSet {
    var left: [NSImage] = []
    var right: [NSImage] = []
    var alphaReps: [NSBitmapImageRep] = []

    var isAvailable: Bool { !left.isEmpty }

    static func load(directory: String) -> FrameSet {
        guard let url = Bundle.main.resourceURL?.appendingPathComponent(directory),
              let files = try? FileManager.default.contentsOfDirectory(
                  at: url, includingPropertiesForKeys: nil
              ) else { return FrameSet() }

        let sorted = files
            .filter { $0.pathExtension.lowercased() == "png" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }

        var leftFrames: [NSImage] = []
        var rightFrames: [NSImage] = []
        var reps: [NSBitmapImageRep] = []
        for file in sorted {
            guard let image = NSImage(contentsOf: file) else { continue }
            leftFrames.append(image)
            rightFrames.append(mirroredImage(image))
            if let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                reps.append(NSBitmapImageRep(cgImage: cg))
            }
        }
        return FrameSet(left: leftFrames, right: rightFrames, alphaReps: reps)
    }

    func frames(facingRight: Bool) -> [NSImage] {
        facingRight ? right : left
    }
}

/// Loads the walk-cycle and running PNG sequences and caches left/right
/// facing variants. Both source GIFs show the pig facing left, so the
/// right-facing sets are horizontal mirrors generated at load time.
@MainActor
final class WalkCatalog {
    static let shared = WalkCatalog()

    private var trot = FrameSet()
    private var dash = FrameSet()

    var frameCount: Int { trot.left.count }
    var isAvailable: Bool { trot.isAvailable }
    var runAvailable: Bool { dash.isAvailable }

    private init() {
        trot = FrameSet.load(directory: "walk")
        dash = FrameSet.load(directory: "run")
    }

    func frames(style: WalkStyle, facingRight: Bool) -> [NSImage] {
        switch style {
        case .trot: return trot.frames(facingRight: facingRight)
        case .dash: return dash.frames(facingRight: facingRight)
        }
    }

    func alphaReps(style: WalkStyle) -> [NSBitmapImageRep] {
        switch style {
        case .trot: return trot.alphaReps
        case .dash: return dash.alphaReps
        }
    }
}
