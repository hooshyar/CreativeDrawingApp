//
//  ColorPalette.swift
//  CreativeDrawing
//
//  Kid-friendly color palettes
//

import UIKit

/// Pre-defined kid-friendly color palettes
struct ColorPalette {

    /// Rainbow colors - the main palette for kids (expanded with essential colors)
    static let rainbow: [UIColor] = [
        // Spectrum colors
        UIColor(red: 1.00, green: 0.23, blue: 0.19, alpha: 1), // Red
        UIColor(red: 1.00, green: 0.58, blue: 0.00, alpha: 1), // Orange
        UIColor(red: 1.00, green: 0.92, blue: 0.23, alpha: 1), // Yellow
        UIColor(red: 0.65, green: 0.90, blue: 0.20, alpha: 1), // Lime Green
        UIColor(red: 0.30, green: 0.85, blue: 0.39, alpha: 1), // Green
        UIColor(red: 0.00, green: 0.80, blue: 0.80, alpha: 1), // Teal
        UIColor(red: 0.20, green: 0.67, blue: 0.86, alpha: 1), // Light Blue
        UIColor(red: 0.35, green: 0.34, blue: 0.84, alpha: 1), // Blue
        UIColor(red: 0.50, green: 0.30, blue: 0.90, alpha: 1), // Indigo
        UIColor(red: 0.69, green: 0.32, blue: 0.87, alpha: 1), // Purple
        UIColor(red: 1.00, green: 0.40, blue: 0.60, alpha: 1), // Pink
        UIColor(red: 1.00, green: 0.08, blue: 0.58, alpha: 1), // Hot Pink
        // Essential colors for drawing people, animals, nature
        UIColor(red: 0.55, green: 0.27, blue: 0.07, alpha: 1), // Brown
        UIColor(red: 0.96, green: 0.87, blue: 0.70, alpha: 1), // Skin Light
        UIColor(red: 0.82, green: 0.64, blue: 0.52, alpha: 1), // Skin Medium
        UIColor(red: 0.62, green: 0.44, blue: 0.32, alpha: 1), // Skin Dark
        UIColor(red: 0.00, green: 0.00, blue: 0.00, alpha: 1), // Black
        UIColor(red: 1.00, green: 1.00, blue: 1.00, alpha: 1), // White
    ]

    /// Extended palette with lots of variety - 32 colors!
    static let extended: [UIColor] = [
        // Core colors
        UIColor(red: 1.00, green: 0.23, blue: 0.19, alpha: 1), // Red
        UIColor(red: 0.86, green: 0.08, blue: 0.24, alpha: 1), // Crimson
        UIColor(red: 1.00, green: 0.58, blue: 0.00, alpha: 1), // Orange
        UIColor(red: 1.00, green: 0.75, blue: 0.30, alpha: 1), // Tangerine
        UIColor(red: 1.00, green: 0.92, blue: 0.23, alpha: 1), // Yellow
        UIColor(red: 1.00, green: 0.84, blue: 0.00, alpha: 1), // Gold
        UIColor(red: 0.65, green: 0.90, blue: 0.20, alpha: 1), // Lime
        UIColor(red: 0.30, green: 0.85, blue: 0.39, alpha: 1), // Green
        UIColor(red: 0.00, green: 0.50, blue: 0.25, alpha: 1), // Emerald
        UIColor(red: 0.00, green: 0.39, blue: 0.00, alpha: 1), // Forest Green
        UIColor(red: 0.00, green: 0.80, blue: 0.80, alpha: 1), // Teal
        UIColor(red: 0.25, green: 0.88, blue: 0.82, alpha: 1), // Turquoise
        UIColor(red: 0.00, green: 0.75, blue: 1.00, alpha: 1), // Cyan
        UIColor(red: 0.20, green: 0.67, blue: 0.86, alpha: 1), // Sky Blue
        UIColor(red: 0.35, green: 0.34, blue: 0.84, alpha: 1), // Blue
        UIColor(red: 0.10, green: 0.10, blue: 0.60, alpha: 1), // Navy
        UIColor(red: 0.50, green: 0.30, blue: 0.90, alpha: 1), // Indigo
        UIColor(red: 0.69, green: 0.32, blue: 0.87, alpha: 1), // Purple
        UIColor(red: 0.50, green: 0.00, blue: 0.50, alpha: 1), // Deep Purple
        UIColor(red: 1.00, green: 0.40, blue: 0.60, alpha: 1), // Pink
        UIColor(red: 1.00, green: 0.08, blue: 0.58, alpha: 1), // Hot Pink
        UIColor(red: 0.80, green: 0.30, blue: 0.50, alpha: 1), // Rose
        // Earthy & Skin tones
        UIColor(red: 0.55, green: 0.27, blue: 0.07, alpha: 1), // Brown
        UIColor(red: 0.82, green: 0.41, blue: 0.12, alpha: 1), // Chocolate
        UIColor(red: 0.96, green: 0.87, blue: 0.70, alpha: 1), // Tan/Skin Light
        UIColor(red: 0.82, green: 0.64, blue: 0.52, alpha: 1), // Skin Medium
        UIColor(red: 0.62, green: 0.44, blue: 0.32, alpha: 1), // Skin Dark
        // Neutrals
        UIColor(red: 0.00, green: 0.00, blue: 0.00, alpha: 1), // Black
        UIColor(red: 0.35, green: 0.35, blue: 0.35, alpha: 1), // Dark Gray
        UIColor(red: 0.60, green: 0.60, blue: 0.60, alpha: 1), // Gray
        UIColor(red: 0.85, green: 0.85, blue: 0.85, alpha: 1), // Light Gray
        UIColor(red: 1.00, green: 1.00, blue: 1.00, alpha: 1), // White
    ]

    /// Sparkle colors - shiny metallic and glitter effects (expanded)
    static let sparkle: [UIColor] = [
        UIColor(red: 1.00, green: 0.84, blue: 0.00, alpha: 1), // Gold
        UIColor(red: 0.85, green: 0.65, blue: 0.13, alpha: 1), // Goldenrod
        UIColor(red: 0.75, green: 0.75, blue: 0.75, alpha: 1), // Silver
        UIColor(red: 0.90, green: 0.90, blue: 0.95, alpha: 1), // Platinum
        UIColor(red: 0.72, green: 0.45, blue: 0.20, alpha: 1), // Bronze/Copper
        UIColor(red: 0.80, green: 0.50, blue: 0.20, alpha: 1), // Rose Gold
        UIColor(red: 0.94, green: 0.90, blue: 0.55, alpha: 1), // Champagne
        UIColor(red: 0.69, green: 0.88, blue: 0.90, alpha: 1), // Ice Blue Shimmer
        UIColor(red: 0.80, green: 0.95, blue: 1.00, alpha: 1), // Diamond Blue
        UIColor(red: 1.00, green: 0.41, blue: 0.71, alpha: 1), // Hot Pink Glitter
        UIColor(red: 1.00, green: 0.60, blue: 0.80, alpha: 1), // Pink Sparkle
        UIColor(red: 0.50, green: 1.00, blue: 0.83, alpha: 1), // Aquamarine
        UIColor(red: 0.85, green: 0.65, blue: 1.00, alpha: 1), // Lavender Shimmer
        UIColor(red: 0.60, green: 0.80, blue: 0.90, alpha: 1), // Opal Blue
        UIColor(red: 0.70, green: 1.00, blue: 0.70, alpha: 1), // Peridot Green
        UIColor(red: 1.00, green: 0.85, blue: 0.85, alpha: 1), // Pearl Pink
    ]

    /// Pastel colors - soft and dreamy (expanded)
    static let pastel: [UIColor] = [
        UIColor(red: 1.00, green: 0.71, blue: 0.76, alpha: 1), // Pink
        UIColor(red: 1.00, green: 0.80, blue: 0.90, alpha: 1), // Rose
        UIColor(red: 1.00, green: 0.80, blue: 0.80, alpha: 1), // Blush
        UIColor(red: 1.00, green: 0.85, blue: 0.73, alpha: 1), // Peach
        UIColor(red: 1.00, green: 0.90, blue: 0.70, alpha: 1), // Apricot
        UIColor(red: 1.00, green: 1.00, blue: 0.80, alpha: 1), // Light Yellow
        UIColor(red: 0.95, green: 1.00, blue: 0.75, alpha: 1), // Butter
        UIColor(red: 0.85, green: 1.00, blue: 0.75, alpha: 1), // Light Lime
        UIColor(red: 0.75, green: 1.00, blue: 0.80, alpha: 1), // Mint
        UIColor(red: 0.70, green: 1.00, blue: 0.90, alpha: 1), // Seafoam
        UIColor(red: 0.75, green: 0.95, blue: 1.00, alpha: 1), // Aqua
        UIColor(red: 0.75, green: 0.90, blue: 1.00, alpha: 1), // Sky Blue
        UIColor(red: 0.80, green: 0.80, blue: 1.00, alpha: 1), // Periwinkle
        UIColor(red: 0.85, green: 0.75, blue: 1.00, alpha: 1), // Lavender
        UIColor(red: 0.95, green: 0.80, blue: 1.00, alpha: 1), // Lilac
        UIColor(red: 0.90, green: 0.95, blue: 1.00, alpha: 1), // Ice
    ]

    /// Neon colors - super bright and fun! 16 colors
    static let neon: [UIColor] = [
        UIColor(red: 1.00, green: 0.00, blue: 0.25, alpha: 1), // Hot Red
        UIColor(red: 1.00, green: 0.00, blue: 0.50, alpha: 1), // Neon Red-Pink
        UIColor(red: 1.00, green: 0.07, blue: 0.58, alpha: 1), // Neon Pink
        UIColor(red: 1.00, green: 0.00, blue: 1.00, alpha: 1), // Magenta
        UIColor(red: 0.75, green: 0.00, blue: 1.00, alpha: 1), // Neon Purple
        UIColor(red: 0.50, green: 0.00, blue: 1.00, alpha: 1), // Electric Violet
        UIColor(red: 0.25, green: 0.25, blue: 1.00, alpha: 1), // Neon Blue
        UIColor(red: 0.00, green: 0.50, blue: 1.00, alpha: 1), // Electric Blue
        UIColor(red: 0.00, green: 1.00, blue: 1.00, alpha: 1), // Cyan
        UIColor(red: 0.00, green: 1.00, blue: 0.75, alpha: 1), // Aqua
        UIColor(red: 0.00, green: 1.00, blue: 0.50, alpha: 1), // Spring Green
        UIColor(red: 0.00, green: 1.00, blue: 0.00, alpha: 1), // Neon Green
        UIColor(red: 0.50, green: 1.00, blue: 0.00, alpha: 1), // Lime
        UIColor(red: 0.80, green: 1.00, blue: 0.00, alpha: 1), // Chartreuse
        UIColor(red: 1.00, green: 1.00, blue: 0.00, alpha: 1), // Neon Yellow
        UIColor(red: 1.00, green: 0.50, blue: 0.00, alpha: 1), // Neon Orange
    ]

    /// Nature colors - earthy and organic tones (expanded)
    static let nature: [UIColor] = [
        UIColor(red: 0.00, green: 0.39, blue: 0.00, alpha: 1), // Dark Green
        UIColor(red: 0.13, green: 0.55, blue: 0.13, alpha: 1), // Forest Green
        UIColor(red: 0.33, green: 0.42, blue: 0.18, alpha: 1), // Olive
        UIColor(red: 0.56, green: 0.74, blue: 0.56, alpha: 1), // Sage
        UIColor(red: 0.13, green: 0.70, blue: 0.67, alpha: 1), // Teal
        UIColor(red: 0.25, green: 0.88, blue: 0.82, alpha: 1), // Turquoise
        UIColor(red: 0.40, green: 0.60, blue: 0.80, alpha: 1), // Ocean Blue
        UIColor(red: 0.68, green: 0.85, blue: 0.90, alpha: 1), // Sky
        UIColor(red: 0.36, green: 0.25, blue: 0.20, alpha: 1), // Dark Brown
        UIColor(red: 0.54, green: 0.27, blue: 0.07, alpha: 1), // Saddle Brown
        UIColor(red: 0.82, green: 0.41, blue: 0.12, alpha: 1), // Chocolate
        UIColor(red: 0.87, green: 0.72, blue: 0.53, alpha: 1), // Tan
        UIColor(red: 0.96, green: 0.87, blue: 0.70, alpha: 1), // Wheat
        UIColor(red: 0.94, green: 0.90, blue: 0.55, alpha: 1), // Khaki
        UIColor(red: 0.85, green: 0.75, blue: 0.70, alpha: 1), // Sand
        UIColor(red: 0.60, green: 0.50, blue: 0.45, alpha: 1), // Stone
    ]

    /// All available palette types
    enum PaletteType: String, CaseIterable {
        case rainbow = "Rainbow"
        case extended = "All Colors"
        case pastel = "Pastel"
        case neon = "Neon"
        case nature = "Nature"
        case sparkle = "Sparkle ✨"

        var colors: [UIColor] {
            switch self {
            case .rainbow: return ColorPalette.rainbow
            case .extended: return ColorPalette.extended
            case .pastel: return ColorPalette.pastel
            case .neon: return ColorPalette.neon
            case .nature: return ColorPalette.nature
            case .sparkle: return ColorPalette.sparkle
            }
        }

        var icon: String {
            switch self {
            case .rainbow: return "rainbow"
            case .extended: return "circle.grid.3x3.fill"
            case .pastel: return "cloud.fill"
            case .neon: return "bolt.fill"
            case .nature: return "leaf.fill"
            case .sparkle: return "sparkles"
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
