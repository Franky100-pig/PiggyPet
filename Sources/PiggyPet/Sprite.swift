import Foundation

struct Sprite: Decodable, Identifiable {
    enum Kind: String, Decodable {
        case image
        case text
    }

    let id: String
    let kind: Kind
    let file: String?
    let text: String?
    let original: String?
    let mood: String
    let bubble: String
}

struct Manifest: Decodable {
    let version: Int
    let spriteSize: Int
    let sleepId: String
    let sprites: [Sprite]
}
