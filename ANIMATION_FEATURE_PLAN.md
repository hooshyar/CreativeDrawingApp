# Animation Features Implementation Plan

## Executive Summary

This document outlines a comprehensive plan to add **kid-friendly animation capabilities** to CreativeDrawing, enabling children to create shareable animated content for social media and family sharing.

### Proposed Features

| Feature | Description | Shareability |
|---------|-------------|--------------|
| **Glittering Sparkles** | Real-time animated particles on sparkle strokes | Video/GIF |
| **Rainbow Shimmer** | Color-cycling animation on rainbow strokes | Video/GIF |
| **Animation Trace** | Progressive stroke reveal effect | Video/GIF |
| **Drawing Timelapse** | Fast-forward replay of entire drawing creation | Video/GIF |
| **Stamp Bounce** | Gentle continuous animation on placed stamps | Video/GIF |

---

## Part 1: Technical Analysis

### Current Infrastructure (What We Have)

Your codebase is **remarkably well-prepared** for animation features:

| Component | Current State | Animation-Ready? |
|-----------|--------------|------------------|
| **Stroke timestamps** | ✅ Per-point `TimeInterval` captured | Perfect for playback |
| **Action history** | ✅ Full undo stack with ordering | Ready for timelapse |
| **Sparkle brush** | ✅ Individual particle positions | Needs animation loop |
| **Rainbow brush** | ✅ HSV color cycling logic exists | Needs real-time updates |
| **Image export** | ✅ `exportAsImage()` works | Needs frame capture |
| **Catmull-Rom smoothing** | ✅ Smooth curve interpolation | Perfect for progressive draw |

### What's Missing

```
┌─────────────────────────────────────────────────────────┐
│  MISSING COMPONENTS                                      │
├─────────────────────────────────────────────────────────┤
│  1. CADisplayLink animation loop (real-time effects)    │
│  2. Particle lifecycle system (glitter animation)       │
│  3. Frame capture pipeline (for video export)           │
│  4. AVAssetWriter video encoder                         │
│  5. GIF encoder                                         │
│  6. Playback state machine                              │
│  7. Animation preview UI                                │
│  8. Share sheet integration                             │
└─────────────────────────────────────────────────────────┘
```

---

## Part 2: Architecture Design

### New Components Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                    ANIMATION SYSTEM ARCHITECTURE                     │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ┌──────────────────┐    ┌──────────────────┐    ┌───────────────┐ │
│  │  AnimationEngine │───▶│  EffectAnimator  │───▶│ CAEmitterLayer│ │
│  │  (CADisplayLink) │    │  (Glitter/Rainbow)│    │ (Particles)   │ │
│  └────────┬─────────┘    └──────────────────┘    └───────────────┘ │
│           │                                                          │
│           ▼                                                          │
│  ┌──────────────────┐    ┌──────────────────┐    ┌───────────────┐ │
│  │ PlaybackEngine   │───▶│ StrokeAnimator   │───▶│ DrawingCanvas │ │
│  │ (Timelapse/Trace)│    │ (Progressive)    │    │ (Rendering)   │ │
│  └────────┬─────────┘    └──────────────────┘    └───────────────┘ │
│           │                                                          │
│           ▼                                                          │
│  ┌──────────────────┐    ┌──────────────────┐    ┌───────────────┐ │
│  │  VideoExporter   │───▶│ AVAssetWriter    │───▶│  MP4 / GIF    │ │
│  │  (Frame Capture) │    │ (H.264 Encoding) │    │  (Shareable)  │ │
│  └──────────────────┘    └──────────────────┘    └───────────────┘ │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### File Structure

```
CreativeDrawing/
├── Animation/
│   ├── AnimationEngine.swift         # CADisplayLink coordinator
│   ├── EffectAnimator.swift          # Glitter, rainbow shimmer
│   ├── PlaybackEngine.swift          # Timelapse, trace playback
│   ├── StrokeAnimator.swift          # Progressive stroke reveal
│   └── ParticleSystem.swift          # CAEmitterLayer wrapper
├── Export/
│   ├── VideoExporter.swift           # AVAssetWriter pipeline
│   ├── GIFExporter.swift             # GIF encoding
│   └── FrameCapturer.swift           # Canvas snapshot system
├── UI/
│   ├── AnimationPreviewController.swift  # Preview/export UI
│   ├── PlaybackControlsView.swift        # Play/pause/speed
│   └── ShareAnimationView.swift          # Share sheet wrapper
└── Models/
    └── AnimationSettings.swift       # User preferences
```

---

## Part 3: Feature Specifications

### 3.1 Glittering Sparkles ✨

**Goal**: Make sparkle brush strokes come alive with twinkling particles

**Technical Approach**:
- Use `CAEmitterLayer` for GPU-accelerated particles
- Particles spawn at existing sparkle positions from stroke data
- Each particle has: birth rate, lifetime, velocity, scale animation, alpha fade

**Particle Properties**:
```swift
struct GlitterParticle {
    let position: CGPoint
    let birthTime: TimeInterval
    let lifetime: TimeInterval      // 0.3 - 0.8 seconds
    let maxScale: CGFloat           // 0.5 - 1.5x
    let rotationSpeed: CGFloat      // Random spin
    let fadeInDuration: CGFloat     // 0.1s
    let fadeOutDuration: CGFloat    // 0.2s
}
```

**Animation Cycle**:
1. Particle spawns at stroke point (from existing sparkle data)
2. Scales up quickly (0.1s)
3. Holds at peak brightness (0.3s)
4. Fades out gradually (0.2s)
5. New particle spawns at nearby offset

**Visual Reference**:
```
Frame 0:    ·  ✦  ·  ✧  ·
Frame 10:   ✧  ·  ✦  ·  ✧
Frame 20:   ·  ✧  ·  ✦  ·
Frame 30:   ✦  ·  ✧  ·  ✦
```

### 3.2 Rainbow Shimmer 🌈

**Goal**: Rainbow strokes slowly cycle through colors, creating a magical effect

**Technical Approach**:
- Extend existing `drawRainbowStroke()` with time-based hue offset
- Use `CADisplayLink` to update `hueOffset` each frame
- Shift entire stroke's color spectrum by offset value

**Algorithm**:
```swift
// Current: hue = pointIndex / totalPoints * 2.0 (static)
// Animated: hue = (pointIndex / totalPoints * 2.0) + (time * cycleSpeed)

let cycleSpeed: CGFloat = 0.5  // Full spectrum cycle in 2 seconds
let animatedHue = (baseHue + (elapsedTime * cycleSpeed)).truncatingRemainder(dividingBy: 1.0)
```

**Color Flow**:
```
Time 0.0s:  🔴🟠🟡🟢🔵🟣
Time 0.5s:  🟣🔴🟠🟡🟢🔵
Time 1.0s:  🔵🟣🔴🟠🟡🟢
Time 1.5s:  🟢🔵🟣🔴🟠🟡
Time 2.0s:  🔴🟠🟡🟢🔵🟣  (cycle complete)
```

### 3.3 Animation Trace ✏️

**Goal**: Strokes appear progressively, like watching someone draw in real-time

**Technical Approach**:
- Use existing `Stroke.smoothedPoints()`
- Render partial stroke (points 0...N) where N increases over time
- Add "pen tip" indicator at current position

**Modes**:
| Mode | Description | Use Case |
|------|-------------|----------|
| **Continuous** | All strokes reveal simultaneously | Artistic effect |
| **Sequential** | One stroke at a time, in order | True timelapse |
| **Dramatic** | Pause between strokes | Reveal effect |

**Pen Tip Effect**:
- Small glowing dot at the "current" drawing position
- Slight particle trail behind the tip
- Matches the brush color

### 3.4 Drawing Timelapse ⏱️

**Goal**: Replay the entire drawing creation at 10-50x speed

**Technical Approach**:
- Leverage existing `actionHistory` from `DrawingDocument`
- Each stroke has `createdAt` timestamp
- Calculate relative timings and compress to target duration

**Speed Calculation**:
```swift
let totalDrawingTime = lastStroke.createdAt - firstStroke.createdAt  // e.g., 5 minutes
let targetDuration: TimeInterval = 15  // 15-second video
let speedMultiplier = totalDrawingTime / targetDuration  // 20x speed

// Per-stroke timing:
for stroke in strokes {
    let relativeTime = stroke.createdAt - firstStroke.createdAt
    let playbackTime = relativeTime / speedMultiplier
}
```

**Timelapse Options**:
| Duration | Speed | Best For |
|----------|-------|----------|
| 5 seconds | 60x | Instagram Stories |
| 15 seconds | 20x | TikTok/Reels |
| 30 seconds | 10x | YouTube Shorts |
| Full speed | 1x | Detailed tutorial |

### 3.5 Stamp Bounce 🎈

**Goal**: Placed stamps gently bounce/pulse to add life

**Technical Approach**:
- Apply subtle scale animation to stamp images
- Use sine wave for organic breathing effect
- Different stamps can have different bounce patterns

**Animation Curve**:
```swift
let breathingScale = 1.0 + (sin(elapsedTime * 2.0 * .pi) * 0.05)  // ±5% scale
stamp.transform = CGAffineTransform(scaleX: breathingScale, y: breathingScale)
```

---

## Part 4: Export System

### Video Export Pipeline

```
┌─────────────────────────────────────────────────────────────────┐
│                     VIDEO EXPORT PIPELINE                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  1. PREPARE                                                      │
│     ├── Calculate frame count (duration × fps)                  │
│     ├── Ensure dimensions are multiples of 16                   │
│     └── Configure AVAssetWriter with H.264 codec                │
│                                                                  │
│  2. RENDER FRAMES                                                │
│     ├── For each frame time:                                    │
│     │   ├── Update animation state (glitter, rainbow, etc.)     │
│     │   ├── Render canvas to UIImage                            │
│     │   ├── Convert UIImage → CVPixelBuffer                     │
│     │   └── Append buffer with CMTime                           │
│     └── Show progress to user                                   │
│                                                                  │
│  3. FINALIZE                                                     │
│     ├── Finish writing                                          │
│     ├── Move to Photos library (optional)                       │
│     └── Return URL for sharing                                  │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Export Formats

| Format | Resolution | FPS | File Size | Best For |
|--------|------------|-----|-----------|----------|
| **MP4 (H.264)** | Canvas size | 30 | ~2-5 MB | Universal sharing |
| **GIF** | 480px max | 15 | ~1-3 MB | Quick previews |
| **HEVC** | Canvas size | 30 | ~1-3 MB | Modern devices |

### Social Media Specifications

| Platform | Max Duration | Ideal Resolution | Format |
|----------|--------------|------------------|--------|
| Instagram Stories | 15s | 1080×1920 | MP4 |
| TikTok | 60s | 1080×1920 | MP4 |
| iMessage | Any | Any | GIF/MP4 |
| Family Sharing | Any | Original | MP4 |

---

## Part 5: User Experience Design

### Animation Preview UI

```
┌─────────────────────────────────────────────────┐
│  ← Back                    Animation Preview    │
├─────────────────────────────────────────────────┤
│                                                  │
│  ┌─────────────────────────────────────────┐   │
│  │                                          │   │
│  │                                          │   │
│  │        [Canvas Preview Area]             │   │
│  │        (Shows live animation)            │   │
│  │                                          │   │
│  │                                          │   │
│  └─────────────────────────────────────────┘   │
│                                                  │
│  ──●────────────────────────────── 0:05 / 0:15  │
│                                                  │
│        ◀◀     ▶ / ⏸     ▶▶                      │
│                                                  │
├─────────────────────────────────────────────────┤
│  Animation Type:                                 │
│  ┌─────────┐ ┌─────────┐ ┌─────────┐           │
│  │ Timelapse│ │  Trace  │ │ Effects │           │
│  │  (15s)   │ │ (10s)   │ │  Only   │           │
│  └─────────┘ └─────────┘ └─────────┘           │
│                                                  │
│  ⚡ Include Effects:                             │
│  [✓] Glitter Animation                          │
│  [✓] Rainbow Shimmer                            │
│  [✓] Stamp Bounce                               │
│                                                  │
├─────────────────────────────────────────────────┤
│  ┌───────────────────────────────────────────┐  │
│  │        📤 Share Animation                  │  │
│  └───────────────────────────────────────────┘  │
└─────────────────────────────────────────────────┘
```

### Kid-Friendly Design Principles

1. **Big, Clear Buttons**: Touch targets minimum 44pt
2. **Instant Feedback**: Haptic + visual on every tap
3. **Simple Choices**: Max 3 options at once
4. **Fun Sounds**: Cheerful audio feedback
5. **Progress Celebration**: Confetti when export completes

### Parental Controls

```swift
struct AnimationSettings {
    var shareEnabled: Bool = true           // Parent can disable
    var autoSaveToPhotos: Bool = false      // Require parent approval
    var maxExportDuration: TimeInterval = 30 // Limit video length
    var watermarkEnabled: Bool = true       // "Made with CreativeDrawing"
}
```

---

## Part 6: Implementation Phases

### Phase 1: Animation Engine Foundation (Week 1-2)
**Priority: Critical**

| Task | Description | Files |
|------|-------------|-------|
| Create AnimationEngine | CADisplayLink coordinator | `AnimationEngine.swift` |
| Add time tracking | Elapsed time for all effects | `AnimationEngine.swift` |
| Implement EffectAnimator | Base class for effects | `EffectAnimator.swift` |
| Update DrawingCanvas | Support animated rendering | `DrawingCanvas.swift` |

**Deliverable**: Real-time animation loop running at 60fps

### Phase 2: Visual Effects (Week 3-4)
**Priority: High**

| Task | Description | Files |
|------|-------------|-------|
| Glitter particle system | CAEmitterLayer-based sparkles | `ParticleSystem.swift` |
| Rainbow shimmer | Animated hue cycling | `EffectAnimator.swift` |
| Stamp bounce | Breathing scale animation | `EffectAnimator.swift` |
| Effect toggle UI | Enable/disable effects | `DrawingViewController.swift` |

**Deliverable**: Live animated effects on canvas

### Phase 3: Playback System (Week 5-6)
**Priority: High**

| Task | Description | Files |
|------|-------------|-------|
| PlaybackEngine | State machine for playback | `PlaybackEngine.swift` |
| StrokeAnimator | Progressive stroke reveal | `StrokeAnimator.swift` |
| Speed controls | 1x, 5x, 10x, 20x multipliers | `PlaybackEngine.swift` |
| Pen tip effect | Indicator at draw position | `StrokeAnimator.swift` |

**Deliverable**: Drawing timelapse playback with speed control

### Phase 4: Export Pipeline (Week 7-8)
**Priority: High**

| Task | Description | Files |
|------|-------------|-------|
| FrameCapturer | Canvas snapshot system | `FrameCapturer.swift` |
| VideoExporter | AVAssetWriter integration | `VideoExporter.swift` |
| GIFExporter | Animated GIF generation | `GIFExporter.swift` |
| Progress UI | Export progress indicator | UI files |

**Deliverable**: MP4 and GIF export working

### Phase 5: Share Integration (Week 9-10)
**Priority: Medium**

| Task | Description | Files |
|------|-------------|-------|
| AnimationPreviewController | Full preview UI | `AnimationPreviewController.swift` |
| Share sheet | UIActivityViewController | `ShareAnimationView.swift` |
| Save to Photos | PHPhotoLibrary integration | `VideoExporter.swift` |
| Social presets | Optimized export settings | `AnimationSettings.swift` |

**Deliverable**: Complete share flow with social media optimization

### Phase 6: Polish & Testing (Week 11-12)
**Priority: Medium**

| Task | Description | Files |
|------|-------------|-------|
| Performance optimization | Memory management, frame drops | All |
| Battery testing | Ensure reasonable power usage | All |
| Accessibility | VoiceOver support | UI files |
| Unit tests | Test animation timing, export | Test files |

**Deliverable**: Production-ready animation features

---

## Part 7: Technical Specifications

### AnimationEngine.swift

```swift
import UIKit

protocol AnimationEngineDelegate: AnyObject {
    func animationEngineDidUpdate(_ engine: AnimationEngine, elapsedTime: TimeInterval)
}

final class AnimationEngine {

    // MARK: - Properties

    weak var delegate: AnimationEngineDelegate?

    private var displayLink: CADisplayLink?
    private var startTime: CFTimeInterval = 0
    private var pausedTime: CFTimeInterval = 0
    private var isPaused: Bool = false

    var isRunning: Bool { displayLink != nil }
    var elapsedTime: TimeInterval {
        guard !isPaused else { return pausedTime - startTime }
        return CACurrentMediaTime() - startTime
    }

    // MARK: - Effect Animators

    private var glitterAnimator: GlitterAnimator?
    private var rainbowAnimator: RainbowAnimator?
    private var stampAnimator: StampBounceAnimator?

    // MARK: - Lifecycle

    func start() {
        guard displayLink == nil else { return }

        startTime = CACurrentMediaTime()
        displayLink = CADisplayLink(target: self, selector: #selector(tick))
        displayLink?.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 60)
        displayLink?.add(to: .main, forMode: .common)
    }

    func pause() {
        isPaused = true
        pausedTime = CACurrentMediaTime()
    }

    func resume() {
        let pauseDuration = CACurrentMediaTime() - pausedTime
        startTime += pauseDuration
        isPaused = false
    }

    func stop() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func tick(_ link: CADisplayLink) {
        guard !isPaused else { return }

        let time = elapsedTime

        // Update all animators
        glitterAnimator?.update(time: time)
        rainbowAnimator?.update(time: time)
        stampAnimator?.update(time: time)

        delegate?.animationEngineDidUpdate(self, elapsedTime: time)
    }
}
```

### GlitterAnimator (CAEmitterLayer approach)

```swift
import UIKit

final class GlitterAnimator {

    private weak var canvas: DrawingCanvas?
    private var emitterLayers: [CAEmitterLayer] = []

    func setupForStrokes(_ strokes: [Stroke], in canvas: DrawingCanvas) {
        self.canvas = canvas
        removeAllEmitters()

        let sparkleStrokes = strokes.filter { $0.brushType == .sparkle }

        for stroke in sparkleStrokes {
            let emitter = createEmitterLayer(for: stroke)
            canvas.layer.addSublayer(emitter)
            emitterLayers.append(emitter)
        }
    }

    private func createEmitterLayer(for stroke: Stroke) -> CAEmitterLayer {
        let emitter = CAEmitterLayer()
        emitter.emitterShape = .point
        emitter.renderMode = .additive

        // Create emitter cell for sparkle
        let cell = CAEmitterCell()
        cell.birthRate = 3
        cell.lifetime = 0.8
        cell.velocity = 20
        cell.velocityRange = 10
        cell.emissionRange = .pi * 2
        cell.scale = 0.05
        cell.scaleRange = 0.03
        cell.scaleSpeed = -0.02
        cell.alphaSpeed = -0.8
        cell.spin = 2
        cell.spinRange = 4

        // Use star image (SF Symbol or custom)
        cell.contents = UIImage(systemName: "sparkle")?.cgImage
        cell.color = stroke.color.cgColor

        emitter.emitterCells = [cell]

        // Position emitter along stroke path
        let points = stroke.smoothedPoints(granularity: 4)
        if let midpoint = points[safe: points.count / 2] {
            emitter.emitterPosition = midpoint.position
        }

        return emitter
    }

    func update(time: TimeInterval) {
        // Animate emitter positions or properties if needed
        for (index, emitter) in emitterLayers.enumerated() {
            // Subtle position oscillation
            let offsetX = sin(time * 2 + Double(index)) * 3
            let offsetY = cos(time * 2 + Double(index)) * 3
            emitter.emitterPosition.x += CGFloat(offsetX) * 0.1
            emitter.emitterPosition.y += CGFloat(offsetY) * 0.1
        }
    }

    private func removeAllEmitters() {
        emitterLayers.forEach { $0.removeFromSuperlayer() }
        emitterLayers.removeAll()
    }
}
```

### RainbowAnimator

```swift
import UIKit

final class RainbowAnimator {

    private weak var canvas: DrawingCanvas?
    private var hueOffset: CGFloat = 0
    private let cycleSpeed: CGFloat = 0.3  // Full cycle in ~3.3 seconds

    var currentHueOffset: CGFloat { hueOffset }

    func update(time: TimeInterval) {
        // Smoothly cycle through hue spectrum
        hueOffset = CGFloat(time * Double(cycleSpeed)).truncatingRemainder(dividingBy: 1.0)

        // Trigger canvas redraw for rainbow strokes
        canvas?.setNeedsDisplay()
    }
}
```

### VideoExporter

```swift
import AVFoundation
import UIKit

final class VideoExporter {

    enum ExportError: Error {
        case cannotCreateWriter
        case cannotCreateInput
        case cannotCreatePixelBuffer
        case writingFailed(Error)
    }

    struct ExportSettings {
        var fps: Int32 = 30
        var duration: TimeInterval = 15
        var includeAudio: Bool = false
        var codec: AVVideoCodecType = .h264
    }

    typealias ProgressHandler = (Float) -> Void
    typealias CompletionHandler = (Result<URL, ExportError>) -> Void

    func export(
        canvas: DrawingCanvas,
        animationEngine: AnimationEngine,
        settings: ExportSettings,
        progress: @escaping ProgressHandler,
        completion: @escaping CompletionHandler
    ) {
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp4")

        // Ensure dimensions are multiples of 16
        let width = Int(canvas.bounds.width) / 16 * 16
        let height = Int(canvas.bounds.height) / 16 * 16
        let size = CGSize(width: width, height: height)

        guard let writer = try? AVAssetWriter(outputURL: outputURL, fileType: .mp4) else {
            completion(.failure(.cannotCreateWriter))
            return
        }

        let videoSettings: [String: Any] = [
            AVVideoCodecKey: settings.codec,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height
        ]

        let input = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        input.expectsMediaDataInRealTime = false

        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
                kCVPixelBufferWidthKey as String: width,
                kCVPixelBufferHeightKey as String: height
            ]
        )

        writer.add(input)
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)

        let totalFrames = Int(settings.duration * Double(settings.fps))
        let frameDuration = CMTime(value: 1, timescale: settings.fps)

        DispatchQueue.global(qos: .userInitiated).async {
            for frameIndex in 0..<totalFrames {
                autoreleasepool {
                    let time = Double(frameIndex) / Double(settings.fps)

                    // Update animation state
                    DispatchQueue.main.sync {
                        animationEngine.setTime(time)
                    }

                    // Render frame
                    if let image = self.captureFrame(canvas: canvas, size: size),
                       let pixelBuffer = self.createPixelBuffer(from: image, size: size) {

                        let presentationTime = CMTimeMultiply(frameDuration, multiplier: Int32(frameIndex))

                        while !input.isReadyForMoreMediaData {
                            Thread.sleep(forTimeInterval: 0.01)
                        }

                        adaptor.append(pixelBuffer, withPresentationTime: presentationTime)
                    }

                    let progressValue = Float(frameIndex + 1) / Float(totalFrames)
                    DispatchQueue.main.async {
                        progress(progressValue)
                    }
                }
            }

            input.markAsFinished()
            writer.finishWriting {
                DispatchQueue.main.async {
                    if writer.status == .completed {
                        completion(.success(outputURL))
                    } else if let error = writer.error {
                        completion(.failure(.writingFailed(error)))
                    }
                }
            }
        }
    }

    private func captureFrame(canvas: DrawingCanvas, size: CGSize) -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            canvas.layer.render(in: context.cgContext)
        }
    }

    private func createPixelBuffer(from image: UIImage, size: CGSize) -> CVPixelBuffer? {
        let attrs: [String: Any] = [
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
        ]

        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            Int(size.width),
            Int(size.height),
            kCVPixelFormatType_32ARGB,
            attrs as CFDictionary,
            &pixelBuffer
        )

        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            return nil
        }

        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }

        let context = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
        )

        if let cgImage = image.cgImage {
            context?.draw(cgImage, in: CGRect(origin: .zero, size: size))
        }

        return buffer
    }
}
```

### PlaybackEngine

```swift
import Foundation

protocol PlaybackEngineDelegate: AnyObject {
    func playbackEngine(_ engine: PlaybackEngine, shouldDrawStroke stroke: Stroke, progress: CGFloat)
    func playbackEngine(_ engine: PlaybackEngine, didUpdateProgress progress: CGFloat)
    func playbackEngineDidFinish(_ engine: PlaybackEngine)
}

final class PlaybackEngine {

    enum State {
        case idle
        case playing
        case paused
        case finished
    }

    enum Mode {
        case timelapse(duration: TimeInterval)  // Compress to fixed duration
        case realtime(speed: CGFloat)           // 1x, 2x, 5x, etc.
        case trace(strokeDuration: TimeInterval) // Each stroke takes fixed time
    }

    weak var delegate: PlaybackEngineDelegate?

    private(set) var state: State = .idle
    private var strokes: [Stroke] = []
    private var mode: Mode = .timelapse(duration: 15)

    private var startTime: TimeInterval = 0
    private var pausedTime: TimeInterval = 0
    private var displayLink: CADisplayLink?

    private var strokeTimeline: [(stroke: Stroke, startTime: TimeInterval, endTime: TimeInterval)] = []

    func prepare(strokes: [Stroke], mode: Mode) {
        self.strokes = strokes.sorted { $0.createdAt < $1.createdAt }
        self.mode = mode

        buildTimeline()
        state = .idle
    }

    private func buildTimeline() {
        guard let firstStroke = strokes.first else { return }

        strokeTimeline.removeAll()

        switch mode {
        case .timelapse(let duration):
            // Compress entire drawing into target duration
            guard let lastStroke = strokes.last else { return }
            let totalTime = lastStroke.createdAt.timeIntervalSince(firstStroke.createdAt)
            let speedMultiplier = max(totalTime / duration, 1)

            for stroke in strokes {
                let relativeStart = stroke.createdAt.timeIntervalSince(firstStroke.createdAt) / speedMultiplier
                let strokeDuration = calculateStrokeDuration(stroke) / speedMultiplier
                strokeTimeline.append((stroke, relativeStart, relativeStart + strokeDuration))
            }

        case .realtime(let speed):
            for stroke in strokes {
                let relativeStart = stroke.createdAt.timeIntervalSince(firstStroke.createdAt) / Double(speed)
                let strokeDuration = calculateStrokeDuration(stroke) / Double(speed)
                strokeTimeline.append((stroke, relativeStart, relativeStart + strokeDuration))
            }

        case .trace(let strokeDuration):
            var currentTime: TimeInterval = 0
            for stroke in strokes {
                strokeTimeline.append((stroke, currentTime, currentTime + strokeDuration))
                currentTime += strokeDuration + 0.2  // Small gap between strokes
            }
        }
    }

    private func calculateStrokeDuration(_ stroke: Stroke) -> TimeInterval {
        guard let first = stroke.points.first, let last = stroke.points.last else { return 0.5 }
        return max(last.timestamp - first.timestamp, 0.3)
    }

    func play() {
        guard state != .playing else { return }

        if state == .paused {
            let pauseDuration = CACurrentMediaTime() - pausedTime
            startTime += pauseDuration
        } else {
            startTime = CACurrentMediaTime()
        }

        state = .playing

        displayLink = CADisplayLink(target: self, selector: #selector(tick))
        displayLink?.add(to: .main, forMode: .common)
    }

    func pause() {
        state = .paused
        pausedTime = CACurrentMediaTime()
        displayLink?.invalidate()
        displayLink = nil
    }

    func stop() {
        state = .idle
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func tick() {
        let elapsed = CACurrentMediaTime() - startTime

        guard let lastEntry = strokeTimeline.last else { return }
        let totalDuration = lastEntry.endTime

        let progress = CGFloat(min(elapsed / totalDuration, 1.0))
        delegate?.playbackEngine(self, didUpdateProgress: progress)

        // Notify delegate about strokes that should be drawn
        for entry in strokeTimeline {
            if elapsed >= entry.startTime && elapsed <= entry.endTime {
                let strokeProgress = CGFloat((elapsed - entry.startTime) / (entry.endTime - entry.startTime))
                delegate?.playbackEngine(self, shouldDrawStroke: entry.stroke, progress: strokeProgress)
            }
        }

        if elapsed >= totalDuration {
            state = .finished
            displayLink?.invalidate()
            displayLink = nil
            delegate?.playbackEngineDidFinish(self)
        }
    }
}
```

---

## Part 8: Memory & Performance Considerations

### Memory Management

| Concern | Solution |
|---------|----------|
| Frame buffer allocation | Use `autoreleasepool` per frame |
| Pixel buffer reuse | Pool and reuse CVPixelBuffers |
| Large canvas sizes | Downsample for GIF export |
| CAEmitterLayer count | Max 20 emitters, remove off-screen |

### Performance Targets

| Metric | Target | Acceptable |
|--------|--------|------------|
| Animation FPS | 60 | 30 |
| Export time (15s video) | < 30s | < 60s |
| Memory during export | < 200MB | < 400MB |
| Battery impact (animation) | Low | Medium |

### Optimization Strategies

1. **Lazy emitter creation**: Only create CAEmitterLayers for visible sparkle strokes
2. **Render caching**: Cache static parts, only re-render animated elements
3. **Adaptive frame rate**: Drop to 30fps if device is struggling
4. **Background export**: Use lower priority queue, show progress
5. **Frame skipping**: Skip frames if behind schedule during playback

---

## Part 9: Testing Strategy

### Unit Tests

```swift
// AnimationEngineTests.swift
func testAnimationEngineStartsAndStops() {
    let engine = AnimationEngine()
    XCTAssertFalse(engine.isRunning)

    engine.start()
    XCTAssertTrue(engine.isRunning)

    engine.stop()
    XCTAssertFalse(engine.isRunning)
}

func testRainbowAnimatorHueCycling() {
    let animator = RainbowAnimator()

    animator.update(time: 0)
    XCTAssertEqual(animator.currentHueOffset, 0, accuracy: 0.01)

    animator.update(time: 3.33)  // Full cycle at 0.3 speed
    XCTAssertEqual(animator.currentHueOffset, 0, accuracy: 0.1)
}

func testPlaybackEngineTimelapse() {
    let engine = PlaybackEngine()
    let strokes = createTestStrokes(count: 10, totalDuration: 60)

    engine.prepare(strokes: strokes, mode: .timelapse(duration: 15))
    // Verify timeline compression
}
```

### Integration Tests

- Export generates valid MP4 file
- Exported video plays in Photos app
- Share sheet accepts exported content
- Animations render at correct speed

### Manual Testing Checklist

- [ ] Glitter sparkles on multiple sparkle strokes
- [ ] Rainbow shimmer cycles smoothly
- [ ] Timelapse plays entire drawing
- [ ] Export progress shows correctly
- [ ] Share sheet opens with video
- [ ] Works on iPad and iPhone
- [ ] Performance acceptable on older devices (iPhone 11)

---

## Part 10: Dependencies & Resources

### No External Dependencies Required

All features can be built with native iOS frameworks:

| Framework | Usage |
|-----------|-------|
| AVFoundation | Video export (AVAssetWriter) |
| CoreGraphics | Frame rendering |
| QuartzCore | CADisplayLink, CAEmitterLayer |
| Photos | Save to library |
| UIKit | Share sheet, UI |

### Optional Enhancements

| Library | Purpose | Benefit |
|---------|---------|---------|
| [Gifsicle](https://www.lcdf.org/gifsicle/) | GIF optimization | Smaller file sizes |
| [lottie-ios](https://github.com/airbnb/lottie-ios) | Pre-made animations | Richer effects |

### References

- [AVAssetWriter Apple Docs](https://developer.apple.com/documentation/avfoundation/avassetwriter)
- [CAEmitterLayer - NSHipster](https://nshipster.com/caemitterlayer/)
- [Creating Videos from Images](https://img.ly/blog/how-to-make-videos-from-still-images-with-avfoundation-and-swift/)
- [Twinkle Sparkle Library](https://github.com/piemonte/Twinkle)

---

## Summary

This plan provides a **complete roadmap** for adding professional, kid-friendly animation features to CreativeDrawing. The architecture leverages your existing well-designed codebase while adding the necessary animation and export infrastructure.

**Key Decisions:**
1. Use **CADisplayLink** for real-time animations (not timers)
2. Use **CAEmitterLayer** for particle effects (GPU-accelerated)
3. Use **AVAssetWriter** for video export (native, no dependencies)
4. Build **modular animators** that can be combined
5. Support **social media presets** for easy sharing

The phased approach allows delivering value incrementally while building toward the complete feature set.
