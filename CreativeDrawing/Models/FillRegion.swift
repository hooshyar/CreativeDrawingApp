//
//  FillRegion.swift
//  CreativeDrawing
//
//  Represents a filled region created by the bucket/fill tool
//

import UIKit

/// A filled region on the canvas
class FillRegion {
    let id: UUID
    let color: UIColor
    let filledImage: UIImage
    let bounds: CGRect
    let createdAt: Date

    init(color: UIColor, filledImage: UIImage, bounds: CGRect) {
        self.id = UUID()
        self.color = color
        self.filledImage = filledImage
        self.bounds = bounds
        self.createdAt = Date()
    }

    /// Initialize with existing ID (for deserialization)
    init(id: UUID, color: UIColor, filledImage: UIImage, bounds: CGRect) {
        self.id = id
        self.color = color
        self.filledImage = filledImage
        self.bounds = bounds
        self.createdAt = Date()
    }
}

/// Flood fill algorithm for canvas
class FloodFill {

    /// Tolerance for color matching (0-255 scale)
    static let colorTolerance: Int = 32

    /// Perform flood fill on an image at the given point
    /// Returns a new image with only the filled region (transparent elsewhere)
    static func fill(
        in image: UIImage,
        at point: CGPoint,
        with fillColor: UIColor,
        tolerance: Int = colorTolerance
    ) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }

        let width = cgImage.width
        let height = cgImage.height

        // Convert point to pixel coordinates
        let scale = image.scale
        let pixelX = Int(point.x * scale)
        let pixelY = Int(point.y * scale)

        // Check bounds
        guard pixelX >= 0 && pixelX < width && pixelY >= 0 && pixelY < height else {
            return nil
        }

        // Create pixel buffer
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8

        var pixelData = [UInt8](repeating: 0, count: width * height * bytesPerPixel)

        guard let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        // Get the target color at the clicked point
        let targetIndex = (pixelY * width + pixelX) * bytesPerPixel
        let targetR = Int(pixelData[targetIndex])
        let targetG = Int(pixelData[targetIndex + 1])
        let targetB = Int(pixelData[targetIndex + 2])
        let targetA = Int(pixelData[targetIndex + 3])

        // Get fill color components
        var fillR: CGFloat = 0, fillG: CGFloat = 0, fillB: CGFloat = 0, fillA: CGFloat = 0
        fillColor.getRed(&fillR, green: &fillG, blue: &fillB, alpha: &fillA)

        let newR = UInt8(fillR * 255)
        let newG = UInt8(fillG * 255)
        let newB = UInt8(fillB * 255)
        let newA = UInt8(fillA * 255)

        // Don't fill if clicking on the same color
        if colorsMatch(targetR, targetG, targetB, targetA,
                       Int(newR), Int(newG), Int(newB), Int(newA),
                       tolerance: tolerance) {
            return nil
        }

        // Create output buffer (transparent)
        var outputData = [UInt8](repeating: 0, count: width * height * bytesPerPixel)

        // Visited array
        var visited = [Bool](repeating: false, count: width * height)

        // Queue for flood fill (using array as queue for simplicity)
        var queue = [(Int, Int)]()
        queue.append((pixelX, pixelY))
        visited[pixelY * width + pixelX] = true

        // Process queue
        while !queue.isEmpty {
            let (x, y) = queue.removeFirst()
            let index = (y * width + x) * bytesPerPixel

            // Fill this pixel in output
            outputData[index] = newR
            outputData[index + 1] = newG
            outputData[index + 2] = newB
            outputData[index + 3] = newA

            // Check neighbors (4-connected)
            let neighbors = [(x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)]

            for (nx, ny) in neighbors {
                // Check bounds
                guard nx >= 0 && nx < width && ny >= 0 && ny < height else { continue }

                let neighborPos = ny * width + nx

                // Skip if already visited
                guard !visited[neighborPos] else { continue }

                let neighborIndex = neighborPos * bytesPerPixel
                let nR = Int(pixelData[neighborIndex])
                let nG = Int(pixelData[neighborIndex + 1])
                let nB = Int(pixelData[neighborIndex + 2])
                let nA = Int(pixelData[neighborIndex + 3])

                // Check if color matches target
                if colorsMatch(nR, nG, nB, nA, targetR, targetG, targetB, targetA, tolerance: tolerance) {
                    visited[neighborPos] = true
                    queue.append((nx, ny))
                }
            }
        }

        // Create output image
        guard let outputContext = CGContext(
            data: &outputData,
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ),
        let outputCGImage = outputContext.makeImage() else {
            return nil
        }

        return UIImage(cgImage: outputCGImage, scale: scale, orientation: .up)
    }

    /// Check if two colors match within tolerance
    private static func colorsMatch(
        _ r1: Int, _ g1: Int, _ b1: Int, _ a1: Int,
        _ r2: Int, _ g2: Int, _ b2: Int, _ a2: Int,
        tolerance: Int
    ) -> Bool {
        return abs(r1 - r2) <= tolerance &&
               abs(g1 - g2) <= tolerance &&
               abs(b1 - b2) <= tolerance &&
               abs(a1 - a2) <= tolerance
    }
}
