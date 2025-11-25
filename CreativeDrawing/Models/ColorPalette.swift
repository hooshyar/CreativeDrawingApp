//
//  ColorPalette.swift
//  CreativeDrawing
//
//  Kid-friendly color palettes
//

import UIKit

/// Pre-defined kid-friendly color palettes
struct ColorPalette {

    /// Rainbow colors - the main palette for kids
    static let rainbow: [UIColor] = [
        UIColor(red: 1.00, green: 0.23, blue: 0.19, alpha: 1), // Red
        UIColor(red: 1.00, green: 0.58, blue: 0.00, alpha: 1), // Orange
        UIColor(red: 1.00, green: 0.92, blue: 0.23, alpha: 1), // Yellow
        UIColor(red: 0.30, green: 0.85, blue: 0.39, alpha: 1), // Green
        UIColor(red: 0.20, green: 0.67, blue: 0.86, alpha: 1), // Light Blue
        UIColor(red: 0.35, green: 0.34, blue: 0.84, alpha: 1), // Blue
        UIColor(red: 0.69, green: 0.32, blue: 0.87, alpha: 1), // Purple
        UIColor(red: 1.00, green: 0.40, blue: 0.60, alpha: 1), // Pink
    ]

    /// Extended palette with more variety
    static let extended: [UIColor] = rainbow + [
        UIColor(red: 0.55, green: 0.27, blue: 0.07, alpha: 1), // Brown
        UIColor(red: 0.60, green: 0.60, blue: 0.60, alpha: 1), // Gray
        UIColor(red: 0.00, green: 0.00, blue: 0.00, alpha: 1), // Black
        UIColor(red: 1.00, green: 1.00, blue: 1.00, alpha: 1), // White
    ]

    /// Pastel colors - softer shades
    static let pastel: [UIColor] = [
        UIColor(red: 1.00, green: 0.71, blue: 0.76, alpha: 1), // Pink
        UIColor(red: 1.00, green: 0.85, blue: 0.73, alpha: 1), // Peach
        UIColor(red: 1.00, green: 1.00, blue: 0.80, alpha: 1), // Light Yellow
        UIColor(red: 0.75, green: 1.00, blue: 0.80, alpha: 1), // Mint
        UIColor(red: 0.75, green: 0.90, blue: 1.00, alpha: 1), // Sky Blue
        UIColor(red: 0.85, green: 0.75, blue: 1.00, alpha: 1), // Lavender
        UIColor(red: 1.00, green: 0.80, blue: 0.90, alpha: 1), // Rose
        UIColor(red: 0.90, green: 0.95, blue: 1.00, alpha: 1), // Ice
    ]

    /// Neon colors - bright and fun
    static let neon: [UIColor] = [
        UIColor(red: 1.00, green: 0.07, blue: 0.58, alpha: 1), // Neon Pink
        UIColor(red: 0.00, green: 1.00, blue: 0.00, alpha: 1), // Neon Green
        UIColor(red: 0.00, green: 1.00, blue: 1.00, alpha: 1), // Cyan
        UIColor(red: 1.00, green: 1.00, blue: 0.00, alpha: 1), // Neon Yellow
        UIColor(red: 1.00, green: 0.50, blue: 0.00, alpha: 1), // Neon Orange
        UIColor(red: 0.75, green: 0.00, blue: 1.00, alpha: 1), // Neon Purple
        UIColor(red: 0.00, green: 0.50, blue: 1.00, alpha: 1), // Electric Blue
        UIColor(red: 1.00, green: 0.00, blue: 0.25, alpha: 1), // Hot Red
    ]

    /// Nature colors - earthy tones
    static let nature: [UIColor] = [
        UIColor(red: 0.13, green: 0.55, blue: 0.13, alpha: 1), // Forest Green
        UIColor(red: 0.54, green: 0.27, blue: 0.07, alpha: 1), // Saddle Brown
        UIColor(red: 0.13, green: 0.70, blue: 0.67, alpha: 1), // Teal
        UIColor(red: 0.96, green: 0.87, blue: 0.70, alpha: 1), // Wheat
        UIColor(red: 0.00, green: 0.39, blue: 0.00, alpha: 1), // Dark Green
        UIColor(red: 0.82, green: 0.41, blue: 0.12, alpha: 1), // Chocolate
        UIColor(red: 0.25, green: 0.88, blue: 0.82, alpha: 1), // Turquoise
        UIColor(red: 0.94, green: 0.90, blue: 0.55, alpha: 1), // Khaki
    ]

    /// All available palette types
    enum PaletteType: String, CaseIterable {
        case rainbow = "Rainbow"
        case extended = "All Colors"
        case pastel = "Pastel"
        case neon = "Neon"
        case nature = "Nature"

        var colors: [UIColor] {
            switch self {
            case .rainbow: return ColorPalette.rainbow
            case .extended: return ColorPalette.extended
            case .pastel: return ColorPalette.pastel
            case .neon: return ColorPalette.neon
            case .nature: return ColorPalette.nature
            }
        }

        var icon: String {
            switch self {
            case .rainbow: return "rainbow"
            case .extended: return "circle.grid.3x3.fill"
            case .pastel: return "cloud.fill"
            case .neon: return "bolt.fill"
            case .nature: return "leaf.fill"
            }
        }
    }

    /// Generate rainbow colors for the rainbow brush
    static func rainbowGradientColors(count: Int) -> [UIColor] {
        var colors: [UIColor] = []
        for i in 0..<count {
            let hue = CGFloat(i) / CGFloat(count)
            colors.append(UIColor(hue: hue, saturation: 1.0, brightness: 1.0, alpha: 1.0))
        }
        return colors
    }

    /// Get a color name for accessibility
    static func colorName(for color: UIColor) -> String {
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0

        color.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)

        // Handle grayscale
        if saturation < 0.1 {
            if brightness < 0.2 { return "Black" }
            if brightness > 0.9 { return "White" }
            return "Gray"
        }

        // Map hue to color name
        let hueAngle = hue * 360
        switch hueAngle {
        case 0..<15, 345...360: return "Red"
        case 15..<45: return "Orange"
        case 45..<75: return "Yellow"
        case 75..<150: return "Green"
        case 150..<195: return "Cyan"
        case 195..<255: return "Blue"
        case 255..<285: return "Purple"
        case 285..<345: return "Pink"
        default: return "Color"
        }
    }
}

// MARK: - UIColor Extensions

extension UIColor {
    /// Create a lighter version of this color
    func lighter(by percentage: CGFloat = 0.3) -> UIColor {
        return adjust(by: abs(percentage))
    }

    /// Create a darker version of this color
    func darker(by percentage: CGFloat = 0.3) -> UIColor {
        return adjust(by: -abs(percentage))
    }

    private func adjust(by percentage: CGFloat) -> UIColor {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        self.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        return UIColor(
            red: min(red + percentage, 1.0),
            green: min(green + percentage, 1.0),
            blue: min(blue + percentage, 1.0),
            alpha: alpha
        )
    }

    /// Get contrasting text color (black or white)
    var contrastingTextColor: UIColor {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        self.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        // Calculate luminance
        let luminance = 0.299 * red + 0.587 * green + 0.114 * blue
        return luminance > 0.5 ? .black : .white
    }
}
