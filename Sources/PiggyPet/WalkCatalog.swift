import AppKit

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

/// Loads the PNG walk-cycle sequence and caches left/right facing variants.
/// The source GIF shows the pig facing left, so the right-facing set is a
/// horizontal mirror generated at load time.
@MainActor
final class WalkCatalog {
    static let shared = WalkCatalog()

    private(set) var left: [NSImage] = []
    private(set) var right: [NSImage] = []
    private(set) var alphaReps: [NSBitmapImageRep] = []

    var frameCount: Int { left.count }
    var isAvailable: Bool { !left.isEmpty }

    private init() {
        guard let url = Bundle.main.resourceURL?.appendingPathComponent("walk"),
              let files = try? FileManager.default.contentsOfDirectory(
                  at: url, includingPropertiesForKeys: nil
              ) else { return }

        let sorted = files
            .filter { $0.pathExtension.lowercased() == "png" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }

        var leftFrames: [NSImage] = []
        var rightFrames: [NSImage] = []
        var reps: [NSBitmapImageRep] = []
        for file in sorted {
            guard let image = NSImage(contentsOf: file) else { continue }
            leftFrames.append(image)
            rightFrames.append(Self.mirrored(image))
            if let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                reps.append(NSBitmapImageRep(cgImage: cg))
            }
        }
        left = leftFrames
        right = rightFrames
        alphaReps = reps
    }

    func frames(facingRight: Bool) -> [NSImage] {
        facingRight ? right : left
    }

    private static func mirrored(_ image: NSImage) -> NSImage {
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
}
