//
//  BrushRendererTests.swift
//  CreativeDrawingTests
//
//  Tests for BrushRenderer shared brush rendering
//

import XCTest
@testable import Little_Canvas

final class BrushRendererTests: XCTestCase {

    // MARK: - Draw Stroke Tests

    func testDrawStrokeDoesNotCrashWithEmptyStroke() {
        // Given
        let stroke = Stroke(color: .red, brushType: .pencil, lineWidth: 5.0)
        let size = CGSize(width: 100, height: 100)

        // When/Then - should not crash
        let renderer = UIGraphicsImageRenderer(size: size)
        let _ = renderer.image { context in
            BrushRenderer.drawStroke(stroke, in: context.cgContext, timeOffset: 0)
        }
    }

    func testDrawStrokeWithSinglePoint() {
        // Given
        let stroke = createStroke(withPointCount: 1, brushType: .pencil)
        let size = CGSize(width: 100, height: 100)

        // When/Then - should not crash
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            BrushRenderer.drawStroke(stroke, in: context.cgContext, timeOffset: 0)
        }

        XCTAssertNotNil(image)
    }

    func testDrawPencilStroke() {
        // Given
        let stroke = createStroke(withPointCount: 10, brushType: .pencil)
        let size = CGSize(width: 200, height: 200)

        // When
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            BrushRenderer.drawStroke(stroke, in: context.cgContext, timeOffset: 0)
        }

        // Then
        XCTAssertNotNil(image)
        // Verify the image is not completely white (stroke was drawn)
        XCTAssertTrue(hasNonWhitePixels(image))
    }

    func testDrawMarkerStroke() {
        // Given
        let stroke = createStroke(withPointCount: 10, brushType: .marker)
        let size = CGSize(width: 200, height: 200)

        // When
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            BrushRenderer.drawStroke(stroke, in: context.cgContext, timeOffset: 0)
        }

        // Then
        XCTAssertNotNil(image)
        XCTAssertTrue(hasNonWhitePixels(image))
    }

    func testDrawCrayonStroke() {
        // Given
        let stroke = createStroke(withPointCount: 10, brushType: .crayon)
        let size = CGSize(width: 200, height: 200)

        // When
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            BrushRenderer.drawStroke(stroke, in: context.cgContext, timeOffset: 0)
        }

        // Then
        XCTAssertNotNil(image)
        XCTAssertTrue(hasNonWhitePixels(image))
    }

    func testDrawSparkleStroke() {
        // Given
        let stroke = createStroke(withPointCount: 10, brushType: .sparkle)
        let size = CGSize(width: 200, height: 200)

        // When
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            BrushRenderer.drawStroke(stroke, in: context.cgContext, timeOffset: 0)
        }

        // Then
        XCTAssertNotNil(image)
    }

    func testDrawRainbowStroke() {
        // Given
        let stroke = createStroke(withPointCount: 10, brushType: .rainbow)
        let size = CGSize(width: 200, height: 200)

        // When
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            BrushRenderer.drawStroke(stroke, in: context.cgContext, timeOffset: 0)
        }

        // Then
        XCTAssertNotNil(image)
    }

    func testDrawEraserStroke() {
        // Given
        let stroke = createStroke(withPointCount: 10, brushType: .eraser)
        let size = CGSize(width: 200, height: 200)

        // When
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            // Fill background first
            UIColor.blue.setFill()
            context.fill(CGRect(origin: .zero, size: size))

            // Draw eraser stroke
            BrushRenderer.drawStroke(stroke, in: context.cgContext, timeOffset: 0)
        }

        // Then
        XCTAssertNotNil(image)
    }

    // MARK: - Deterministic Noise Tests

    func testDeterministicNoiseIsConsistent() {
        // Given
        let x: CGFloat = 50.0
        let y: CGFloat = 75.0
        let seed = 42

        // When
        let noise1 = BrushRenderer.deterministicNoise(x, y, seed: seed)
        let noise2 = BrushRenderer.deterministicNoise(x, y, seed: seed)

        // Then
        XCTAssertEqual(noise1, noise2)
    }

    func testDeterministicNoiseRange() {
        // Given - multiple positions
        let positions: [(CGFloat, CGFloat)] = [
            (0, 0), (100, 100), (50, 75), (-10, 200), (999, 999)
        ]

        // When/Then - all values should be in [0, 1]
        for (x, y) in positions {
            let noise = BrushRenderer.deterministicNoise(x, y, seed: 0)
            XCTAssertGreaterThanOrEqual(noise, 0)
            XCTAssertLessThanOrEqual(noise, 1)
        }
    }

    func testDeterministicNoiseVariesWithPosition() {
        // Given
        let seed = 42

        // When
        let noise1 = BrushRenderer.deterministicNoise(0, 0, seed: seed)
        let noise2 = BrushRenderer.deterministicNoise(100, 100, seed: seed)

        // Then - different positions should (likely) produce different values
        // Note: There's a very small chance they could be equal, but extremely unlikely
        XCTAssertNotEqual(noise1, noise2)
    }

    func testDeterministicNoiseVariesWithSeed() {
        // Given
        let x: CGFloat = 50.0
        let y: CGFloat = 75.0

        // When
        let noise1 = BrushRenderer.deterministicNoise(x, y, seed: 1)
        let noise2 = BrushRenderer.deterministicNoise(x, y, seed: 2)

        // Then
        XCTAssertNotEqual(noise1, noise2)
    }

    // MARK: - Draw Star Tests

    func testDrawStar() {
        // Given
        let size = CGSize(width: 100, height: 100)

        // When
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            BrushRenderer.drawStar(
                at: CGPoint(x: 50, y: 50),
                size: 20,
                color: .yellow,
                in: context.cgContext
            )
        }

        // Then
        XCTAssertNotNil(image)
        XCTAssertTrue(hasNonWhitePixels(image))
    }

    // MARK: - Time Offset Tests

    func testSparkleStrokeUsesTimeOffset() {
        // Given
        let stroke = createStroke(withPointCount: 20, brushType: .sparkle)
        let size = CGSize(width: 200, height: 200)

        // When - render at different time offsets
        let renderer = UIGraphicsImageRenderer(size: size)
        let image1 = renderer.image { context in
            BrushRenderer.drawStroke(stroke, in: context.cgContext, timeOffset: 0)
        }
        let image2 = renderer.image { context in
            BrushRenderer.drawStroke(stroke, in: context.cgContext, timeOffset: 1.0)
        }

        // Then - both should render successfully
        XCTAssertNotNil(image1)
        XCTAssertNotNil(image2)
        // Note: Visual differences would require pixel-level comparison
    }

    // MARK: - Helper Methods

    private func createStroke(withPointCount count: Int, brushType: BrushType) -> Stroke {
        let stroke = Stroke(color: .red, brushType: brushType, lineWidth: brushType.baseWidth)
        let startTime = Date().timeIntervalSince1970

        for i in 0..<count {
            let point = StrokePoint(
                position: CGPoint(x: 20 + Double(i) * 15, y: 20 + Double(i) * 15),
                pressure: 1.0,
                timestamp: startTime + Double(i) * 0.1
            )
            stroke.addPoint(point)
        }

        return stroke
    }

    private func hasNonWhitePixels(_ image: UIImage) -> Bool {
        guard let cgImage = image.cgImage else { return false }

        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8

        var pixelData = [UInt8](repeating: 0, count: width * height * bytesPerPixel)

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return false }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        // Check for non-white pixels (R != 255 or G != 255 or B != 255)
        for y in 0..<height {
            for x in 0..<width {
                let offset = (y * width + x) * bytesPerPixel
                let r = pixelData[offset]
                let g = pixelData[offset + 1]
                let b = pixelData[offset + 2]

                if r != 255 || g != 255 || b != 255 {
                    return true
                }
            }
        }

        return false
    }
}
