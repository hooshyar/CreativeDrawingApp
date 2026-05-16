//
//  GIFExporter.swift
//  CreativeDrawing
//
//  Exports animations as GIF using ImageIO
//

import UIKit
import ImageIO
import MobileCoreServices
import UniformTypeIdentifiers

/// Exports drawing animations as animated GIF
class GIFExporter {

    // MARK: - Properties

    /// Frame capturer for rendering frames
    private var frameCapturer: FrameCapturer?

    /// Export configuration
    private var configuration: ExportConfiguration?

    /// Current export progress handler
    private var progressHandler: ((ExportProgress) -> Void)?

    /// Flag to indicate if export is cancelled
    private var isCancelled = false

    // MARK: - Public Methods

    /// Export drawing animation as GIF
    /// - Parameters:
    ///   - document: Drawing document to export
    ///   - canvasSize: Size of the canvas
    ///   - configuration: Export configuration
    ///   - playbackMode: Playback mode for animation
    ///   - progressHandler: Called with progress updates
    ///   - completion: Called when export completes or fails
    func export(
        document: DrawingDocument,
        canvasSize: CGSize,
        configuration: ExportConfiguration,
        playbackMode: PlaybackMode,
        progressHandler: ((ExportProgress) -> Void)? = nil,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        self.configuration = configuration
        self.progressHandler = progressHandler
        self.isCancelled = false

        // Validate configuration
        guard configuration.format == .gif else {
            completion(.failure(ExportError.invalidConfiguration))
            return
        }

        // Create frame capturer
        frameCapturer = FrameCapturer(
            document: document,
            canvasSize: canvasSize,
            configuration: configuration,
            playbackMode: playbackMode
        )

        // Create output URL
        let outputURL = createOutputURL()

        // Remove existing file if needed
        try? FileManager.default.removeItem(at: outputURL)

        // Report preparing phase
        progressHandler?(ExportProgress(
            currentFrame: 0,
            totalFrames: configuration.totalFrames,
            estimatedTimeRemaining: nil,
            phase: .preparing
        ))

        // Export on background queue
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async {
                    completion(.failure(ExportError.cancelled))
                }
                return
            }

            let result = self.createGIF(at: outputURL, configuration: configuration)

            DispatchQueue.main.async {
                switch result {
                case .success:
                    // Report completed
                    if let progressHandler = self.progressHandler {
                        let progress = ExportProgress(
                            currentFrame: configuration.totalFrames,
                            totalFrames: configuration.totalFrames,
                            estimatedTimeRemaining: 0,
                            phase: .completed
                        )
                        progressHandler(progress)
                    }
                    completion(.success(outputURL))

                case .failure(let error):
                    completion(.failure(error))
                }

                self.cleanup()
            }
        }
    }

    /// Cancel ongoing export
    func cancel() {
        isCancelled = true
        cleanup()
    }

    // MARK: - Private Methods

    /// Create output URL for GIF file
    private func createOutputURL() -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let filename = "drawing_animation_\(Int(Date().timeIntervalSince1970)).gif"
        return tempDir.appendingPathComponent(filename)
    }

    /// Create GIF file at URL
    private func createGIF(at url: URL, configuration: ExportConfiguration) -> Result<Void, Error> {
        guard let frameCapturer = frameCapturer else {
            return .failure(ExportError.invalidConfiguration)
        }

        // Get GIF type identifier
        let gifType: CFString
        if #available(iOS 14.0, *) {
            gifType = UTType.gif.identifier as CFString
        } else {
            gifType = kUTTypeGIF
        }

        // Create destination
        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL,
            gifType,
            configuration.totalFrames,
            nil
        ) else {
            return .failure(ExportError.gifCreationFailed)
        }

        // GIF file properties
        let gifProperties: [CFString: Any] = [
            kCGImagePropertyGIFDictionary: [
                kCGImagePropertyGIFLoopCount: configuration.loopAnimation ? 0 : 1
            ]
        ]
        CGImageDestinationSetProperties(destination, gifProperties as CFDictionary)

        // Frame delay in seconds
        let frameDelay = 1.0 / Double(configuration.frameRate)

        // Frame properties
        let frameProperties: [CFString: Any] = [
            kCGImagePropertyGIFDictionary: [
                kCGImagePropertyGIFDelayTime: frameDelay,
                kCGImagePropertyGIFUnclampedDelayTime: frameDelay
            ]
        ]

        let totalFrames = configuration.totalFrames
        let startTime = CFAbsoluteTimeGetCurrent()

        // Render and add frames
        for frameIndex in 0..<totalFrames {
            if isCancelled {
                return .failure(ExportError.cancelled)
            }

            autoreleasepool {
                // Render frame
                guard let image = frameCapturer.renderFrame(atIndex: frameIndex),
                      let cgImage = frameCapturer.cgImage(from: image) else {
                    return
                }

                // Apply color reduction for smaller file size
                let processedImage: CGImage
                if configuration.quality != .high {
                    processedImage = reduceColors(cgImage, to: configuration.quality.gifColorCount) ?? cgImage
                } else {
                    processedImage = cgImage
                }

                // Add frame to GIF
                CGImageDestinationAddImage(destination, processedImage, frameProperties as CFDictionary)

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

        // Report encoding phase
        if let progressHandler = progressHandler {
            let progress = ExportProgress(
                currentFrame: totalFrames,
                totalFrames: totalFrames,
                estimatedTimeRemaining: nil,
                phase: .encoding
            )
            DispatchQueue.main.async {
                progressHandler(progress)
            }
        }

        // Finalize GIF
        guard CGImageDestinationFinalize(destination) else {
            return .failure(ExportError.fileWriteFailed)
        }

        return .success(())
    }

    /// Reduce color count in image for smaller GIF file size
    private func reduceColors(_ image: CGImage, to colorCount: Int) -> CGImage? {
        let width = image.width
        let height = image.height

        // Create indexed color space (not directly possible, so we use quantization)
        // For simplicity, we'll just return the original image
        // In a production app, you'd use a proper color quantization algorithm

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        return context.makeImage()
    }

    /// Clean up resources
    private func cleanup() {
        frameCapturer = nil
    }
}

// MARK: - Convenience Export Methods

extension GIFExporter {

    /// Export timelapse GIF
    static func exportTimelapse(
        document: DrawingDocument,
        canvasSize: CGSize,
        duration: TimeInterval = 5.0,
        preset: ExportConfiguration? = nil,
        progressHandler: ((ExportProgress) -> Void)? = nil,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        let config = preset ?? ExportConfiguration.standardGIF(duration: duration)
        let exporter = GIFExporter()

        exporter.export(
            document: document,
            canvasSize: canvasSize,
            configuration: config,
            playbackMode: .timelapse(targetDuration: duration),
            progressHandler: progressHandler,
            completion: completion
        )
    }

    /// Export for iMessage
    static func exportForIMessage(
        document: DrawingDocument,
        canvasSize: CGSize,
        duration: TimeInterval = 5.0,
        progressHandler: ((ExportProgress) -> Void)? = nil,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        let config = ExportConfiguration.iMessage(duration: duration)
        let exporter = GIFExporter()

        exporter.export(
            document: document,
            canvasSize: canvasSize,
            configuration: config,
            playbackMode: .timelapse(targetDuration: duration),
            progressHandler: progressHandler,
            completion: completion
        )
    }

    /// Export trace mode GIF (progressive stroke reveal)
    static func exportTrace(
        document: DrawingDocument,
        canvasSize: CGSize,
        durationPerStroke: TimeInterval = 0.5,
        preset: ExportConfiguration? = nil,
        progressHandler: ((ExportProgress) -> Void)? = nil,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        let totalDuration = TimeInterval(document.strokes.count) * durationPerStroke
        let config = preset ?? ExportConfiguration.standardGIF(duration: totalDuration)
        let exporter = GIFExporter()

        exporter.export(
            document: document,
            canvasSize: canvasSize,
            configuration: config,
            playbackMode: .trace(durationPerStroke: durationPerStroke),
            progressHandler: progressHandler,
            completion: completion
        )
    }
}

// MARK: - GIF Data Export

extension GIFExporter {

    /// Export GIF as Data (useful for sharing without file)
    static func exportToData(
        document: DrawingDocument,
        canvasSize: CGSize,
        configuration: ExportConfiguration,
        playbackMode: PlaybackMode,
        progressHandler: ((ExportProgress) -> Void)? = nil,
        completion: @escaping (Result<Data, Error>) -> Void
    ) {
        let exporter = GIFExporter()

        exporter.export(
            document: document,
            canvasSize: canvasSize,
            configuration: configuration,
            playbackMode: playbackMode,
            progressHandler: progressHandler
        ) { result in
            switch result {
            case .success(let url):
                do {
                    let data = try Data(contentsOf: url)
                    // Clean up temp file
                    try? FileManager.default.removeItem(at: url)
                    completion(.success(data))
                } catch {
                    completion(.failure(error))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
}
