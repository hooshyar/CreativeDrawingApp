//
//  StrokeAnimatorTests.swift
//  CreativeDrawingTests
//
//  Tests for StrokeAnimator partial stroke rendering
//

import XCTest
@testable import Little_Canvas

final class StrokeAnimatorTests: XCTestCase {

    // MARK: - Partial Stroke Tests

    func testPartialStrokeReturnsCorrectPointCount() {
        // Given
        let stroke = createStroke(withPointCount: 10)

        // When
        let partial = StrokeAnimator.partialStroke(from: stroke, pointCount: 5)

        // Then
        XCTAssertEqual(partial.points.count, 5)
        XCTAssertEqual(partial.id, stroke.id)
        XCTAssertEqual(partial.color, stroke.color)
        XCTAssertEqual(partial.brushType, stroke.brushType)
    }

    func testPartialStrokeWithZeroPointsReturnsEmpty() {
        // Given
        let stroke = createStroke(withPointCount: 10)

        // When
        let partial = StrokeAnimator.partialStroke(from: stroke, pointCount: 0)

        // Then
        XCTAssertEqual(partial.points.count, 0)
    }

    func testPartialStrokeWithNegativePointsReturnsEmpty() {
        // Given
        let stroke = createStroke(withPointCount: 10)

        // When
        let partial = StrokeAnimator.partialStroke(from: stroke, pointCount: -5)

        // Then
        XCTAssertEqual(partial.points.count, 0)
    }

    func testPartialStrokeWithAllPointsReturnsOriginal() {
        // Given
        let stroke = createStroke(withPointCount: 10)

        // When
        let partial = StrokeAnimator.partialStroke(from: stroke, pointCount: 10)

        // Then
        XCTAssertEqual(partial.points.count, 10)
    }

    func testPartialStrokeWithExcessPointCountClampsToMax() {
        // Given
        let stroke = createStroke(withPointCount: 5)

        // When
        let partial = StrokeAnimator.partialStroke(from: stroke, pointCount: 100)

        // Then
        XCTAssertEqual(partial.points.count, 5)
    }

    // MARK: - Current Tip Position Tests

    func testCurrentTipPositionReturnsLastVisiblePoint() {
        // Given
        let stroke = createStroke(withPointCount: 10)

        // When
        let position = StrokeAnimator.currentTipPosition(stroke: stroke, pointIndex: 5)

        // Then
        XCTAssertNotNil(position)
        XCTAssertEqual(position, stroke.points[5].position)
    }

    func testCurrentTipPositionReturnsNilForEmptyStroke() {
        // Given
        let stroke = Stroke(color: .red, brushType: .pencil, lineWidth: 5.0)

        // When
        let position = StrokeAnimator.currentTipPosition(stroke: stroke, pointIndex: 0)

        // Then
        XCTAssertNil(position)
    }

    func testCurrentTipPositionReturnsNilForNegativeIndex() {
        // Given
        let stroke = createStroke(withPointCount: 10)

        // When
        let position = StrokeAnimator.currentTipPosition(stroke: stroke, pointIndex: -1)

        // Then
        XCTAssertNil(position)
    }

    func testCurrentTipPositionReturnsNilForOutOfBoundsIndex() {
        // Given
        let stroke = createStroke(withPointCount: 5)

        // When
        let position = StrokeAnimator.currentTipPosition(stroke: stroke, pointIndex: 10)

        // Then
        XCTAssertNil(position)
    }

    // MARK: - Interpolated Position Tests

    func testInterpolatedPositionAtZero() {
        // Given
        let stroke = createStroke(withPointCount: 10)

        // When
        let position = StrokeAnimator.interpolatedPosition(stroke: stroke, progress: 0)

        // Then
        XCTAssertNotNil(position)
        XCTAssertEqual(position?.x ?? -1, stroke.points[0].position.x, accuracy: 0.001)
        XCTAssertEqual(position?.y ?? -1, stroke.points[0].position.y, accuracy: 0.001)
    }

    func testInterpolatedPositionAtOne() {
        // Given
        let stroke = createStroke(withPointCount: 10)

        // When
        let position = StrokeAnimator.interpolatedPosition(stroke: stroke, progress: 1.0)

        // Then
        XCTAssertNotNil(position)
        XCTAssertEqual(position?.x ?? -1, stroke.points.last!.position.x, accuracy: 0.001)
        XCTAssertEqual(position?.y ?? -1, stroke.points.last!.position.y, accuracy: 0.001)
    }

    func testInterpolatedPositionAtHalf() {
        // Given - stroke from (0,0) to (90,90)
        let stroke = createStroke(withPointCount: 10) // Points at 0,10,20...90

        // When
        let position = StrokeAnimator.interpolatedPosition(stroke: stroke, progress: 0.5)

        // Then - should be around middle
        XCTAssertNotNil(position)
        // At 50%, we're at index 4.5 which interpolates between point 4 (40,40) and point 5 (50,50)
        XCTAssertEqual(position?.x ?? -1, 45.0, accuracy: 0.001)
        XCTAssertEqual(position?.y ?? -1, 45.0, accuracy: 0.001)
    }

    func testInterpolatedPositionClampsNegativeProgress() {
        // Given
        let stroke = createStroke(withPointCount: 10)

        // When
        let position = StrokeAnimator.interpolatedPosition(stroke: stroke, progress: -0.5)

        // Then - should clamp to start
        XCTAssertNotNil(position)
        XCTAssertEqual(position?.x ?? -1, stroke.points[0].position.x, accuracy: 0.001)
    }

    func testInterpolatedPositionClampsExcessProgress() {
        // Given
        let stroke = createStroke(withPointCount: 10)

        // When
        let position = StrokeAnimator.interpolatedPosition(stroke: stroke, progress: 1.5)

        // Then - should clamp to end
        XCTAssertNotNil(position)
        XCTAssertEqual(position?.x ?? -1, stroke.points.last!.position.x, accuracy: 0.001)
    }

    func testInterpolatedPositionWithSinglePoint() {
        // Given
        let stroke = createStroke(withPointCount: 1)

        // When
        let position = StrokeAnimator.interpolatedPosition(stroke: stroke, progress: 0.5)

        // Then
        XCTAssertNotNil(position)
        XCTAssertEqual(position?.x ?? -1, stroke.points[0].position.x, accuracy: 0.001)
    }

    // MARK: - Visible Point Count Tests

    func testVisiblePointCountAtZero() {
        // Given
        let stroke = createStroke(withPointCount: 10)

        // When
        let count = StrokeAnimator.visiblePointCount(stroke: stroke, elapsedTime: 0, totalStrokeDuration: 1.0)

        // Then - minimum of 1 visible
        XCTAssertEqual(count, 1)
    }

    func testVisiblePointCountAtHalf() {
        // Given
        let stroke = createStroke(withPointCount: 10)

        // When
        let count = StrokeAnimator.visiblePointCount(stroke: stroke, elapsedTime: 0.5, totalStrokeDuration: 1.0)

        // Then
        XCTAssertEqual(count, 5)
    }

    func testVisiblePointCountAtFull() {
        // Given
        let stroke = createStroke(withPointCount: 10)

        // When
        let count = StrokeAnimator.visiblePointCount(stroke: stroke, elapsedTime: 1.0, totalStrokeDuration: 1.0)

        // Then
        XCTAssertEqual(count, 10)
    }

    func testVisiblePointCountWithZeroDuration() {
        // Given
        let stroke = createStroke(withPointCount: 10)

        // When
        let count = StrokeAnimator.visiblePointCount(stroke: stroke, elapsedTime: 0.5, totalStrokeDuration: 0)

        // Then - should return all points
        XCTAssertEqual(count, 10)
    }

    // MARK: - Original Duration Tests

    func testOriginalDuration() {
        // Given
        let stroke = Stroke(color: .red, brushType: .pencil, lineWidth: 5.0)
        let startTime: TimeInterval = 1000.0

        for i in 0..<5 {
            let point = StrokePoint(
                position: CGPoint(x: Double(i) * 10, y: Double(i) * 10),
                pressure: 1.0,
                timestamp: startTime + Double(i) * 0.5 // 0.5 seconds apart
            )
            stroke.addPoint(point)
        }

        // When
        let duration = StrokeAnimator.originalDuration(of: stroke)

        // Then - 4 intervals of 0.5 seconds = 2.0 seconds
        XCTAssertEqual(duration, 2.0, accuracy: 0.001)
    }

    func testOriginalDurationWithEmptyStroke() {
        // Given
        let stroke = Stroke(color: .red, brushType: .pencil, lineWidth: 5.0)

        // When
        let duration = StrokeAnimator.originalDuration(of: stroke)

        // Then
        XCTAssertEqual(duration, 0)
    }

    func testOriginalDurationWithSinglePoint() {
        // Given
        let stroke = createStroke(withPointCount: 1)

        // When
        let duration = StrokeAnimator.originalDuration(of: stroke)

        // Then
        XCTAssertEqual(duration, 0)
    }

    // MARK: - Helper Methods

    private func createStroke(withPointCount count: Int) -> Stroke {
        let stroke = Stroke(color: .red, brushType: .pencil, lineWidth: 5.0)
        let startTime = Date().timeIntervalSince1970

        for i in 0..<count {
            let point = StrokePoint(
                position: CGPoint(x: Double(i) * 10, y: Double(i) * 10),
                pressure: 1.0,
                timestamp: startTime + Double(i) * 0.1
            )
            stroke.addPoint(point)
        }

        return stroke
    }
}
