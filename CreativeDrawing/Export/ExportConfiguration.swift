//
//  ExportConfiguration.swift
//  CreativeDrawing
//
//  Configuration and presets for video/GIF export
//

import UIKit
import AVFoundation

// MARK: - Export Format

/// Supported export formats
enum ExportFormat {
    case mp4
    case gif

    var fileExtension: String {
        switch self {
        case .mp4: return "mp4"
        case .gif: return "gif"
        }
    }

    var mimeType: String {
        switch self {
        case .mp4: return "video/mp4"
        case .gif: return "image/gif"
        }
    }
}

// MARK: - Export Quality

/// Quality levels for export
enum ExportQuality {
    case low
    case medium
    case high

    /// Video bitrate in bits per second
    var videoBitrate: Int {
        switch self {
        case .low: return 2_000_000      // 2 Mbps
        case .medium: return 5_000_000   // 5 Mbps
        case .high: return 10_000_000    // 10 Mbps
        }
    }

    /// GIF color count (power of 2, max 256)
    var gifColorCount: Int {
        switch self {
        case .low: return 64
        case .medium: return 128
        case .high: return 256
        }
    }
}

// MARK: - Export Configuration

/// Configuration for video/GIF export
struct ExportConfiguration {

    /// Output resolution
    let resolution: CGSize

    /// Duration in seconds
    let duration: TimeInterval

    /// Frames per second
    let frameRate: Int

    /// Export format (MP4 or GIF)
    let format: ExportFormat

    /// Quality level
    let quality: ExportQuality

    /// Whether to include live effects (sparkle twinkling, rainbow shimmer)
    let includeLiveEffects: Bool

    /// Whether to loop the animation (for GIF)
    let loopAnimation: Bool

    /// Background color override (nil uses document color)
    let backgroundColor: UIColor?

    // MARK: - Computed Properties

    /// Total number of frames
    var totalFrames: Int {
        return Int(ceil(duration * Double(frameRate)))
    }

    /// Duration of each frame
    var frameDuration: TimeInterval {
        return 1.0 / Double(frameRate)
    }

    /// Video dimensions aligned to 16 pixels (required for H.264)
    var alignedResolution: CGSize {
        let width = (Int(resolution.width) / 16) * 16
        let height = (Int(resolution.height) / 16) * 16
        return CGSize(width: max(width, 16), height: max(height, 16))
    }

    /// CMTime for frame duration
    var frameTime: CMTime {
        // Use 600 timescale for better precision
        return CMTime(value: CMTimeValue(600 / frameRate), timescale: 600)
    }

    // MARK: - Initialization

    init(
        resolution: CGSize,
        duration: TimeInterval,
        frameRate: Int = 30,
        format: ExportFormat = .mp4,
        quality: ExportQuality = .medium,
        includeLiveEffects: Bool = true,
        loopAnimation: Bool = true,
        backgroundColor: UIColor? = nil
    ) {
        self.resolution = resolution
        self.duration = duration
        self.frameRate = frameRate
        self.format = format
        self.quality = quality
        self.includeLiveEffects = includeLiveEffects
        self.loopAnimation = loopAnimation
        self.backgroundColor = backgroundColor
    }
}

// MARK: - Social Media Presets

extension ExportConfiguration {

    /// Instagram Stories preset (1080x1920, 15s, 30fps, MP4)
    static func instagramStories(duration: TimeInterval = 15.0) -> ExportConfiguration {
        return ExportConfiguration(
            resolution: CGSize(width: 1080, height: 1920),
            duration: min(duration, 15.0), // Instagram Stories max 15s
            frameRate: 30,
            format: .mp4,
            quality: .high,
            includeLiveEffects: true,
            loopAnimation: false
        )
    }

    /// TikTok preset (1080x1920, 30s, 30fps, MP4)
    static func tiktok(duration: TimeInterval = 30.0) -> ExportConfiguration {
        return ExportConfiguration(
            resolution: CGSize(width: 1080, height: 1920),
            duration: min(duration, 60.0), // TikTok allows up to 60s
            frameRate: 30,
            format: .mp4,
            quality: .high,
            includeLiveEffects: true,
            loopAnimation: false
        )
    }

    /// iMessage GIF preset (480x480, 5s, 15fps, GIF)
    static func iMessage(duration: TimeInterval = 5.0) -> ExportConfiguration {
        return ExportConfiguration(
            resolution: CGSize(width: 480, height: 480),
            duration: min(duration, 10.0),
            frameRate: 15, // Lower framerate for smaller file size
            format: .gif,
            quality: .medium,
            includeLiveEffects: true,
            loopAnimation: true
        )
    }

    /// Square video for Instagram Feed (1080x1080, MP4)
    static func instagramFeed(duration: TimeInterval = 10.0) -> ExportConfiguration {
        return ExportConfiguration(
            resolution: CGSize(width: 1080, height: 1080),
            duration: min(duration, 60.0),
            frameRate: 30,
            format: .mp4,
            quality: .high,
            includeLiveEffects: true,
            loopAnimation: false
        )
    }

    /// Standard GIF (640x640, 10s, 20fps)
    static func standardGIF(duration: TimeInterval = 10.0) -> ExportConfiguration {
        return ExportConfiguration(
            resolution: CGSize(width: 640, height: 640),
            duration: duration,
            frameRate: 20,
            format: .gif,
            quality: .high,
            includeLiveEffects: true,
            loopAnimation: true
        )
    }

    /// Custom configuration builder
    static func custom(
        width: CGFloat,
        height: CGFloat,
        duration: TimeInterval,
        frameRate: Int = 30,
        format: ExportFormat = .mp4,
        quality: ExportQuality = .medium
    ) -> ExportConfiguration {
        return ExportConfiguration(
            resolution: CGSize(width: width, height: height),
            duration: duration,
            frameRate: frameRate,
            format: format,
            quality: quality,
            includeLiveEffects: true,
            loopAnimation: format == .gif
        )
    }

    /// Match canvas size (useful for preserving aspect ratio)
    static func matchCanvas(
        _ canvasSize: CGSize,
        duration: TimeInterval,
        format: ExportFormat = .mp4,
        maxDimension: CGFloat = 1080
    ) -> ExportConfiguration {
        let aspectRatio = canvasSize.width / canvasSize.height
        let scaledSize: CGSize

        if aspectRatio > 1 {
            // Landscape
            scaledSize = CGSize(
                width: min(canvasSize.width, maxDimension),
                height: min(canvasSize.width, maxDimension) / aspectRatio
            )
        } else {
            // Portrait or square
            scaledSize = CGSize(
                width: min(canvasSize.height, maxDimension) * aspectRatio,
                height: min(canvasSize.height, maxDimension)
            )
        }

        return ExportConfiguration(
            resolution: scaledSize,
            duration: duration,
            frameRate: format == .gif ? 20 : 30,
            format: format,
            quality: .high,
            includeLiveEffects: true,
            loopAnimation: format == .gif
        )
    }
}

// MARK: - Export Progress

/// Progress information during export
struct ExportProgress {
    /// Current frame being processed
    let currentFrame: Int

    /// Total frames to process
    let totalFrames: Int

    /// Progress as a percentage (0.0 to 1.0)
    var progress: Float {
        guard totalFrames > 0 else { return 0 }
        return Float(currentFrame) / Float(totalFrames)
    }

    /// Estimated time remaining in seconds
    let estimatedTimeRemaining: TimeInterval?

    /// Current export phase
    let phase: ExportPhase
}

/// Phases of the export process
enum ExportPhase {
    case preparing
    case renderingFrames
    case encoding
    case finalizing
    case completed
    case failed(Error)

    var description: String {
        switch self {
        case .preparing: return "Preparing..."
        case .renderingFrames: return "Rendering frames..."
        case .encoding: return "Encoding..."
        case .finalizing: return "Finalizing..."
        case .completed: return "Completed"
        case .failed: return "Failed"
        }
    }
}

// MARK: - Export Error

/// Errors that can occur during export
enum ExportError: LocalizedError {
    case invalidConfiguration
    case noDocument
    case failedToCreateWriter
    case failedToCreateInput
    case failedToRenderFrame(Int)
    case failedToCreatePixelBuffer
    case writingFailed(Error)
    case cancelled
    case gifCreationFailed
    case fileWriteFailed

    var errorDescription: String? {
        switch self {
        case .invalidConfiguration:
            return "Invalid export configuration"
        case .noDocument:
            return "No document to export"
        case .failedToCreateWriter:
            return "Failed to create video writer"
        case .failedToCreateInput:
            return "Failed to create video input"
        case .failedToRenderFrame(let index):
            return "Failed to render frame \(index)"
        case .failedToCreatePixelBuffer:
            return "Failed to create pixel buffer"
        case .writingFailed(let error):
            return "Writing failed: \(error.localizedDescription)"
        case .cancelled:
            return "Export was cancelled"
        case .gifCreationFailed:
            return "Failed to create GIF"
        case .fileWriteFailed:
            return "Failed to write file"
        }
    }
}
