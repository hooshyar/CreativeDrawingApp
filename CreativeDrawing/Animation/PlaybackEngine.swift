//
//  PlaybackEngine.swift
//  CreativeDrawing
//
//  State machine for controlling timelapse and animation playback
//

import UIKit

// MARK: - Playback Types

/// Different playback modes for animation
enum PlaybackMode {
    /// Compress entire drawing into a fixed duration
    case timelapse(targetDuration: TimeInterval)

    /// Playback at a speed multiplier (1x, 2x, 5x, 10x)
    case realtime(speedMultiplier: CGFloat)

    /// Fixed time per stroke for progressive reveal
    case trace(durationPerStroke: TimeInterval)
}

/// Current state of playback
enum PlaybackState {
    case idle
    case playing
    case paused
    case completed
}

/// Information about what to render at a specific point in playback
struct PlaybackRenderState {
    /// Strokes that are fully completed
    let completedStrokes: [Stroke]

    /// Current stroke being drawn (partial) - nil if between strokes
    let activeStroke: (stroke: Stroke, visiblePointCount: Int)?

    /// Position of the drawing "pen tip" for visual feedback
    let penTipPosition: CGPoint?

    /// Stamps that are fully placed
    let completedStamps: [Stamp]

    /// Fill regions that are completed
    let completedFills: [FillRegion]

    /// Background color
    let backgroundColor: UIColor

    /// Current progress (0.0 to 1.0)
    let progress: CGFloat

    /// Current playback time
    let currentTime: TimeInterval
}

// MARK: - Timeline Event

/// An event in the drawing timeline
enum TimelineEvent {
    case strokeStart(stroke: Stroke, pointIndex: Int)
    case strokePoint(stroke: Stroke, pointIndex: Int)
    case strokeEnd(stroke: Stroke)
    case stamp(stamp: Stamp)
    case fill(fill: FillRegion)
}

/// A timestamped event for playback
struct TimestampedEvent {
    let originalTime: TimeInterval
    let mappedTime: TimeInterval
    let event: TimelineEvent
}

// MARK: - PlaybackEngine Delegate

protocol PlaybackEngineDelegate: AnyObject {
    /// Called when playback state changes
    func playbackEngine(_ engine: PlaybackEngine, didChangeState state: PlaybackState)

    /// Called when render state updates (every frame)
    func playbackEngine(_ engine: PlaybackEngine, didUpdateRenderState state: PlaybackRenderState)

    /// Called when playback completes
    func playbackEngineDidComplete(_ engine: PlaybackEngine)
}

// MARK: - PlaybackEngine

/// Engine for controlling timelapse and animation playback
class PlaybackEngine {

    // MARK: - Properties

    weak var delegate: PlaybackEngineDelegate?

    /// Current playback mode
    private(set) var playbackMode: PlaybackMode = .timelapse(targetDuration: 10.0)

    /// Current playback state
    private(set) var state: PlaybackState = .idle {
        didSet {
            if state != oldValue {
                delegate?.playbackEngine(self, didChangeState: state)
            }
        }
    }

    /// The document being played back
    private var document: DrawingDocument?

    /// Canvas size for rendering
    private var canvasSize: CGSize = .zero

    /// Timeline of events
    private var timeline: [TimestampedEvent] = []

    /// Total duration of the playback
    private var totalDuration: TimeInterval = 0

    /// Original duration of the drawing
    private var originalDuration: TimeInterval = 0

    /// Display link for playback
    private var displayLink: CADisplayLink?

    /// Start time of playback
    private var playbackStartTime: CFTimeInterval = 0

    /// Time when paused
    private var pausedTime: CFTimeInterval = 0

    /// Accumulated time from previous play sessions (for pause/resume)
    private var accumulatedTime: CFTimeInterval = 0

    /// Current playback progress (0.0 to 1.0)
    private(set) var progress: CGFloat = 0

    /// Current playback time
    private(set) var currentTime: TimeInterval = 0

    // MARK: - Computed Properties

    /// Speed multiplier for current mode
    var speedMultiplier: CGFloat {
        switch playbackMode {
        case .timelapse(let targetDuration):
            guard originalDuration > 0 else { return 1.0 }
            return CGFloat(originalDuration / targetDuration)
        case .realtime(let multiplier):
            return multiplier
        case .trace:
            return 1.0
        }
    }

    // MARK: - Configuration

    /// Configure the engine with a document and playback mode
    func configure(document: DrawingDocument, canvasSize: CGSize, mode: PlaybackMode) {
        self.document = document
        self.canvasSize = canvasSize
        self.playbackMode = mode

        // Handle empty documents gracefully
        guard !document.strokes.isEmpty else {
            state = .completed
            progress = 1.0
            currentTime = 0
            totalDuration = 0
            return
        }

        buildTimeline()
        calculateDurations()

        state = .idle
        progress = 0
        currentTime = 0
    }

    /// Change playback mode (rebuilds timeline if needed)
    func setPlaybackMode(_ mode: PlaybackMode) {
        let wasPlaying = state == .playing
        if wasPlaying {
            pause()
        }

        self.playbackMode = mode
        calculateDurations()

        if wasPlaying {
            play()
        }
    }

    // MARK: - Playback Control

    /// Start or resume playback
    func play() {
        guard document != nil else { return }

        if state == .completed {
            // Restart from beginning
            reset()
        }

        playbackStartTime = CACurrentMediaTime()
        startDisplayLink()
        state = .playing
    }

    /// Pause playback
    func pause() {
        guard state == .playing else { return }

        accumulatedTime += CACurrentMediaTime() - playbackStartTime
        stopDisplayLink()
        state = .paused
    }

    /// Stop playback and reset to beginning
    func stop() {
        stopDisplayLink()
        reset()
        state = .idle
    }

    /// Reset to beginning
    func reset() {
        progress = 0
        currentTime = 0
        accumulatedTime = 0
    }

    /// Seek to a specific progress (0.0 to 1.0)
    func seek(to progress: CGFloat) {
        let clampedProgress = max(0, min(1, progress))
        self.progress = clampedProgress
        self.currentTime = TimeInterval(clampedProgress) * totalDuration
        self.accumulatedTime = currentTime

        if state == .paused || state == .idle {
            // Update render state immediately when seeking
            updateRenderState()
        }
    }

    // MARK: - Timeline Building

    /// Build the timeline from the document
    private func buildTimeline() {
        guard let document = document else { return }

        timeline.removeAll()

        // Collect all stroke points with their timestamps
        var events: [(time: TimeInterval, event: TimelineEvent)] = []

        for stroke in document.strokes {
            guard let firstPoint = stroke.points.first else { continue }

            // Stroke start
            events.append((firstPoint.timestamp, .strokeStart(stroke: stroke, pointIndex: 0)))

            // Individual points
            for (index, point) in stroke.points.enumerated() where index > 0 {
                events.append((point.timestamp, .strokePoint(stroke: stroke, pointIndex: index)))
            }

            // Stroke end (use last point timestamp)
            if let lastPoint = stroke.points.last {
                events.append((lastPoint.timestamp, .strokeEnd(stroke: stroke)))
            }
        }

        // Add stamps (use creation time approximation - after strokes)
        for stamp in document.stamps {
            // Approximate stamp time as after all strokes
            let stampTime = events.last?.time ?? 0
            events.append((stampTime, .stamp(stamp: stamp)))
        }

        // Sort by time
        events.sort { $0.time < $1.time }

        // Calculate original duration
        if let firstTime = events.first?.time, let lastTime = events.last?.time {
            originalDuration = lastTime - firstTime
        } else {
            originalDuration = 0
        }

        // Map times based on playback mode
        let startTime = events.first?.time ?? 0

        timeline = events.map { event in
            let normalizedTime = event.time - startTime
            let mappedTime = mapTime(normalizedTime)

            return TimestampedEvent(
                originalTime: event.time,
                mappedTime: mappedTime,
                event: event.event
            )
        }
    }

    /// Map original time to playback time based on mode
    private func mapTime(_ originalTime: TimeInterval) -> TimeInterval {
        guard originalDuration > 0 else { return originalTime }

        switch playbackMode {
        case .timelapse(let targetDuration):
            let ratio = targetDuration / originalDuration
            return originalTime * ratio

        case .realtime(let multiplier):
            return originalTime / TimeInterval(multiplier)

        case .trace:
            // In trace mode, timing is based on stroke count, not original timestamps
            // This is handled specially in the render state calculation
            return originalTime
        }
    }

    /// Calculate total duration based on mode
    private func calculateDurations() {
        switch playbackMode {
        case .timelapse(let targetDuration):
            totalDuration = targetDuration

        case .realtime(let multiplier):
            totalDuration = originalDuration / TimeInterval(multiplier)

        case .trace(let durationPerStroke):
            guard let document = document else {
                totalDuration = 0
                return
            }
            totalDuration = TimeInterval(document.strokes.count) * durationPerStroke
        }
    }

    // MARK: - Display Link

    private func startDisplayLink() {
        guard displayLink == nil else { return }

        displayLink = CADisplayLink(target: self, selector: #selector(displayLinkTick(_:)))

        if #available(iOS 15.0, *) {
            displayLink?.preferredFrameRateRange = CAFrameRateRange(
                minimum: 30,
                maximum: 60,
                preferred: 60
            )
        }

        displayLink?.add(to: .main, forMode: .common)
    }

    private func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func displayLinkTick(_ link: CADisplayLink) {
        let elapsedTime = (CACurrentMediaTime() - playbackStartTime) + accumulatedTime
        currentTime = elapsedTime
        progress = totalDuration > 0 ? CGFloat(elapsedTime / totalDuration) : 1.0

        if progress >= 1.0 {
            // Playback complete
            progress = 1.0
            currentTime = totalDuration
            stopDisplayLink()
            state = .completed
            delegate?.playbackEngineDidComplete(self)
        }

        updateRenderState()
    }

    // MARK: - Render State

    /// Update and notify delegate of current render state
    private func updateRenderState() {
        let renderState = calculateRenderState(at: currentTime)
        delegate?.playbackEngine(self, didUpdateRenderState: renderState)
    }

    /// Calculate what to render at a specific time
    func calculateRenderState(at time: TimeInterval) -> PlaybackRenderState {
        guard let document = document else {
            return PlaybackRenderState(
                completedStrokes: [],
                activeStroke: nil,
                penTipPosition: nil,
                completedStamps: [],
                completedFills: [],
                backgroundColor: .white,
                progress: 0,
                currentTime: 0
            )
        }

        var completedStrokes: [Stroke] = []
        var activeStroke: (stroke: Stroke, visiblePointCount: Int)?
        var penTipPosition: CGPoint?
        var completedStamps: [Stamp] = []
        var completedFills: [FillRegion] = document.fills // Show fills immediately for now

        // Process timeline events up to current time
        for event in timeline {
            if event.mappedTime > time {
                break
            }

            switch event.event {
            case .strokeStart(let stroke, _):
                // Start tracking this stroke
                activeStroke = (stroke, 1)

            case .strokePoint(let stroke, let pointIndex):
                // Update active stroke point count
                if activeStroke?.stroke.id == stroke.id {
                    activeStroke = (stroke, pointIndex + 1)
                }
                // Update pen tip position
                if pointIndex < stroke.points.count {
                    penTipPosition = stroke.points[pointIndex].position
                }

            case .strokeEnd(let stroke):
                // Move stroke to completed
                if activeStroke?.stroke.id == stroke.id {
                    completedStrokes.append(stroke)
                    activeStroke = nil
                }

            case .stamp(let stamp):
                completedStamps.append(stamp)

            case .fill(let fill):
                completedFills.append(fill)
            }
        }

        // Handle trace mode specially
        if case .trace(let durationPerStroke) = playbackMode {
            let strokeIndex = Int(time / durationPerStroke)
            let strokeProgress = CGFloat(fmod(time, durationPerStroke) / durationPerStroke)

            completedStrokes = Array(document.strokes.prefix(strokeIndex))

            if strokeIndex < document.strokes.count {
                let currentStroke = document.strokes[strokeIndex]
                let visiblePoints = max(1, Int(CGFloat(currentStroke.points.count) * strokeProgress))
                activeStroke = (currentStroke, visiblePoints)

                if visiblePoints > 0 && visiblePoints <= currentStroke.points.count {
                    penTipPosition = currentStroke.points[visiblePoints - 1].position
                }
            }
        }

        return PlaybackRenderState(
            completedStrokes: completedStrokes,
            activeStroke: activeStroke,
            penTipPosition: penTipPosition,
            completedStamps: completedStamps,
            completedFills: completedFills,
            backgroundColor: document.backgroundColor,
            progress: CGFloat(time / max(totalDuration, 0.001)),
            currentTime: time
        )
    }

    // MARK: - Utility

    /// Get duration formatted as MM:SS
    func formattedDuration() -> String {
        let minutes = Int(totalDuration) / 60
        let seconds = Int(totalDuration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    /// Get current time formatted as MM:SS
    func formattedCurrentTime() -> String {
        let minutes = Int(currentTime) / 60
        let seconds = Int(currentTime) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
