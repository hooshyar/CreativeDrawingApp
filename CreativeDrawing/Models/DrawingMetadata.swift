//
//  DrawingMetadata.swift
//  CreativeDrawing
//
//  Metadata for saved drawings - name, dates, thumbnail info
//

import UIKit

/// Represents metadata for a saved drawing
struct DrawingMetadata: Codable, Identifiable {
    /// Unique identifier for the drawing
    let id: UUID

    /// User-given name for the drawing (or auto-generated)
    var name: String

    /// When the drawing was first created
    let createdAt: Date

    /// When the drawing was last modified
    var modifiedAt: Date

    /// Thumbnail image data (JPEG compressed)
    var thumbnailData: Data?

    /// Number of strokes in the drawing
    var strokeCount: Int

    /// Number of stamps in the drawing
    var stampCount: Int

    /// Background color stored as hex string
    var backgroundColorHex: String

    /// File name for the drawing data
    var fileName: String {
        return "\(id.uuidString).drawing"
    }

    /// File name for the thumbnail
    var thumbnailFileName: String {
        return "\(id.uuidString).thumb.jpg"
    }

    init(
        id: UUID = UUID(),
        name: String? = nil,
        createdAt: Date = Date(),
        modifiedAt: Date = Date(),
        thumbnailData: Data? = nil,
        strokeCount: Int = 0,
        stampCount: Int = 0,
        backgroundColorHex: String = "#FFFFFF"
    ) {
        self.id = id
        self.name = name ?? DrawingMetadata.generateName(for: createdAt)
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.thumbnailData = thumbnailData
        self.strokeCount = strokeCount
        self.stampCount = stampCount
        self.backgroundColorHex = backgroundColorHex
    }

    /// Generate a fun name based on date/time
    static func generateName(for date: Date) -> String {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)

        let timeOfDay: String
        switch hour {
        case 5..<12:
            timeOfDay = "Morning"
        case 12..<17:
            timeOfDay = "Afternoon"
        case 17..<21:
            timeOfDay = "Evening"
        default:
            timeOfDay = "Night"
        }

        let adjectives = ["Happy", "Colorful", "Magic", "Sparkly", "Rainbow", "Sunny", "Dreamy", "Fun", "Creative", "Amazing"]
        let nouns = ["Drawing", "Art", "Creation", "Masterpiece", "Picture", "Doodle"]

        let adjective = adjectives.randomElement() ?? "Happy"
        let noun = nouns.randomElement() ?? "Drawing"

        return "\(timeOfDay) \(adjective) \(noun)"
    }

    /// Get thumbnail as UIImage
    var thumbnail: UIImage? {
        guard let data = thumbnailData else { return nil }
        return UIImage(data: data)
    }

    /// Create thumbnail from full image
    mutating func setThumbnail(from image: UIImage, maxSize: CGFloat = 200) {
        let scale = min(maxSize / image.size.width, maxSize / image.size.height)
        let newSize = CGSize(
            width: image.size.width * scale,
            height: image.size.height * scale
        )

        let renderer = UIGraphicsImageRenderer(size: newSize)
        let thumbnail = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }

        thumbnailData = thumbnail.jpegData(compressionQuality: 0.7)
    }

    /// Formatted creation date
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: createdAt)
    }

    /// Short date for display
    var shortDate: String {
        let formatter = DateFormatter()
        let calendar = Calendar.current

        if calendar.isDateInToday(createdAt) {
            formatter.dateFormat = "'Today'"
        } else if calendar.isDateInYesterday(createdAt) {
            formatter.dateFormat = "'Yesterday'"
        } else {
            formatter.dateFormat = "MMM d"
        }

        return formatter.string(from: createdAt)
    }
}

// MARK: - Color Hex Extension

extension UIColor {
    /// Convert UIColor to hex string
    var hexString: String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }

    /// Create UIColor from hex string
    convenience init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        guard hexSanitized.count == 6 else { return nil }

        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)

        self.init(
            red: CGFloat((rgb & 0xFF0000) >> 16) / 255.0,
            green: CGFloat((rgb & 0x00FF00) >> 8) / 255.0,
            blue: CGFloat(rgb & 0x0000FF) / 255.0,
            alpha: 1.0
        )
    }
}
