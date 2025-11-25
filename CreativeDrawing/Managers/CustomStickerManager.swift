//
//  CustomStickerManager.swift
//  CreativeDrawing
//
//  Manages custom sticker creation using on-device Vision AI
//

import UIKit
import Vision
import os.log

private let stickerLog = OSLog(subsystem: "app.datacode.CreativeDrawing", category: "StickerManager")

/// Manages creation and storage of custom stickers from photos
class CustomStickerManager {

    static let shared = CustomStickerManager()

    /// Maximum number of custom stickers to store
    private let maxCustomStickers = 20

    /// Directory for storing custom stickers
    private var stickersDirectory: URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let stickersPath = documentsPath.appendingPathComponent("CustomStickers", isDirectory: true)

        // Create directory if it doesn't exist
        if !FileManager.default.fileExists(atPath: stickersPath.path) {
            try? FileManager.default.createDirectory(at: stickersPath, withIntermediateDirectories: true)
        }

        return stickersPath
    }

    /// Currently loaded custom stickers
    private(set) var customStickers: [CustomSticker] = []

    /// Callback when stickers are updated
    var onStickersUpdated: (() -> Void)?

    private init() {
        loadStickers()
    }

    // MARK: - Sticker Creation

    /// Create a sticker from an image using Vision AI to extract the subject
    /// - Parameters:
    ///   - image: The source image
    ///   - completion: Called with the resulting sticker or error
    func createSticker(from image: UIImage, completion: @escaping (Result<CustomSticker, StickerError>) -> Void) {
        os_log("Creating sticker from image: %dx%d", log: stickerLog, type: .info, Int(image.size.width), Int(image.size.height))

        // Ensure we have a valid CGImage
        guard let cgImage = image.cgImage else {
            os_log("Invalid image - no CGImage available", log: stickerLog, type: .error)
            completion(.failure(.invalidImage))
            return
        }

        // Check iOS version for Vision capabilities
        if #available(iOS 17.0, *) {
            os_log("Using iOS 17+ VNGenerateForegroundInstanceMaskRequest", log: stickerLog, type: .info)
            extractSubjectWithVision(cgImage: cgImage, originalImage: image, completion: completion)
        } else {
            os_log("Using fallback saliency detection", log: stickerLog, type: .info)
            // Fallback: Use basic saliency detection for older iOS
            extractSubjectWithSaliency(cgImage: cgImage, originalImage: image, completion: completion)
        }
    }

    /// Extract subject using iOS 17+ foreground instance mask
    @available(iOS 17.0, *)
    private func extractSubjectWithVision(cgImage: CGImage, originalImage: UIImage, completion: @escaping (Result<CustomSticker, StickerError>) -> Void) {

        let request = VNGenerateForegroundInstanceMaskRequest()

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])

                guard let result = request.results?.first else {
                    os_log("No Vision results - using original image", log: stickerLog, type: .info)
                    // Fall back to using the whole image as a sticker
                    DispatchQueue.main.async {
                        let sticker = self.saveSticker(image: originalImage)
                        completion(.success(sticker))
                    }
                    return
                }

                // Check if there are any instances detected
                guard result.allInstances.count > 0 else {
                    os_log("No foreground instances found - using original image", log: stickerLog, type: .info)
                    // Fall back to using the whole image as a sticker
                    DispatchQueue.main.async {
                        let sticker = self.saveSticker(image: originalImage)
                        completion(.success(sticker))
                    }
                    return
                }

                // Generate the mask image
                let maskPixelBuffer = try result.generateScaledMaskForImage(forInstances: result.allInstances, from: handler)

                // Convert mask to UIImage
                let ciImage = CIImage(cvPixelBuffer: maskPixelBuffer)
                let context = CIContext()

                guard let maskCGImage = context.createCGImage(ciImage, from: ciImage.extent) else {
                    os_log("Failed to create mask CGImage - using original image", log: stickerLog, type: .error)
                    // Fall back to using the whole image as a sticker
                    DispatchQueue.main.async {
                        let sticker = self.saveSticker(image: originalImage)
                        completion(.success(sticker))
                    }
                    return
                }

                // Apply mask to original image
                guard let maskedImage = self.applyMask(maskCGImage, to: cgImage) else {
                    os_log("Failed to apply mask - using original image", log: stickerLog, type: .error)
                    // Fall back to using the whole image as a sticker
                    DispatchQueue.main.async {
                        let sticker = self.saveSticker(image: originalImage)
                        completion(.success(sticker))
                    }
                    return
                }

                // Crop to content bounds and create sticker
                let croppedImage = self.cropToContent(maskedImage)
                let sticker = self.saveSticker(image: croppedImage)

                DispatchQueue.main.async {
                    completion(.success(sticker))
                }

            } catch {
                os_log("Vision error: %{public}@ - using original image", log: stickerLog, type: .error, error.localizedDescription)
                // Fall back to using the whole image as a sticker
                DispatchQueue.main.async {
                    let sticker = self.saveSticker(image: originalImage)
                    completion(.success(sticker))
                }
            }
        }
    }

    /// Fallback extraction using saliency detection (iOS 13+)
    private func extractSubjectWithSaliency(cgImage: CGImage, originalImage: UIImage, completion: @escaping (Result<CustomSticker, StickerError>) -> Void) {

        let request = VNGenerateAttentionBasedSaliencyImageRequest()

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])

                guard let result = request.results?.first else {
                    os_log("No saliency results - using original image", log: stickerLog, type: .info)
                    DispatchQueue.main.async {
                        let sticker = self.saveSticker(image: originalImage)
                        completion(.success(sticker))
                    }
                    return
                }

                // Convert saliency map to mask
                let saliencyMap = result.pixelBuffer
                let ciImage = CIImage(cvPixelBuffer: saliencyMap)
                let context = CIContext()

                // Scale up saliency map to match original image size
                let scaleX = CGFloat(cgImage.width) / ciImage.extent.width
                let scaleY = CGFloat(cgImage.height) / ciImage.extent.height
                let scaledCIImage = ciImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))

                // Threshold the saliency map to create a mask
                let thresholdFilter = CIFilter(name: "CIColorThreshold")!
                thresholdFilter.setValue(scaledCIImage, forKey: kCIInputImageKey)
                thresholdFilter.setValue(0.3, forKey: "inputThreshold")

                guard let thresholdedImage = thresholdFilter.outputImage,
                      let maskCGImage = context.createCGImage(thresholdedImage, from: CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height)) else {
                    os_log("Failed to create saliency mask - using original image", log: stickerLog, type: .error)
                    DispatchQueue.main.async {
                        let sticker = self.saveSticker(image: originalImage)
                        completion(.success(sticker))
                    }
                    return
                }

                // Apply mask to original image
                guard let maskedImage = self.applyMask(maskCGImage, to: cgImage) else {
                    os_log("Failed to apply saliency mask - using original image", log: stickerLog, type: .error)
                    DispatchQueue.main.async {
                        let sticker = self.saveSticker(image: originalImage)
                        completion(.success(sticker))
                    }
                    return
                }

                let croppedImage = self.cropToContent(maskedImage)
                let sticker = self.saveSticker(image: croppedImage)

                DispatchQueue.main.async {
                    completion(.success(sticker))
                }

            } catch {
                os_log("Saliency error: %{public}@ - using original image", log: stickerLog, type: .error, error.localizedDescription)
                DispatchQueue.main.async {
                    let sticker = self.saveSticker(image: originalImage)
                    completion(.success(sticker))
                }
            }
        }
    }

    /// Apply a mask to an image
    private func applyMask(_ mask: CGImage, to image: CGImage) -> UIImage? {
        let width = image.width
        let height = image.height

        // Create a context with alpha
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 4 * width,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        // Draw the original image
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        // Get the image data
        guard let imageData = context.data else { return nil }

        // Create mask context to read mask data
        guard let maskContext = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return nil }

        maskContext.draw(mask, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let maskData = maskContext.data else { return nil }

        let imageBuffer = imageData.bindMemory(to: UInt8.self, capacity: width * height * 4)
        let maskBuffer = maskData.bindMemory(to: UInt8.self, capacity: width * height)

        // Apply mask as alpha
        for y in 0..<height {
            for x in 0..<width {
                let pixelIndex = (y * width + x) * 4
                let maskIndex = y * width + x
                let maskValue = maskBuffer[maskIndex]

                // Apply mask value as alpha
                imageBuffer[pixelIndex + 3] = maskValue
            }
        }

        // Create result image
        guard let resultImage = context.makeImage() else { return nil }
        return UIImage(cgImage: resultImage)
    }

    /// Crop image to its non-transparent content
    private func cropToContent(_ image: UIImage) -> UIImage {
        guard let cgImage = image.cgImage else { return image }

        let width = cgImage.width
        let height = cgImage.height

        // Create context to read pixels
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        var pixelData = [UInt8](repeating: 0, count: width * height * 4)

        guard let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 4 * width,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return image }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        // Find bounds of non-transparent pixels
        var minX = width, maxX = 0, minY = height, maxY = 0

        for y in 0..<height {
            for x in 0..<width {
                let index = (y * width + x) * 4 + 3 // Alpha component
                if pixelData[index] > 10 { // Non-transparent
                    minX = min(minX, x)
                    maxX = max(maxX, x)
                    minY = min(minY, y)
                    maxY = max(maxY, y)
                }
            }
        }

        // Add padding
        let padding = 10
        minX = max(0, minX - padding)
        maxX = min(width - 1, maxX + padding)
        minY = max(0, minY - padding)
        maxY = min(height - 1, maxY + padding)

        // Crop
        let cropRect = CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)

        if let croppedCGImage = cgImage.cropping(to: cropRect) {
            return UIImage(cgImage: croppedCGImage)
        }

        return image
    }

    // MARK: - Storage

    /// Save a sticker to persistent storage
    private func saveSticker(image: UIImage) -> CustomSticker {
        let id = UUID()
        let filename = "\(id.uuidString).png"
        let fileURL = stickersDirectory.appendingPathComponent(filename)

        // Save image as PNG
        if let pngData = image.pngData() {
            do {
                try pngData.write(to: fileURL)
                os_log("Sticker saved successfully: %{public}@", log: stickerLog, type: .info, filename)
            } catch {
                os_log("Failed to save sticker: %{public}@", log: stickerLog, type: .error, error.localizedDescription)
            }
        } else {
            os_log("Failed to convert image to PNG data", log: stickerLog, type: .error)
        }

        let sticker = CustomSticker(id: id, imageURL: fileURL, createdAt: Date())

        // Add to collection (limit to max)
        customStickers.insert(sticker, at: 0)
        if customStickers.count > maxCustomStickers {
            let removed = customStickers.removeLast()
            deleteSticker(removed)
        }

        saveMetadata()
        onStickersUpdated?()

        os_log("Sticker creation complete. Total stickers: %d", log: stickerLog, type: .info, customStickers.count)
        return sticker
    }

    /// Delete a sticker
    func deleteSticker(_ sticker: CustomSticker) {
        try? FileManager.default.removeItem(at: sticker.imageURL)
        customStickers.removeAll { $0.id == sticker.id }
        saveMetadata()
        onStickersUpdated?()
    }

    /// Load stickers from storage
    private func loadStickers() {
        let metadataURL = stickersDirectory.appendingPathComponent("metadata.json")

        guard let data = try? Data(contentsOf: metadataURL),
              let metadata = try? JSONDecoder().decode([StickerMetadata].self, from: data) else {
            return
        }

        customStickers = metadata.compactMap { meta in
            let fileURL = stickersDirectory.appendingPathComponent(meta.filename)
            guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
            return CustomSticker(id: meta.id, imageURL: fileURL, createdAt: meta.createdAt)
        }
    }

    /// Save sticker metadata
    private func saveMetadata() {
        let metadata = customStickers.map { sticker in
            StickerMetadata(
                id: sticker.id,
                filename: sticker.imageURL.lastPathComponent,
                createdAt: sticker.createdAt
            )
        }

        let metadataURL = stickersDirectory.appendingPathComponent("metadata.json")

        if let data = try? JSONEncoder().encode(metadata) {
            try? data.write(to: metadataURL)
        }
    }
}

// MARK: - Models

/// A custom sticker created from a photo
struct CustomSticker: Identifiable {
    let id: UUID
    let imageURL: URL
    let createdAt: Date

    /// Load the sticker image
    func loadImage() -> UIImage? {
        guard let data = try? Data(contentsOf: imageURL) else { return nil }
        return UIImage(data: data)
    }
}

/// Metadata for persistence
private struct StickerMetadata: Codable {
    let id: UUID
    let filename: String
    let createdAt: Date
}

/// Errors that can occur during sticker creation
enum StickerError: Error, LocalizedError {
    case invalidImage
    case noSubjectFound
    case processingFailed

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "Couldn't read the image"
        case .noSubjectFound:
            return "Couldn't find anything to cut out"
        case .processingFailed:
            return "Something went wrong"
        }
    }
}
