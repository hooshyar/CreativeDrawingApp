//
//  Stamp.swift
//  CreativeDrawing
//
//  Stamps and stickers for kids to add to their drawings
//

import UIKit

/// A stamp that can be placed on the canvas
struct Stamp {
    let id: UUID
    let type: StampType
    var position: CGPoint
    var scale: CGFloat
    var rotation: CGFloat
    var color: UIColor?

    /// Custom sticker ID (if this is a custom sticker)
    var customStickerId: UUID?

    /// Cached custom sticker image (not persisted)
    var customImage: UIImage?

    /// Whether this is a custom sticker
    var isCustomSticker: Bool {
        return customStickerId != nil
    }

    init(type: StampType, position: CGPoint, scale: CGFloat = 1.0, rotation: CGFloat = 0, color: UIColor? = nil) {
        self.id = UUID()
        self.type = type
        self.position = position
        self.scale = scale
        self.rotation = rotation
        self.color = color
        self.customStickerId = nil
        self.customImage = nil
    }

    /// Initialize with existing ID (for deserialization)
    init(id: UUID, type: StampType, position: CGPoint, scale: CGFloat = 1.0, rotation: CGFloat = 0, color: UIColor? = nil) {
        self.id = id
        self.type = type
        self.position = position
        self.scale = scale
        self.rotation = rotation
        self.color = color
        self.customStickerId = nil
        self.customImage = nil
    }

    /// Initialize as a custom sticker
    init(customSticker: CustomSticker, position: CGPoint, scale: CGFloat = 1.0, rotation: CGFloat = 0) {
        self.id = UUID()
        self.type = .star // Default type, not used for custom stickers
        self.position = position
        self.scale = scale
        self.rotation = rotation
        self.color = nil
        self.customStickerId = customSticker.id
        self.customImage = customSticker.loadImage()
    }

    /// Initialize custom sticker with existing ID (for deserialization)
    init(id: UUID, customStickerId: UUID, position: CGPoint, scale: CGFloat = 1.0, rotation: CGFloat = 0) {
        self.id = id
        self.type = .star
        self.position = position
        self.scale = scale
        self.rotation = rotation
        self.color = nil
        self.customStickerId = customStickerId
        // Try to load the image
        if let sticker = CustomStickerManager.shared.customStickers.first(where: { $0.id == customStickerId }) {
            self.customImage = sticker.loadImage()
        } else {
            self.customImage = nil
        }
    }
}

/// Types of stamps available
enum StampType: String, CaseIterable {
    // Animals
    case cat = "cat.fill"
    case dog = "dog.fill"
    case bird = "bird.fill"
    case fish = "fish.fill"
    case butterfly = "butterfly.fill"
    case ladybug = "ladybug.fill"
    case ant = "ant.fill"
    case tortoise = "tortoise.fill"
    case hare = "hare.fill"
    case pawprint = "pawprint.fill"

    // Nature
    case sun = "sun.max.fill"
    case moon = "moon.fill"
    case star = "star.fill"
    case cloud = "cloud.fill"
    case rainbow = "rainbow"
    case snowflake = "snowflake"
    case flame = "flame.fill"
    case drop = "drop.fill"
    case leaf = "leaf.fill"
    case tree = "tree.fill"

    // Shapes
    case heart = "heart.fill"
    case starShape = "star.circle.fill"
    case circle = "circle.fill"
    case square = "square.fill"
    case triangle = "triangle.fill"
    case diamond = "diamond.fill"
    case hexagon = "hexagon.fill"
    case pentagon = "pentagon.fill"

    // Fun
    case smiley = "face.smiling.fill"
    case wink = "face.smiling"
    case balloon = "balloon.fill"
    case gift = "gift.fill"
    case crown = "crown.fill"
    case sparkles = "sparkles"
    case wand = "wand.and.stars"
    case party = "party.popper.fill"

    // Transport
    case car = "car.fill"
    case airplane = "airplane"
    case bicycle = "bicycle"

    // Food
    case apple = "applelogo"
    case carrot = "leaf.arrow.circlepath"

    var displayName: String {
        switch self {
        case .cat: return "Cat"
        case .dog: return "Dog"
        case .bird: return "Bird"
        case .fish: return "Fish"
        case .butterfly: return "Butterfly"
        case .ladybug: return "Ladybug"
        case .ant: return "Ant"
        case .tortoise: return "Turtle"
        case .hare: return "Bunny"
        case .pawprint: return "Paw"
        case .sun: return "Sun"
        case .moon: return "Moon"
        case .star: return "Star"
        case .cloud: return "Cloud"
        case .rainbow: return "Rainbow"
        case .snowflake: return "Snowflake"
        case .flame: return "Fire"
        case .drop: return "Drop"
        case .leaf: return "Leaf"
        case .tree: return "Tree"
        case .heart: return "Heart"
        case .starShape: return "Star"
        case .circle: return "Circle"
        case .square: return "Square"
        case .triangle: return "Triangle"
        case .diamond: return "Diamond"
        case .hexagon: return "Hexagon"
        case .pentagon: return "Pentagon"
        case .smiley: return "Smiley"
        case .wink: return "Wink"
        case .balloon: return "Balloon"
        case .gift: return "Gift"
        case .crown: return "Crown"
        case .sparkles: return "Sparkles"
        case .wand: return "Magic"
        case .party: return "Party"
        case .car: return "Car"
        case .airplane: return "Plane"
        case .bicycle: return "Bike"
        case .apple: return "Apple"
        case .carrot: return "Carrot"
        }
    }

    var category: StampCategory {
        switch self {
        case .cat, .dog, .bird, .fish, .butterfly, .ladybug, .ant, .tortoise, .hare, .pawprint:
            return .animals
        case .sun, .moon, .star, .cloud, .rainbow, .snowflake, .flame, .drop, .leaf, .tree:
            return .nature
        case .heart, .starShape, .circle, .square, .triangle, .diamond, .hexagon, .pentagon:
            return .shapes
        case .smiley, .wink, .balloon, .gift, .crown, .sparkles, .wand, .party:
            return .fun
        case .car, .airplane, .bicycle:
            return .transport
        case .apple, .carrot:
            return .food
        }
    }

    var defaultColor: UIColor {
        switch self {
        case .sun, .star, .starShape: return .systemYellow
        case .heart: return .systemRed
        case .leaf, .tree, .carrot: return .systemGreen
        case .cloud: return .systemGray
        case .moon: return .systemYellow
        case .drop: return .systemBlue
        case .flame: return .systemOrange
        case .snowflake: return .systemCyan
        case .smiley, .wink: return .systemYellow
        case .balloon, .gift, .party: return .systemPink
        case .crown: return .systemYellow
        default: return .systemPurple
        }
    }
}

enum StampCategory: String, CaseIterable {
    case animals = "Animals"
    case nature = "Nature"
    case shapes = "Shapes"
    case fun = "Fun"
    case transport = "Transport"
    case food = "Food"

    var icon: String {
        switch self {
        case .animals: return "pawprint.fill"
        case .nature: return "leaf.fill"
        case .shapes: return "square.on.circle"
        case .fun: return "face.smiling.fill"
        case .transport: return "car.fill"
        case .food: return "carrot.fill"
        }
    }

    var stamps: [StampType] {
        return StampType.allCases.filter { $0.category == self }
    }
}
