//
//  VideoExporter.swift
//  CreativeDrawing
//
//  Exports animations as H.264 MP4 video using AVAssetWriter
//

import UIKit
import AVFoundation

/// Exports drawing animations as MP4 video
class VideoExporter {

    // MARK: - Properties

    /// Frame capturer for rendering frames
    private var frameCapturer: FrameCapturer?

    /// Export configuration
    private var configuration: ExportConfiguration?

    /// Asset writer for video output
    private var assetWriter: AVAssetWriter?

    /// Video input for asset writer
    private var videoInput: AVAssetWriterInput?

    /// Pixel buffer adaptor for efficient frame writing
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?

    /// Current export progress handler
    private var progressHandler: ((ExportProgress) -> Void)?

    /// Flag to indicate if export is cancelled
    private var isCancelled = false

    /// Output URL for the video
    private var outputURL: URL?

    // MARK: - Public Methods

    /// Export drawing animation as MP4 video
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
        guard configuration.format == .mp4 else {
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
        self.outputURL = outputURL

        // Remove existing file if needed
        try? FileManager.default.removeItem(at: outputURL)

        // Report preparing phase
        progressHandler?(ExportProgress(
            currentFrame: 0,
            totalFrames: configuration.totalFrames,
            estimatedTimeRemaining: nil,
            phase: .preparing
        ))

        // Setup asset writer
        do {
            try setupAssetWriter(outputURL: outputURL, configuration: configuration)
        } catch {
            completion(.failure(error))
            return
        }

        // Start writing
        guard assetWriter?.startWriting() == true else {
            let error = assetWriter?.error ?? ExportError.failedToCreateWriter
            completion(.failure(error))
            return
        }

        assetWriter?.startSession(atSourceTime: .zero)

        // Write frames
        writeFrames(completion: completion)
    }

    /// Cancel ongoing export
    func cancel() {
        isCancelled = true
        assetWriter?.cancelWriting()
        cleanup()
    }

    // MARK: - Private Methods

    /// Create output URL for video file
    private func createOutputURL() -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let filename = "drawing_animation_\(Int(Date().timeIntervalSince1970)).mp4"
        return tempDir.appendingPathComponent(filename)
    }

    /// Setup AVAssetWriter and inputs
    private func setupAssetWriter(outputURL: URL, configuration: ExportConfiguration) throws {
        // Create asset writer
        let writer: AVAssetWriter
        do {
            writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
        } catch {
            throw ExportError.failedToCreateWriter
        }

        let size = configuration.alignedResolution

        // Video settings for H.264
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: Int(size.width),
            AVVideoHeightKey: Int(size.height),
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: configuration.quality.videoBitrate,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
                AVVideoMaxKeyFrameIntervalKey: configuration.frameRate * 2
            ]
        ]

        // Create video input
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        input.expectsMediaDataInRealTime = false

        guard writer.canAdd(input) else {
            throw ExportError.failedToCreateInput
        }

        writer.add(input)

        // Create pixel buffer adaptor
        let sourcePixelBufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
            kCVPixelBufferWidthKey as String: Int(size.width),
            kCVPixelBufferHeightKey as String: Int(size.height)
        ]

        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: sourcePixelBufferAttributes
        )

        self.assetWriter = writer
        self.videoInput = input
        self.pixelBufferAdaptor = adaptor
    }

    /// Write frames to video
    private func writeFrames(completion: @escaping (Result<URL, Error>) -> Void) {
        guard let configuration = configuration,
              let frameCapturer = frameCapturer,
              let videoInput = videoInput,
              let adaptor = pixelBufferAdaptor,
              let outputURL = outputURL else {
            completion(.failure(ExportError.invalidConfiguration))
            return
        }

        let totalFrames = configuration.totalFrames
        let frameTime = configuration.frameTime
        let size = configuration.alignedResolution
        var frameIndex = 0
        let startTime = CFAbsoluteTimeGetCurrent()

        // Use video input's media data request queue
        videoInput.requestMediaDataWhenReady(on: DispatchQueue.global(qos: .userInitiated)) { [weak self] in
            guard let self = self else { return }

            while videoInput.isReadyForMoreMediaData && frameIndex < totalFrames && !self.isCancelled {
                autoreleasepool {
                    // Calculate presentation time
                    let presentationTime = CMTimeMultiply(frameTime, multiplier: Int32(frameIndex))

                    // Render frame
                    guard let image = frameCapturer.renderFrame(atIndex: frameIndex) else {
                        DispatchQueue.main.async {
                            completion(.failure(ExportError.failedToRenderFrame(frameIndex)))
                        }
                        videoInput.markAsFinished()
                        return
                    }

                    // Create pixel buffer
                    guard let pixelBuffer = frameCapturer.createPixelBuffer(from: image, size: size) else {
                        DispatchQueue.main.async {
                            completion(.failure(ExportError.failedToCreatePixelBuffer))
                        }
                        videoInput.markAsFinished()
                        return
                    }

                    // Append pixel buffer
                    if !adaptor.append(pixelBuffer, withPresentationTime: presentationTime) {
                        let error = self.assetWriter?.error ?? ExportError.writingFailed(NSError())
                        DispatchQueue.main.async {
                            completion(.failure(error))
                        }
                        videoInput.markAsFinished()
                        return
                    }

                    frameIndex += 1

                    // Update progress
                    if let progressHandler = self.progressHandler {
                        let elapsed = CFAbsoluteTimeGetCurrent() - startTime
                        let framesRemaining = totalFrames - frameIndex
                        let timePerFrame = elapsed / Double(frameIndex)
                        let estimatedRemaining = TimeInterval(framesRemaining) * timePerFrame

                        let progress = ExportProgress(
                            currentFrame: frameIndex,
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

            // Check if cancelled
            if self.isCancelled {
                videoInput.markAsFinished()
                self.assetWriter?.cancelWriting()
                DispatchQueue.main.async {
                    completion(.failure(ExportError.cancelled))
                }
                return
            }

            // Finalize if all frames written
            if frameIndex >= totalFrames {
                videoInput.markAsFinished()
                self.finalizeVideo(outputURL: outputURL, completion: completion)
            }
        }
    }

    /// Finalize video writing
    private func finalizeVideo(outputURL: URL, completion: @escaping (Result<URL, Error>) -> Void) {
        // Report finalizing phase
        if let config = configuration, let progressHandler = progressHandler {
            let progress = ExportProgress(
                currentFrame: config.totalFrames,
                totalFrames: config.totalFrames,
                estimatedTimeRemaining: 0,
                phase: .finalizing
            )
            DispatchQueue.main.async {
                progressHandler(progress)
            }
        }

        assetWriter?.finishWriting { [weak self] in
            guard let self = self else { return }

            DispatchQueue.main.async {
                if let error = self.assetWriter?.error {
                    completion(.failure(ExportError.writingFailed(error)))
                } else {
                    // Report completed
                    if let config = self.configuration, let progressHandler = self.progressHandler {
                        let progress = ExportProgress(
                            currentFrame: config.totalFrames,
                            totalFrames: config.totalFrames,
                            estimatedTimeRemaining: 0,
                            phase: .completed
                        )
                        progressHandler(progress)
                    }

                    completion(.success(outputURL))
                }

                self.cleanup()
            }
        }
    }

    /// Clean up resources
    private func cleanup() {
        videoInput = nil
        pixelBufferAdaptor = nil
        assetWriter = nil
        frameCapturer = nil
    }
}

// MARK: - Convenience Export Methods

extension VideoExporter {

    /// Export timelapse video
    static func exportTimelapse(
        document: DrawingDocument,
        canvasSize: CGSize,
        duration: TimeInterval = 10.0,
        preset: ExportConfiguration? = nil,
        progressHandler: ((ExportProgress) -> Void)? = nil,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        let config = preset ?? ExportConfiguration.matchCanvas(canvasSize, duration: duration, format: .mp4)
        let exporter = VideoExporter()

        exporter.export(
            document: document,
            canvasSize: canvasSize,
            configuration: config,
            playbackMode: .timelapse(targetDuration: duration),
            progressHandler: progressHandler,
            completion: completion
        )
    }

    /// Export for Instagram Stories
    static func exportForInstagramStories(
        document: DrawingDocument,
        canvasSize: CGSize,
        duration: TimeInterval = 15.0,
        progressHandler: ((ExportProgress) -> Void)? = nil,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        let config = ExportConfiguration.instagramStories(duration: duration)
        let exporter = VideoExporter()

        exporter.export(
            document: document,
            canvasSize: canvasSize,
            configuration: config,
            playbackMode: .timelapse(targetDuration: duration),
            progressHandler: progressHandler,
            completion: completion
        )
    }

    /// Export for TikTok
    static func exportForTikTok(
        document: DrawingDocument,
        canvasSize: CGSize,
        duration: TimeInterval = 30.0,
        progressHandler: ((ExportProgress) -> Void)? = nil,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        let config = ExportConfiguration.tiktok(duration: duration)
        let exporter = VideoExporter()

        exporter.export(
            document: document,
            canvasSize: canvasSize,
            configuration: config,
            playbackMode: .timelapse(targetDuration: duration),
            progressHandler: progressHandler,
            completion: completion
        )
    }
}
