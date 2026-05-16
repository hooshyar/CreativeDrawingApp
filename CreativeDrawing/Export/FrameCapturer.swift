//
//  FrameCapturer.swift
//  CreativeDrawing
//
//  Renders frames at specific progress points for export
//

import UIKit
import CoreVideo

/// Captures frames from PlaybackEngine render states for video/GIF export
class FrameCapturer {

    // MARK: - Properties

    /// The playback engine providing render states
    private let playbackEngine: PlaybackEngine

    /// Canvas used for rendering
    private let playbackCanvas: PlaybackCanvas

    /// Export configuration
    private let configuration: ExportConfiguration

    /// Cached CGContext for reuse
    private var cachedContext: CGContext?

    /// Pixel buffer pool for video export
    private var pixelBufferPool: CVPixelBufferPool?

    // MARK: - Initialization

    init(
        document: DrawingDocument,
        canvasSize: CGSize,
        configuration: ExportConfiguration,
        playbackMode: PlaybackMode
    ) {
        self.playbackEngine = PlaybackEngine()
        self.playbackCanvas = PlaybackCanvas(frame: CGRect(origin: .zero, size: configuration.resolution))
        self.configuration = configuration

        // Configure playback engine
        playbackEngine.configure(
            document: document,
            canvasSize: canvasSize,
            mode: playbackMode
        )

        // Configure canvas
        playbackCanvas.showPenTip = false
        playbackCanvas.backgroundColor = configuration.backgroundColor ?? document.backgroundColor

        // Pre-create pixel buffer pool for video export
        if configuration.format == .mp4 {
            setupPixelBufferPool()
        }
    }

    deinit {
        cachedContext = nil
        pixelBufferPool = nil
    }

    // MARK: - Frame Rendering

    /// Render a frame at a specific progress (0.0 to 1.0)
    /// - Parameters:
    ///   - progress: Progress through the animation (0.0 to 1.0)
    ///   - timeOffset: Time offset for live effects animation
    /// - Returns: Rendered UIImage or nil if rendering failed
    func renderFrame(atProgress progress: CGFloat, timeOffset: CFTimeInterval = 0) -> UIImage? {
        let clampedProgress = max(0, min(1, progress))
        let currentTime = TimeInterval(clampedProgress) * configuration.duration

        // Get render state from playback engine
        let renderState = playbackEngine.calculateRenderState(at: currentTime)

        // Render to image
        return playbackCanvas.renderState(
            renderState,
            size: configuration.resolution,
            timeOffset: configuration.includeLiveEffects ? timeOffset : 0
        )
    }

    /// Render a frame at a specific frame index
    /// - Parameter frameIndex: Frame index (0 to totalFrames-1)
    /// - Returns: Rendered UIImage or nil if rendering failed
    func renderFrame(atIndex frameIndex: Int) -> UIImage? {
        let progress = CGFloat(frameIndex) / CGFloat(max(configuration.totalFrames - 1, 1))
        let timeOffset = CFTimeInterval(frameIndex) * configuration.frameDuration
        return renderFrame(atProgress: progress, timeOffset: timeOffset)
    }

    // MARK: - Pixel Buffer Creation

    /// Create a CVPixelBuffer from a UIImage
    /// - Parameters:
    ///   - image: Source image
    ///   - size: Target size (should match configuration.alignedResolution)
    /// - Returns: CVPixelBuffer or nil if creation failed
    func createPixelBuffer(from image: UIImage, size: CGSize) -> CVPixelBuffer? {
        // Try to use pooled buffer first
        if let pool = pixelBufferPool {
            var pixelBuffer: CVPixelBuffer?
            let status = CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pixelBuffer)

            if status == kCVReturnSuccess, let buffer = pixelBuffer {
                return fillPixelBuffer(buffer, with: image, size: size)
            }
        }

        // Fall back to creating a new buffer
        return createNewPixelBuffer(from: image, size: size)
    }

    /// Create a new pixel buffer (without pool)
    private func createNewPixelBuffer(from image: UIImage, size: CGSize) -> CVPixelBuffer? {
        let width = Int(size.width)
        let height = Int(size.height)

        let attributes: [CFString: Any] = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true,
            kCVPixelBufferWidthKey: width,
            kCVPixelBufferHeightKey: height
        ]

        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32ARGB,
            attributes as CFDictionary,
            &pixelBuffer
        )

        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            return nil
        }

        return fillPixelBuffer(buffer, with: image, size: size)
    }

    /// Fill a pixel buffer with image content
    private func fillPixelBuffer(_ pixelBuffer: CVPixelBuffer, with image: UIImage, size: CGSize) -> CVPixelBuffer? {
        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }

        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            return nil
        }

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)

        guard let context = CGContext(
            data: baseAddress,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else {
            return nil
        }

        // Flip context for UIKit coordinate system
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1, y: -1)

        // Draw image
        if let cgImage = image.cgImage {
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        } else {
            // Render UIImage if no cgImage available
            UIGraphicsPushContext(context)
            image.draw(in: CGRect(x: 0, y: 0, width: width, height: height))
            UIGraphicsPopContext()
        }

        return pixelBuffer
    }

    // MARK: - Pixel Buffer Pool

    /// Setup pixel buffer pool for efficient memory reuse
    private func setupPixelBufferPool() {
        let size = configuration.alignedResolution
        let width = Int(size.width)
        let height = Int(size.height)

        let poolAttributes: [CFString: Any] = [
            kCVPixelBufferPoolMinimumBufferCountKey: 3
        ]

        let pixelBufferAttributes: [CFString: Any] = [
            kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_32ARGB,
            kCVPixelBufferWidthKey: width,
            kCVPixelBufferHeightKey: height,
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true
        ]

        var pool: CVPixelBufferPool?
        CVPixelBufferPoolCreate(
            nil,
            poolAttributes as CFDictionary,
            pixelBufferAttributes as CFDictionary,
            &pool
        )

        pixelBufferPool = pool
    }

    // MARK: - CGImage Conversion

    /// Convert UIImage to CGImage for GIF export
    /// - Parameter image: Source UIImage
    /// - Returns: CGImage or nil if conversion failed
    func cgImage(from image: UIImage) -> CGImage? {
        if let cgImage = image.cgImage {
            return cgImage
        }

        // Render to CGImage if not directly available
        let size = image.size
        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
        defer { UIGraphicsEndImageContext() }

        image.draw(in: CGRect(origin: .zero, size: size))

        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        return context.makeImage()
    }

    // MARK: - Batch Rendering

    /// Render all frames and call handler for each
    /// - Parameters:
    ///   - progressHandler: Called for each frame with progress update
    ///   - frameHandler: Called for each rendered frame
    ///   - completion: Called when all frames are rendered
    func renderAllFrames(
        progressHandler: ((ExportProgress) -> Void)? = nil,
        frameHandler: @escaping (Int, UIImage) -> Bool,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        let totalFrames = configuration.totalFrames
        let startTime = CFAbsoluteTimeGetCurrent()

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else {
                completion(.failure(ExportError.cancelled))
                return
            }

            for frameIndex in 0..<totalFrames {
                autoreleasepool {
                    // Render frame
                    guard let image = self.renderFrame(atIndex: frameIndex) else {
                        DispatchQueue.main.async {
                            completion(.failure(ExportError.failedToRenderFrame(frameIndex)))
                        }
                        return
                    }

                    // Call frame handler
                    let shouldContinue = frameHandler(frameIndex, image)
                    if !shouldContinue {
                        DispatchQueue.main.async {
                            completion(.failure(ExportError.cancelled))
                        }
                        return
                    }

                    // Update progress
                    if let progressHandler = progressHandler {
                        let elapsed = CFAbsoluteTimeGetCurrent() - startTime
                        let framesRemaining = totalFrames - frameIndex - 1
                        let timePerFrame = elapsed / Double(frameIndex + 1)
                        let estimatedRemaining = TimeInterval(framesRemaining) * timePerFrame

                        let progress = ExportProgress(
                            currentFrame: frameIndex + 1,
                            totalFrames: totalFrames,
                            estimatedTimeRemaining: estimatedRemaining,
                            phase: .renderingFrames
                        )

                        DispatchQueue.main.async {
                            progressHandler(progress)
                        }
                    }
                }
            }

            DispatchQueue.main.async {
                completion(.success(()))
            }
        }
    }
}

// MARK: - Convenience Extensions

extension FrameCapturer {

    /// Create a capturer for timelapse export
    static func timelapseCapturer(
        document: DrawingDocument,
        canvasSize: CGSize,
        configuration: ExportConfiguration
    ) -> FrameCapturer {
        return FrameCapturer(
            document: document,
            canvasSize: canvasSize,
            configuration: configuration,
            playbackMode: .timelapse(targetDuration: configuration.duration)
        )
    }

    /// Create a capturer for trace mode export
    static func traceCapturer(
        document: DrawingDocument,
        canvasSize: CGSize,
        configuration: ExportConfiguration,
        durationPerStroke: TimeInterval = 1.0
    ) -> FrameCapturer {
        let actualDuration = TimeInterval(document.strokes.count) * durationPerStroke
        let adjustedConfig = ExportConfiguration(
            resolution: configuration.resolution,
            duration: actualDuration,
            frameRate: configuration.frameRate,
            format: configuration.format,
            quality: configuration.quality,
            includeLiveEffects: configuration.includeLiveEffects,
            loopAnimation: configuration.loopAnimation,
            backgroundColor: configuration.backgroundColor
        )

        return FrameCapturer(
            document: document,
            canvasSize: canvasSize,
            configuration: adjustedConfig,
            playbackMode: .trace(durationPerStroke: durationPerStroke)
        )
    }

    /// Create a capturer for realtime export
    static func realtimeCapturer(
        document: DrawingDocument,
        canvasSize: CGSize,
        configuration: ExportConfiguration,
        speedMultiplier: CGFloat = 1.0
    ) -> FrameCapturer {
        return FrameCapturer(
            document: document,
            canvasSize: canvasSize,
            configuration: configuration,
            playbackMode: .realtime(speedMultiplier: speedMultiplier)
        )
    }
}
