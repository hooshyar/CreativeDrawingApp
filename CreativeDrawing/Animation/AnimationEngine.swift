//
//  AnimationEngine.swift
//  CreativeDrawing
//
//  Core animation engine for live effects and playback
//

import UIKit

/// Protocol for objects that can receive animation updates
protocol AnimationEngineDelegate: AnyObject {
    /// Called each frame during animation
    func animationEngine(_ engine: AnimationEngine, didUpdateAtTime timeOffset: CFTimeInterval)

    /// Called when animation state changes
    func animationEngine(_ engine: AnimationEngine, didChangeState isAnimating: Bool)
}

/// Manages the animation loop using CADisplayLink for smooth 60fps rendering
class AnimationEngine {

    // MARK: - Properties

    weak var delegate: AnimationEngineDelegate?

    /// The display link driving the animation loop
    private var displayLink: CADisplayLink?

    /// Time when animation started
    private var animationStartTime: CFTimeInterval = 0

    /// Current time offset from animation start
    private(set) var currentTimeOffset: CFTimeInterval = 0

    /// Whether animation loop is currently running
    private(set) var isAnimating: Bool = false

    /// Target frame rate (default: 60fps)
    var targetFrameRate: Int = 60 {
        didSet {
            if #available(iOS 15.0, *) {
                displayLink?.preferredFrameRateRange = CAFrameRateRange(
                    minimum: Float(targetFrameRate / 2),
                    maximum: Float(targetFrameRate),
                    preferred: Float(targetFrameRate)
                )
            }
        }
    }

    /// Whether to pause animation when app enters background
    var pauseInBackground: Bool = true

    // MARK: - Initialization

    init() {
        setupNotifications()
    }

    deinit {
        stopAnimationLoop()
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Public Methods

    /// Start the animation loop
    func startAnimationLoop() {
        guard displayLink == nil else { return }

        animationStartTime = CACurrentMediaTime()

        displayLink = CADisplayLink(target: self, selector: #selector(animationTick(_:)))

        if #available(iOS 15.0, *) {
            displayLink?.preferredFrameRateRange = CAFrameRateRange(
                minimum: Float(targetFrameRate / 2),
                maximum: Float(targetFrameRate),
                preferred: Float(targetFrameRate)
            )
        }

        displayLink?.add(to: .main, forMode: .common)

        isAnimating = true
        delegate?.animationEngine(self, didChangeState: true)
    }

    /// Stop the animation loop
    func stopAnimationLoop() {
        displayLink?.invalidate()
        displayLink = nil

        isAnimating = false
        delegate?.animationEngine(self, didChangeState: false)
    }

    /// Pause the animation loop temporarily
    func pauseAnimationLoop() {
        displayLink?.isPaused = true
    }

    /// Resume the animation loop
    func resumeAnimationLoop() {
        displayLink?.isPaused = false
    }

    /// Reset the animation time to zero
    func resetTime() {
        animationStartTime = CACurrentMediaTime()
        currentTimeOffset = 0
    }

    // MARK: - Private Methods

    @objc private func animationTick(_ displayLink: CADisplayLink) {
        currentTimeOffset = CACurrentMediaTime() - animationStartTime
        delegate?.animationEngine(self, didUpdateAtTime: currentTimeOffset)
    }

    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }

    @objc private func appDidEnterBackground() {
        if pauseInBackground {
            pauseAnimationLoop()
        }
    }

    @objc private func appWillEnterForeground() {
        if pauseInBackground && isAnimating {
            resumeAnimationLoop()
        }
    }
}

// MARK: - Animation Timing Utilities

extension AnimationEngine {

    /// Calculate a smooth sine wave oscillation (0.0 to 1.0)
    static func sineWave(at time: CFTimeInterval, frequency: Double = 1.0, phase: Double = 0.0) -> CGFloat {
        return CGFloat((sin(time * frequency * 2.0 * .pi + phase) + 1.0) / 2.0)
    }

    /// Calculate a triangle wave oscillation (0.0 to 1.0)
    static func triangleWave(at time: CFTimeInterval, frequency: Double = 1.0) -> CGFloat {
        let normalizedTime = fmod(time * frequency, 1.0)
        return CGFloat(normalizedTime < 0.5 ? normalizedTime * 2.0 : 2.0 - normalizedTime * 2.0)
    }

    /// Calculate eased progress (0.0 to 1.0 input, eased output)
    static func easeInOut(_ t: CGFloat) -> CGFloat {
        return t * t * (3.0 - 2.0 * t)
    }

    /// Calculate bounce effect
    static func bounce(_ t: CGFloat) -> CGFloat {
        if t < 0.5 {
            return 4.0 * t * t * t
        } else {
            let f = (2.0 * t) - 2.0
            return 0.5 * f * f * f + 1.0
        }
    }
}

// MARK: - Animated Stroke Helpers

/// Configuration for sparkle animation
struct SparkleAnimationConfig {
    /// Speed of twinkling (cycles per second)
    let twinkleSpeed: Double

    /// Minimum scale during twinkle
    let minScale: CGFloat

    /// Maximum scale during twinkle
    let maxScale: CGFloat

    /// Minimum alpha during twinkle
    let minAlpha: CGFloat

    /// Maximum alpha during twinkle
    let maxAlpha: CGFloat

    static let `default` = SparkleAnimationConfig(
        twinkleSpeed: 3.0,
        minScale: 0.7,
        maxScale: 1.3,
        minAlpha: 0.6,
        maxAlpha: 1.0
    )

    static let subtle = SparkleAnimationConfig(
        twinkleSpeed: 2.0,
        minScale: 0.85,
        maxScale: 1.15,
        minAlpha: 0.7,
        maxAlpha: 1.0
    )

    static let intense = SparkleAnimationConfig(
        twinkleSpeed: 5.0,
        minScale: 0.5,
        maxScale: 1.5,
        minAlpha: 0.4,
        maxAlpha: 1.0
    )
}

/// Configuration for rainbow animation
struct RainbowAnimationConfig {
    /// Speed of hue cycling (full cycles per second)
    let cycleSpeed: Double

    /// Whether to animate saturation
    let animateSaturation: Bool

    /// Saturation variation amount (0.0 to 1.0)
    let saturationVariation: CGFloat

    static let `default` = RainbowAnimationConfig(
        cycleSpeed: 0.3,
        animateSaturation: false,
        saturationVariation: 0.0
    )

    static let slow = RainbowAnimationConfig(
        cycleSpeed: 0.15,
        animateSaturation: false,
        saturationVariation: 0.0
    )

    static let fast = RainbowAnimationConfig(
        cycleSpeed: 0.6,
        animateSaturation: true,
        saturationVariation: 0.2
    )
}

/// Calculates animation values for sparkle strokes
struct SparkleAnimator {

    /// Calculate twinkle value for a sparkle at a specific index and time
    static func twinkleValue(
        forIndex index: Int,
        atTime time: CFTimeInterval,
        config: SparkleAnimationConfig = .default
    ) -> (scale: CGFloat, alpha: CGFloat) {
        // Each sparkle has a different phase based on its index
        let phase = Double(index) * 0.5
        let twinklePhase = time * config.twinkleSpeed + phase
        let normalizedValue = (sin(twinklePhase) + 1.0) / 2.0  // 0.0 to 1.0

        let scale = config.minScale + CGFloat(normalizedValue) * (config.maxScale - config.minScale)
        let alpha = config.minAlpha + CGFloat(normalizedValue) * (config.maxAlpha - config.minAlpha)

        return (scale, alpha)
    }
}

/// Calculates animation values for rainbow strokes
struct RainbowAnimator {

    /// Calculate hue shift for rainbow stroke at a specific time
    static func hueShift(
        atTime time: CFTimeInterval,
        config: RainbowAnimationConfig = .default
    ) -> CGFloat {
        return CGFloat(fmod(time * config.cycleSpeed, 1.0))
    }

    /// Calculate animated hue from base hue
    static func animatedHue(
        baseHue: CGFloat,
        atTime time: CFTimeInterval,
        config: RainbowAnimationConfig = .default
    ) -> CGFloat {
        let shift = hueShift(atTime: time, config: config)
        return fmod(baseHue + shift, 1.0)
    }

    /// Calculate animated color from base hue
    static func animatedColor(
        baseHue: CGFloat,
        saturation: CGFloat = 1.0,
        brightness: CGFloat = 1.0,
        alpha: CGFloat = 1.0,
        atTime time: CFTimeInterval,
        config: RainbowAnimationConfig = .default
    ) -> UIColor {
        let animatedHue = self.animatedHue(baseHue: baseHue, atTime: time, config: config)

        var animatedSaturation = saturation
        if config.animateSaturation {
            let saturationOscillation = AnimationEngine.sineWave(at: time, frequency: 2.0)
            animatedSaturation = saturation - config.saturationVariation / 2 + saturationOscillation * config.saturationVariation
        }

        return UIColor(
            hue: animatedHue,
            saturation: animatedSaturation,
            brightness: brightness,
            alpha: alpha
        )
    }
}
