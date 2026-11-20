import AppKit

/// Decodes the generated manifest and lazily loads/caches sprite images.
@MainActor
final class AssetCatalog {
    static let shared = AssetCatalog()

    let manifest: Manifest
    private var images: [String: NSImage] = [:]

    private init() {
        if let url = Bundle.main.url(forResource: "manifest", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode(Manifest.self, from: data) {
            manifest = decoded
        } else {
            let fallback = Sprite(
                id: "fallback",
                kind: .text,
                file: nil,
                text: "猪",
                original: nil,
                mood: "neutral",
                bubble: "还在准备表情包…"
            )
            manifest = Manifest(
                version: 1,
                spriteSize: 160,
                sleepId: "fallback",
                sprites: [fallback]
            )
        }
    }

    var sleepSprite: Sprite {
        manifest.sprites.first { $0.id == manifest.sleepId }
            ?? manifest.sprites.first
            ?? fallbackSprite
    }

    private var fallbackSprite: Sprite {
        Sprite(id: "fallback", kind: .text, file: nil, text: "猪",
               original: nil, mood: "neutral", bubble: "…")
    }

    func random(except id: String? = nil, mood: String? = nil) -> Sprite {
        var pool = manifest.sprites.filter { $0.id != id }
        if let mood {
            let narrowed = pool.filter { $0.mood == mood }
            if !narrowed.isEmpty { pool = narrowed }
        }
        return pool.randomElement() ?? sleepSprite
    }

    func angrySprite() -> Sprite {
        let pool = manifest.sprites.filter { $0.mood == "angry" }
        return pool.randomElement() ?? random()
    }

    func image(for sprite: Sprite) -> NSImage {
        if let cached = images[sprite.id] { return cached }
        let image: NSImage
        if sprite.kind == .image, let file = sprite.file,
           let url = Bundle.main.resourceURL?.appendingPathComponent(file),
           let loaded = NSImage(contentsOf: url) {
            image = loaded
        } else {
            image = renderText(sprite.text ?? "猪")
        }
        images[sprite.id] = image
        return image
    }

    private func renderText(_ text: String) -> NSImage {
        let size = NSSize(width: 160, height: 160)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.clear.setFill()
        NSRect(origin: .zero, size: size).fill()

        let style = NSMutableParagraphStyle()
        style.alignment = .center
        style.lineBreakMode = .byWordWrapping
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 34, weight: .heavy),
            .foregroundColor: NSColor.systemPink,
            .strokeColor: NSColor(calibratedWhite: 0.18, alpha: 1),
            .strokeWidth: -3.0,
            .paragraphStyle: style,
        ]
        (text as NSString).draw(
            in: NSRect(x: 2, y: 42, width: 156, height: 76),
            withAttributes: attributes
        )
        image.unlockFocus()
        return image
    }
}
