//
//  DrawingStorage.swift
//  CreativeDrawing
//
//  Manages saving, loading, and organizing drawings
//

import UIKit

/// Handles all drawing persistence operations
class DrawingStorage {

    // MARK: - Singleton

    static let shared = DrawingStorage()

    /// Serial queue for thread-safe file operations
    private let storageQueue = DispatchQueue(label: "com.creativedrawing.storage", qos: .userInitiated)

    private init() {
        createDirectoriesIfNeeded()
    }

    // MARK: - Directories

    /// Base directory for all drawings
    private var drawingsDirectory: URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0].appendingPathComponent("Drawings", isDirectory: true)
    }

    /// Directory for drawing data files
    private var dataDirectory: URL {
        return drawingsDirectory.appendingPathComponent("Data", isDirectory: true)
    }

    /// Directory for thumbnails
    private var thumbnailsDirectory: URL {
        return drawingsDirectory.appendingPathComponent("Thumbnails", isDirectory: true)
    }

    /// File for metadata index
    private var metadataIndexURL: URL {
        return drawingsDirectory.appendingPathComponent("metadata.json")
    }

    private func createDirectoriesIfNeeded() {
        let fileManager = FileManager.default

        do {
            try fileManager.createDirectory(at: drawingsDirectory, withIntermediateDirectories: true)
            try fileManager.createDirectory(at: dataDirectory, withIntermediateDirectories: true)
            try fileManager.createDirectory(at: thumbnailsDirectory, withIntermediateDirectories: true)
        } catch {
            print("Failed to create directories: \(error)")
        }
    }

    // MARK: - Metadata Management

    /// All saved drawing metadata
    private var _metadataCache: [DrawingMetadata]?

    /// Get all drawing metadata (cached)
    var allMetadata: [DrawingMetadata] {
        if let cached = _metadataCache {
            return cached
        }

        let loaded = loadMetadataIndex()
        _metadataCache = loaded
        return loaded
    }

    /// Load metadata index from disk (thread-safe)
    private func loadMetadataIndex() -> [DrawingMetadata] {
        return storageQueue.sync {
            guard FileManager.default.fileExists(atPath: metadataIndexURL.path) else {
                return []
            }

            do {
                let data = try Data(contentsOf: metadataIndexURL)
                return try JSONDecoder().decode([DrawingMetadata].self, from: data)
            } catch {
                print("Failed to load metadata index: \(error)")
                return []
            }
        }
    }

    /// Save metadata index to disk (thread-safe)
    private func saveMetadataIndex(_ metadata: [DrawingMetadata]) {
        storageQueue.sync {
            do {
                let data = try JSONEncoder().encode(metadata)
                try data.write(to: metadataIndexURL)
                _metadataCache = metadata
            } catch {
                print("Failed to save metadata index: \(error)")
            }
        }
    }

    // MARK: - Save Operations

    /// Save a drawing document with auto-generated metadata
    @discardableResult
    func saveDrawing(
        _ document: DrawingDocument,
        canvasSize: CGSize,
        existingId: UUID? = nil,
        name: String? = nil
    ) -> DrawingMetadata? {

        let id = existingId ?? UUID()
        let isUpdate = existingId != nil

        // Create or update metadata
        var metadata: DrawingMetadata
        if isUpdate, let existing = allMetadata.first(where: { $0.id == id }) {
            metadata = existing
            metadata.modifiedAt = Date()
            if let newName = name {
                metadata.name = newName
            }
        } else {
            metadata = DrawingMetadata(
                id: id,
                name: name,
                strokeCount: document.strokes.count,
                stampCount: document.stamps.count,
                backgroundColorHex: document.backgroundColor.hexString
            )
        }

        // Update counts
        metadata.strokeCount = document.strokes.count
        metadata.stampCount = document.stamps.count

        // Generate thumbnail
        if let image = document.exportAsImage(size: canvasSize) {
            metadata.setThumbnail(from: image)
        }

        // Save drawing data (thread-safe)
        let dataURL = dataDirectory.appendingPathComponent(metadata.fileName)
        let saveSuccess = storageQueue.sync { () -> Bool in
            do {
                try document.save(to: dataURL)
                return true
            } catch {
                print("Failed to save drawing data: \(error)")
                return false
            }
        }
        guard saveSuccess else { return nil }

        // Update metadata index
        var allMeta = allMetadata
        if let index = allMeta.firstIndex(where: { $0.id == id }) {
            allMeta[index] = metadata
        } else {
            allMeta.insert(metadata, at: 0) // New drawings at top
        }
        saveMetadataIndex(allMeta)

        // Post notification
        NotificationCenter.default.post(name: .drawingsSaved, object: metadata)

        return metadata
    }

    // MARK: - Load Operations

    /// Load a drawing document by ID (thread-safe)
    func loadDrawing(id: UUID) -> DrawingDocument? {
        guard let metadata = allMetadata.first(where: { $0.id == id }) else {
            return nil
        }

        let dataURL = dataDirectory.appendingPathComponent(metadata.fileName)

        return storageQueue.sync {
            let document = DrawingDocument()
            do {
                try document.load(from: dataURL)
                return document
            } catch {
                print("Failed to load drawing: \(error)")
                return nil
            }
        }
    }

    /// Get metadata for a specific drawing
    func getMetadata(id: UUID) -> DrawingMetadata? {
        return allMetadata.first(where: { $0.id == id })
    }

    // MARK: - Delete Operations

    /// Delete a drawing by ID (thread-safe)
    func deleteDrawing(id: UUID) -> Bool {
        guard let metadata = allMetadata.first(where: { $0.id == id }) else {
            return false
        }

        // Delete files (thread-safe)
        let dataURL = dataDirectory.appendingPathComponent(metadata.fileName)
        let thumbURL = thumbnailsDirectory.appendingPathComponent(metadata.thumbnailFileName)

        storageQueue.sync {
            do {
                if FileManager.default.fileExists(atPath: dataURL.path) {
                    try FileManager.default.removeItem(at: dataURL)
                }
                if FileManager.default.fileExists(atPath: thumbURL.path) {
                    try FileManager.default.removeItem(at: thumbURL)
                }
            } catch {
                print("Failed to delete files: \(error)")
            }
        }

        // Update metadata index
        var allMeta = allMetadata
        allMeta.removeAll(where: { $0.id == id })
        saveMetadataIndex(allMeta)

        // Post notification
        NotificationCenter.default.post(name: .drawingDeleted, object: id)

        return true
    }

    /// Delete all drawings
    func deleteAllDrawings() {
        for metadata in allMetadata {
            _ = deleteDrawing(id: metadata.id)
        }
    }

    // MARK: - Rename

    /// Rename a drawing
    func renameDrawing(id: UUID, newName: String) -> Bool {
        var allMeta = allMetadata
        guard let index = allMeta.firstIndex(where: { $0.id == id }) else {
            return false
        }

        allMeta[index].name = newName
        allMeta[index].modifiedAt = Date()
        saveMetadataIndex(allMeta)

        return true
    }

    // MARK: - Queries

    /// Get drawings sorted by date (newest first)
    func getRecentDrawings(limit: Int? = nil) -> [DrawingMetadata] {
        let sorted = allMetadata.sorted { $0.modifiedAt > $1.modifiedAt }
        if let limit = limit {
            return Array(sorted.prefix(limit))
        }
        return sorted
    }

    /// Get total count of saved drawings
    var drawingCount: Int {
        return allMetadata.count
    }

    /// Check if any drawings exist
    var hasDrawings: Bool {
        return !allMetadata.isEmpty
    }

    // MARK: - Auto-save Support

    private var autoSaveId: UUID?

    /// Set the current drawing ID for auto-save
    func setAutoSaveDrawing(id: UUID?) {
        autoSaveId = id
    }

    /// Get the current auto-save drawing ID
    var currentAutoSaveId: UUID? {
        return autoSaveId
    }

    /// Start a new drawing session (returns new ID)
    func startNewDrawing() -> UUID {
        let id = UUID()
        autoSaveId = id
        return id
    }

    // MARK: - Export

    /// Export drawing as PNG to Photos
    func exportToPhotos(document: DrawingDocument, canvasSize: CGSize, completion: @escaping (Bool, Error?) -> Void) {
        guard let image = document.exportAsImage(size: canvasSize) else {
            completion(false, NSError(domain: "DrawingStorage", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create image"]))
            return
        }

        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        completion(true, nil)
    }

    /// Get PNG data for sharing
    func getPNGData(document: DrawingDocument, canvasSize: CGSize) -> Data? {
        guard let image = document.exportAsImage(size: canvasSize) else {
            return nil
        }
        return image.pngData()
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let drawingsSaved = Notification.Name("DrawingsSaved")
    static let drawingDeleted = Notification.Name("DrawingDeleted")
    static let drawingsLoaded = Notification.Name("DrawingsLoaded")
}
