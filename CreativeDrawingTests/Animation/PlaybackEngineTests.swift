//
//  PlaybackEngineTests.swift
//  CreativeDrawingTests
//
//  Tests for PlaybackEngine animation state machine
//

import XCTest
@testable import Little_Canvas

final class PlaybackEngineTests: XCTestCase {

    var engine: PlaybackEngine!
    var delegate: MockPlaybackEngineDelegate!

    override func setUp() {
        super.setUp()
        engine = PlaybackEngine()
        delegate = MockPlaybackEngineDelegate()
        engine.delegate = delegate
    }

    override func tearDown() {
        engine.stop()
        engine = nil
        delegate = nil
        super.tearDown()
    }

    // MARK: - State Tests

    func testInitialStateIsIdle() {
        XCTAssertEqual(engine.state, .idle)
    }

    func testPlayTransitionsToPlaying() {
        // Given
        let document = createTestDocument()
        engine.configure(document: document, canvasSize: CGSize(width: 100, height: 100), mode: .timelapse(targetDuration: 5.0))

        // When
        engine.play()

        // Then
        XCTAssertEqual(engine.state, .playing)
        XCTAssertTrue(delegate.didChangeStateCalled)
        XCTAssertEqual(delegate.lastState, .playing)
    }

    func testPauseTransitionsToPaused() {
        // Given
        let document = createTestDocument()
        engine.configure(document: document, canvasSize: CGSize(width: 100, height: 100), mode: .timelapse(targetDuration: 5.0))
        engine.play()

        // When
        engine.pause()

        // Then
        XCTAssertEqual(engine.state, .paused)
    }

    func testStopResetsToIdle() {
        // Given
        let document = createTestDocument()
        engine.configure(document: document, canvasSize: CGSize(width: 100, height: 100), mode: .timelapse(targetDuration: 5.0))
        engine.play()
        engine.seek(to: 0.5)

        // When
        engine.stop()

        // Then
        XCTAssertEqual(engine.state, .idle)
        XCTAssertEqual(engine.progress, 0)
        XCTAssertEqual(engine.currentTime, 0)
    }

    func testSeekUpdatesProgress() {
        // Given
        let document = createTestDocument()
        engine.configure(document: document, canvasSize: CGSize(width: 100, height: 100), mode: .timelapse(targetDuration: 10.0))

        // When
        engine.seek(to: 0.5)

        // Then
        XCTAssertEqual(engine.progress, 0.5, accuracy: 0.001)
        XCTAssertEqual(engine.currentTime, 5.0, accuracy: 0.001)
    }

    func testSeekClampsToBounds() {
        // Given
        let document = createTestDocument()
        engine.configure(document: document, canvasSize: CGSize(width: 100, height: 100), mode: .timelapse(targetDuration: 10.0))

        // When seeking below 0
        engine.seek(to: -0.5)
        XCTAssertEqual(engine.progress, 0)

        // When seeking above 1
        engine.seek(to: 1.5)
        XCTAssertEqual(engine.progress, 1.0)
    }

    // MARK: - Render State Tests

    func testCalculateRenderStateAtZero() {
        // Given
        let document = createTestDocument()
        engine.configure(document: document, canvasSize: CGSize(width: 100, height: 100), mode: .timelapse(targetDuration: 10.0))

        // When
        let state = engine.calculateRenderState(at: 0)

        // Then
        XCTAssertEqual(state.completedStrokes.count, 0)
        XCTAssertEqual(state.progress, 0)
    }

    func testCalculateRenderStateReturnsProgressiveStrokes() {
        // Given
        let document = createTestDocument()
        engine.configure(document: document, canvasSize: CGSize(width: 100, height: 100), mode: .trace(durationPerStroke: 1.0))

        // When at 50% of first stroke
        let stateHalf = engine.calculateRenderState(at: 0.5)

        // Then should have active stroke with partial points
        XCTAssertNotNil(stateHalf.activeStroke)
        XCTAssertEqual(stateHalf.completedStrokes.count, 0)
    }

    // MARK: - Duration Formatting Tests

    func testFormattedDuration() {
        // Given
        let document = createTestDocument()
        engine.configure(document: document, canvasSize: CGSize(width: 100, height: 100), mode: .timelapse(targetDuration: 90.0))

        // When
        let formatted = engine.formattedDuration()

        // Then
        XCTAssertEqual(formatted, "1:30")
    }

    func testFormattedCurrentTime() {
        // Given
        let document = createTestDocument()
        engine.configure(document: document, canvasSize: CGSize(width: 100, height: 100), mode: .timelapse(targetDuration: 100.0))
        engine.seek(to: 0.65) // 65 seconds

        // When
        let formatted = engine.formattedCurrentTime()

        // Then
        XCTAssertEqual(formatted, "1:05")
    }

    // MARK: - Playback Mode Tests

    func testSpeedMultiplierForTimelapse() {
        // Given
        let document = createTestDocumentWithDuration(originalDuration: 20.0)
        engine.configure(document: document, canvasSize: CGSize(width: 100, height: 100), mode: .timelapse(targetDuration: 10.0))

        // Then
        XCTAssertEqual(engine.speedMultiplier, 2.0, accuracy: 0.001)
    }

    func testSpeedMultiplierForRealtime() {
        // Given
        let document = createTestDocument()
        engine.configure(document: document, canvasSize: CGSize(width: 100, height: 100), mode: .realtime(speedMultiplier: 2.0))

        // Then
        XCTAssertEqual(engine.speedMultiplier, 2.0)
    }

    // MARK: - Helper Methods

    private func createTestDocument() -> DrawingDocument {
        let document = DrawingDocument()

        // Create a stroke with multiple points
        let stroke = Stroke(color: .red, brushType: .pencil, lineWidth: 5.0)
        let startTime = Date().timeIntervalSince1970

        for i in 0..<10 {
            let point = StrokePoint(
                position: CGPoint(x: Double(i) * 10, y: Double(i) * 10),
                pressure: 1.0,
                timestamp: startTime + Double(i) * 0.1
            )
            stroke.addPoint(point)
        }

        document.addStroke(stroke)
        return document
    }

    private func createTestDocumentWithDuration(originalDuration: TimeInterval) -> DrawingDocument {
        let document = DrawingDocument()

        let stroke = Stroke(color: .red, brushType: .pencil, lineWidth: 5.0)
        let startTime = Date().timeIntervalSince1970
        let pointCount = 10

        // Create points spanning the full duration (0 to originalDuration)
        for i in 0..<pointCount {
            let point = StrokePoint(
                position: CGPoint(x: Double(i) * 10, y: Double(i) * 10),
                pressure: 1.0,
                timestamp: startTime + (originalDuration * Double(i) / Double(pointCount - 1))
            )
            stroke.addPoint(point)
        }

        document.addStroke(stroke)
        return document
    }
}

// MARK: - Mock Delegate

class MockPlaybackEngineDelegate: PlaybackEngineDelegate {
    var didChangeStateCalled = false
    var lastState: PlaybackState?
    var didUpdateRenderStateCalled = false
    var lastRenderState: PlaybackRenderState?
    var didCompleteCalled = false

    func playbackEngine(_ engine: PlaybackEngine, didChangeState state: PlaybackState) {
        didChangeStateCalled = true
        lastState = state
    }

    func playbackEngine(_ engine: PlaybackEngine, didUpdateRenderState state: PlaybackRenderState) {
        didUpdateRenderStateCalled = true
        lastRenderState = state
    }

    func playbackEngineDidComplete(_ engine: PlaybackEngine) {
        didCompleteCalled = true
    }
}
