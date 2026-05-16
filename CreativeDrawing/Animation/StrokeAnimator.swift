//
//  StrokeAnimator.swift
//  CreativeDrawing
//
//  Utilities for animating strokes during playback
//

import UIKit

/// Utilities for partial stroke rendering during animation playback
struct StrokeAnimator {

    // MARK: - Partial Stroke Creation

    /// Create a partial stroke with only the first N points visible
    /// - Parameters:
    ///   - stroke: The full stroke
    ///   - pointCount: Number of points to include
    /// - Returns: A new stroke with only the specified number of points
    static func partialStroke(from stroke: Stroke, pointCount: Int) -> Stroke {
        let clampedCount = max(0, min(pointCount, stroke.points.count))

        let partial = Stroke(
            id: stroke.id,
            color: stroke.color,
            brushType: stroke.brushType,
            lineWidth: stroke.lineWidth
        )

        for i in 0..<clampedCount {
            partial.addPoint(stroke.points[i])
        }

        return partial
    }

    /// Get the current tip position for a stroke at a specific point index
    /// - Parameters:
    ///   - stroke: The stroke
    ///   - pointIndex: Index of the last visible point
    /// - Returns: The position of the pen tip, or nil if invalid
    static func currentTipPosition(stroke: Stroke, pointIndex: Int) -> CGPoint? {
        guard pointIndex >= 0 && pointIndex < stroke.points.count else { return nil }
        return stroke.points[pointIndex].position
    }

    /// Interpolate between two points for smoother animation
    /// - Parameters:
    ///   - stroke: The stroke
    ///   - progress: Progress through the stroke (0.0 to 1.0)
    /// - Returns: Interpolated position along the stroke
    static func interpolatedPosition(stroke: Stroke, progress: CGFloat) -> CGPoint? {
        guard stroke.points.count >= 2 else {
            return stroke.points.first?.position
        }

        let clampedProgress = max(0, min(1, progress))
        let totalPoints = stroke.points.count - 1
        let exactIndex = clampedProgress * CGFloat(totalPoints)
        let lowerIndex = Int(floor(exactIndex))
        let upperIndex = min(lowerIndex + 1, totalPoints)
        let fraction = exactIndex - CGFloat(lowerIndex)

        let p1 = stroke.points[lowerIndex].position
        let p2 = stroke.points[upperIndex].position

        return CGPoint(
            x: p1.x + (p2.x - p1.x) * fraction,
            y: p1.y + (p2.y - p1.y) * fraction
        )
    }

    // MARK: - Timing Calculations

    /// Calculate how many points should be visible at a given time
    /// - Parameters:
    ///   - stroke: The stroke
    ///   - elapsedTime: Time elapsed since stroke started
    ///   - totalStrokeDuration: Total duration for the stroke
    /// - Returns: Number of points that should be visible
    static func visiblePointCount(
        stroke: Stroke,
        elapsedTime: TimeInterval,
        totalStrokeDuration: TimeInterval
    ) -> Int {
        guard totalStrokeDuration > 0 else { return stroke.points.count }

        let progress = elapsedTime / totalStrokeDuration
        let clampedProgress = max(0, min(1, progress))

        return max(1, Int(CGFloat(stroke.points.count) * CGFloat(clampedProgress)))
    }

    /// Calculate stroke duration based on original timestamps
    /// - Parameter stroke: The stroke
    /// - Returns: Original duration from first to last point
    static func originalDuration(of stroke: Stroke) -> TimeInterval {
        guard let first = stroke.points.first, let last = stroke.points.last else {
            return 0
        }
        return last.timestamp - first.timestamp
    }

    // MARK: - Visual Effects

    /// Generate a pen tip indicator view
    /// - Parameters:
    ///   - position: Position for the tip
    ///   - color: Color of the brush
    ///   - size: Size of the tip indicator
    /// - Returns: A view representing the pen tip
    static func createPenTipView(
        at position: CGPoint,
        color: UIColor,
        size: CGFloat = 20
    ) -> UIView {
        let view = UIView(frame: CGRect(x: 0, y: 0, width: size, height: size))
        view.center = position
        view.backgroundColor = color.withAlphaComponent(0.8)
        view.layer.cornerRadius = size / 2

        // Add glow effect
        view.layer.shadowColor = color.cgColor
        view.layer.shadowRadius = size / 2
        view.layer.shadowOpacity = 0.8
        view.layer.shadowOffset = .zero

        return view
    }

    /// Animate pen tip with pulsing effect
    /// - Parameters:
    ///   - view: The pen tip view
    ///   - isDrawing: Whether the pen is actively drawing
    static func animatePenTip(_ view: UIView, isDrawing: Bool) {
        if isDrawing {
            UIView.animate(
                withDuration: 0.3,
                delay: 0,
                options: [.repeat, .autoreverse],
                animations: {
                    view.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
                }
            )
        } else {
            view.layer.removeAllAnimations()
            view.transform = .identity
        }
    }
}

// MARK: - Timeline Calculator

/// Calculates compressed timeline for timelapse playback
struct TimelineCalculator {

    /// Calculate compression ratio for timelapse
    /// - Parameters:
    ///   - originalDuration: Original drawing duration
    ///   - targetDuration: Desired playback duration
    /// - Returns: Compression ratio
    static func compressionRatio(
        originalDuration: TimeInterval,
        targetDuration: TimeInterval
    ) -> Double {
        guard originalDuration > 0 else { return 1.0 }
        return targetDuration / originalDuration
    }

    /// Map original time to compressed time
    /// - Parameters:
    ///   - originalTime: Time in original timeline
    ///   - startTime: Start time of the drawing
    ///   - compressionRatio: Ratio to compress by
    /// - Returns: Mapped time in compressed timeline
    static func mapTime(
        originalTime: TimeInterval,
        startTime: TimeInterval,
        compressionRatio: Double
    ) -> TimeInterval {
        return (originalTime - startTime) * compressionRatio
    }

    /// Calculate total duration for trace mode
    /// - Parameters:
    ///   - strokeCount: Number of strokes
    ///   - durationPerStroke: Time allocated per stroke
    /// - Returns: Total duration
    static func traceDuration(
        strokeCount: Int,
        durationPerStroke: TimeInterval
    ) -> TimeInterval {
        return TimeInterval(strokeCount) * durationPerStroke
    }

    /// Calculate which stroke and progress within it for trace mode
    /// - Parameters:
    ///   - currentTime: Current playback time
    ///   - durationPerStroke: Time allocated per stroke
    /// - Returns: Stroke index and progress within that stroke (0.0 to 1.0)
    static func traceProgress(
        currentTime: TimeInterval,
        durationPerStroke: TimeInterval
    ) -> (strokeIndex: Int, progress: CGFloat) {
        guard durationPerStroke > 0 else { return (0, 0) }

        let strokeIndex = Int(currentTime / durationPerStroke)
        let progress = CGFloat(fmod(currentTime, durationPerStroke) / durationPerStroke)

        return (strokeIndex, progress)
    }
}

// MARK: - Easing Functions

/// Standard easing functions for animation
struct Easing {

    /// Linear (no easing)
    static func linear(_ t: CGFloat) -> CGFloat {
        return t
    }

    /// Ease in (slow start)
    static func easeIn(_ t: CGFloat) -> CGFloat {
        return t * t
    }

    /// Ease out (slow end)
    static func easeOut(_ t: CGFloat) -> CGFloat {
        return t * (2 - t)
    }

    /// Ease in and out (slow start and end)
    static func easeInOut(_ t: CGFloat) -> CGFloat {
        if t < 0.5 {
            return 2 * t * t
        } else {
            return -1 + (4 - 2 * t) * t
        }
    }

    /// Cubic ease in
    static func easeInCubic(_ t: CGFloat) -> CGFloat {
        return t * t * t
    }

    /// Cubic ease out
    static func easeOutCubic(_ t: CGFloat) -> CGFloat {
        let f = t - 1
        return f * f * f + 1
    }

    /// Cubic ease in and out
    static func easeInOutCubic(_ t: CGFloat) -> CGFloat {
        if t < 0.5 {
            return 4 * t * t * t
        } else {
            let f = 2 * t - 2
            return 0.5 * f * f * f + 1
        }
    }

    /// Elastic ease out (bouncy)
    static func elasticOut(_ t: CGFloat) -> CGFloat {
        let p: CGFloat = 0.3
        return pow(2, -10 * t) * sin((t - p / 4) * (2 * .pi) / p) + 1
    }

    /// Back ease out (overshoot)
    static func backOut(_ t: CGFloat) -> CGFloat {
        let c1: CGFloat = 1.70158
        let c3 = c1 + 1
        return 1 + c3 * pow(t - 1, 3) + c1 * pow(t - 1, 2)
    }
}
