//
//  TimelineCalculatorTests.swift
//  CreativeDrawingTests
//
//  Tests for TimelineCalculator timing utilities
//

import XCTest
@testable import Little_Canvas

final class TimelineCalculatorTests: XCTestCase {

    // MARK: - Compression Ratio Tests

    func testCompressionRatioForTimelapse() {
        // Given
        let originalDuration: TimeInterval = 60.0 // 1 minute
        let targetDuration: TimeInterval = 10.0   // 10 seconds

        // When
        let ratio = TimelineCalculator.compressionRatio(originalDuration: originalDuration, targetDuration: targetDuration)

        // Then - 10/60 = 0.166...
        XCTAssertEqual(ratio, 1.0/6.0, accuracy: 0.001)
    }

    func testCompressionRatioWithZeroOriginalDuration() {
        // Given
        let originalDuration: TimeInterval = 0
        let targetDuration: TimeInterval = 10.0

        // When
        let ratio = TimelineCalculator.compressionRatio(originalDuration: originalDuration, targetDuration: targetDuration)

        // Then
        XCTAssertEqual(ratio, 1.0)
    }

    func testCompressionRatioForSlowdown() {
        // Given
        let originalDuration: TimeInterval = 5.0
        let targetDuration: TimeInterval = 10.0 // 2x slower

        // When
        let ratio = TimelineCalculator.compressionRatio(originalDuration: originalDuration, targetDuration: targetDuration)

        // Then
        XCTAssertEqual(ratio, 2.0, accuracy: 0.001)
    }

    // MARK: - Map Time Tests

    func testMapTime() {
        // Given
        let originalTime: TimeInterval = 30.0
        let startTime: TimeInterval = 10.0
        let compressionRatio = 0.5

        // When
        let mappedTime = TimelineCalculator.mapTime(originalTime: originalTime, startTime: startTime, compressionRatio: compressionRatio)

        // Then - (30 - 10) * 0.5 = 10
        XCTAssertEqual(mappedTime, 10.0, accuracy: 0.001)
    }

    func testMapTimeAtStart() {
        // Given
        let originalTime: TimeInterval = 10.0
        let startTime: TimeInterval = 10.0
        let compressionRatio = 0.5

        // When
        let mappedTime = TimelineCalculator.mapTime(originalTime: originalTime, startTime: startTime, compressionRatio: compressionRatio)

        // Then
        XCTAssertEqual(mappedTime, 0, accuracy: 0.001)
    }

    // MARK: - Trace Duration Tests

    func testTraceDuration() {
        // Given
        let strokeCount = 5
        let durationPerStroke: TimeInterval = 2.0

        // When
        let duration = TimelineCalculator.traceDuration(strokeCount: strokeCount, durationPerStroke: durationPerStroke)

        // Then
        XCTAssertEqual(duration, 10.0, accuracy: 0.001)
    }

    func testTraceDurationWithZeroStrokes() {
        // Given
        let strokeCount = 0
        let durationPerStroke: TimeInterval = 2.0

        // When
        let duration = TimelineCalculator.traceDuration(strokeCount: strokeCount, durationPerStroke: durationPerStroke)

        // Then
        XCTAssertEqual(duration, 0)
    }

    // MARK: - Trace Progress Tests

    func testTraceProgressFirstStroke() {
        // Given
        let currentTime: TimeInterval = 0.5
        let durationPerStroke: TimeInterval = 1.0

        // When
        let (strokeIndex, progress) = TimelineCalculator.traceProgress(currentTime: currentTime, durationPerStroke: durationPerStroke)

        // Then
        XCTAssertEqual(strokeIndex, 0)
        XCTAssertEqual(progress, 0.5, accuracy: 0.001)
    }

    func testTraceProgressSecondStroke() {
        // Given
        let currentTime: TimeInterval = 1.5
        let durationPerStroke: TimeInterval = 1.0

        // When
        let (strokeIndex, progress) = TimelineCalculator.traceProgress(currentTime: currentTime, durationPerStroke: durationPerStroke)

        // Then
        XCTAssertEqual(strokeIndex, 1)
        XCTAssertEqual(progress, 0.5, accuracy: 0.001)
    }

    func testTraceProgressAtStrokeBoundary() {
        // Given
        let currentTime: TimeInterval = 2.0
        let durationPerStroke: TimeInterval = 1.0

        // When
        let (strokeIndex, progress) = TimelineCalculator.traceProgress(currentTime: currentTime, durationPerStroke: durationPerStroke)

        // Then
        XCTAssertEqual(strokeIndex, 2)
        XCTAssertEqual(progress, 0, accuracy: 0.001)
    }

    func testTraceProgressWithZeroDuration() {
        // Given
        let currentTime: TimeInterval = 1.0
        let durationPerStroke: TimeInterval = 0

        // When
        let (strokeIndex, progress) = TimelineCalculator.traceProgress(currentTime: currentTime, durationPerStroke: durationPerStroke)

        // Then
        XCTAssertEqual(strokeIndex, 0)
        XCTAssertEqual(progress, 0)
    }
}
