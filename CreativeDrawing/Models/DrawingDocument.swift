//
//  DrawingDocument.swift
//  CreativeDrawing
//
//  Manages the drawing state, undo/redo, and persistence
//

import UIKit

/// A single action that can be undone/redone
enum DrawingAction {
    case stroke(Stroke)
    case stamp(Stamp)
    case fill(FillRegion)
    case clear(strokes: [Stroke], stamps: [Stamp], fills: [FillRegion])
}

/// Manages all strokes, stamps and provides undo/redo functionality
class DrawingDocument {
    /// All strokes currently on the canvas
    private(set) var strokes: [Stroke] = []

    /// All stamps currently on the canvas
    private(set) var stamps: [Stamp] = []

    /// All filled regions on the canvas
    private(set) var fills: [FillRegion] = []

    /// Action history for undo
    private var actionHistory: [DrawingAction] = []

    /// Actions that were undone (for redo)
    private var undoneActions: [DrawingAction] = []

    /// Maximum number of undo levels
    let maxUndoLevels = 50

    /// Background color of the canvas
    var backgroundColor: UIColor = .white

    /// Callback when document changes
    var onDocumentChanged: (() -> Void)?

    /// Check if undo is available
    var canUndo: Bool {
        return !actionHistory.isEmpty
    }

    /// Check if redo is available
    var canRedo: Bool {
        return !undoneActions.isEmpty
    }

    /// Add a new stroke to the document
    func addStroke(_ stroke: Stroke) {
        strokes.append(stroke)
        actionHistory.append(.stroke(stroke))
        undoneActions.removeAll()

        // Limit undo history
        if actionHistory.count > maxUndoLevels {
            actionHistory.removeFirst()
        }

        onDocumentChanged?()
    }

    /// Add a new stamp to the document
    func addStamp(_ stamp: Stamp) {
        stamps.append(stamp)
        actionHistory.append(.stamp(stamp))
        undoneActions.removeAll()

        // Limit undo history
        if actionHistory.count > maxUndoLevels {
            actionHistory.removeFirst()
        }

        onDocumentChanged?()
    }

    /// Add a new fill region to the document
    func addFill(_ fill: FillRegion) {
        fills.append(fill)
        actionHistory.append(.fill(fill))
        undoneActions.removeAll()

        // Limit undo history
        if actionHistory.count > maxUndoLevels {
            actionHistory.removeFirst()
        }

        onDocumentChanged?()
    }

    /// Undo the last action
    @discardableResult
    func undo() -> DrawingAction? {
        guard let action = actionHistory.popLast() else { return nil }

        switch action {
        case .stroke(let stroke):
            if let index = strokes.firstIndex(where: { $0.id == stroke.id }) {
                strokes.remove(at: index)
            }
        case .stamp(let stamp):
            if let index = stamps.firstIndex(where: { $0.id == stamp.id }) {
                stamps.remove(at: index)
            }
        case .fill(let fill):
            if let index = fills.firstIndex(where: { $0.id == fill.id }) {
                fills.remove(at: index)
            }
        case .clear(let savedStrokes, let savedStamps, let savedFills):
            strokes = savedStrokes
            stamps = savedStamps
            fills = savedFills
        }

        undoneActions.append(action)
        onDocumentChanged?()
        return action
    }

    /// Redo the last undone action
    @discardableResult
    func redo() -> DrawingAction? {
        guard let action = undoneActions.popLast() else { return nil }

        switch action {
        case .stroke(let stroke):
            strokes.append(stroke)
        case .stamp(let stamp):
            stamps.append(stamp)
        case .fill(let fill):
            fills.append(fill)
        case .clear:
            strokes.removeAll()
            stamps.removeAll()
            fills.removeAll()
        }

        actionHistory.append(action)
        onDocumentChanged?()
        return action
    }

    /// Clear all strokes and stamps (can be undone)
    func clear() {
        guard !strokes.isEmpty || !stamps.isEmpty || !fills.isEmpty else { return }

        let savedStrokes = strokes
        let savedStamps = stamps
        let savedFills = fills

        strokes.removeAll()
        stamps.removeAll()
        fills.removeAll()

        actionHistory.append(.clear(strokes: savedStrokes, stamps: savedStamps, fills: savedFills))
        undoneActions.removeAll()

        onDocumentChanged?()
    }

    /// Hard reset - clears everything including undo history
    func reset() {
        strokes.removeAll()
        stamps.removeAll()
        fills.removeAll()
        actionHistory.removeAll()
        undoneActions.removeAll()
        backgroundColor = .white
        onDocumentChanged?()
    }

    /// Load strokes directly without adding to undo history (for persistence)
    func loadStrokes(_ loadedStrokes: [Stroke]) {
        strokes = loadedStrokes
    }

    /// Load stamps directly without adding to undo history (for persistence)
    func loadStamps(_ loadedStamps: [Stamp]) {
        stamps = loadedStamps
    }

    /// Export the drawing as an image
    func exportAsImage(size: CGSize, scale: CGFloat = UIScreen.main.scale) -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { context in
            // Fill background
            backgroundColor.setFill()
            context.fill(CGRect(origin: .zero, size: size))

            // Draw all fill regions (underneath strokes)
            for fill in fills {
                fill.filledImage.draw(at: .zero)
            }

            // Draw all strokes
            for stroke in strokes {
                drawStroke(stroke, in: context.cgContext)
            }

            // Draw all stamps
            for stamp in stamps {
                drawStamp(stamp, in: context.cgContext)
            }
        }
    }

    /// Draw a single stamp into a graphics context - TRANSPARENT STICKER STYLE
    private func drawStamp(_ stamp: Stamp, in context: CGContext) {
        context.saveGState()

        // Handle custom stickers
        if stamp.isCustomSticker, let customImage = stamp.customImage {
            drawCustomStamp(stamp, image: customImage, in: context)
            context.restoreGState()
            return
        }

        // TRANSPARENT STICKER - Just the icon with subtle effects (matches DrawingCanvas)
        let baseSize: CGFloat = 80
        let stampSize: CGFloat = baseSize * stamp.scale
        let color = stamp.color ?? stamp.type.defaultColor

        // Apply rotation around center
        context.translateBy(x: stamp.position.x, y: stamp.position.y)
        context.rotate(by: stamp.rotation)
        context.translateBy(x: -stamp.position.x, y: -stamp.position.y)

        // Get the SF Symbol with proper configuration
        let config = UIImage.SymbolConfiguration(pointSize: stampSize, weight: .regular)
            .applying(UIImage.SymbolConfiguration(paletteColors: [color]))

        if let image = UIImage(systemName: stamp.type.rawValue, withConfiguration: config) {
            // Calculate proper rect maintaining aspect ratio
            let imageSize = image.size
            let aspectRatio = imageSize.width / imageSize.height

            var drawWidth: CGFloat
            var drawHeight: CGFloat

            if aspectRatio > 1 {
                // Wider than tall
                drawWidth = stampSize
                drawHeight = stampSize / aspectRatio
            } else {
                // Taller than wide or square
                drawHeight = stampSize
                drawWidth = stampSize * aspectRatio
            }

            let iconRect = CGRect(
                x: stamp.position.x - drawWidth / 2,
                y: stamp.position.y - drawHeight / 2,
                width: drawWidth,
                height: drawHeight
            )

            // === LAYER 1: DROP SHADOW ===
            let shadowOffset: CGFloat = 3
            let shadowRect = iconRect.offsetBy(dx: shadowOffset, dy: shadowOffset)
            let shadowImage = image.withTintColor(UIColor.black.withAlphaComponent(0.3), renderingMode: .alwaysOriginal)
            shadowImage.draw(in: shadowRect)

            // === LAYER 2: WHITE OUTLINE/STROKE for visibility ===
            let outlineConfig = UIImage.SymbolConfiguration(pointSize: stampSize * 1.08, weight: .regular)
            if let outlineImage = UIImage(systemName: stamp.type.rawValue, withConfiguration: outlineConfig) {
                let outlineSize = CGSize(width: drawWidth * 1.08, height: drawHeight * 1.08)
                let outlineRect = CGRect(
                    x: stamp.position.x - outlineSize.width / 2,
                    y: stamp.position.y - outlineSize.height / 2,
                    width: outlineSize.width,
                    height: outlineSize.height
                )
                let whiteOutline = outlineImage.withTintColor(.white, renderingMode: .alwaysOriginal)
                whiteOutline.draw(in: outlineRect)
            }

            // === LAYER 3: MAIN COLORED ICON ===
            let tintedImage = image.withTintColor(color, renderingMode: .alwaysOriginal)
            tintedImage.draw(in: iconRect)

        } else {
            // Fallback: draw simple colored circle
            let iconRect = CGRect(
                x: stamp.position.x - stampSize / 2,
                y: stamp.position.y - stampSize / 2,
                width: stampSize,
                height: stampSize
            )
            context.setFillColor(color.cgColor)
            context.fillEllipse(in: iconRect)
        }

        context.restoreGState()
    }

    /// Draw a custom stamp (from user photos) into a graphics context
    private func drawCustomStamp(_ stamp: Stamp, image: UIImage, in context: CGContext) {
        let baseSize: CGFloat = 100
        let stickerSize: CGFloat = baseSize * stamp.scale

        // Apply rotation around center
        context.translateBy(x: stamp.position.x, y: stamp.position.y)
        context.rotate(by: stamp.rotation)
        context.translateBy(x: -stamp.position.x, y: -stamp.position.y)

        // Calculate size maintaining aspect ratio
        let imageSize = image.size
        let aspectRatio = imageSize.width / imageSize.height

        var drawWidth: CGFloat
        var drawHeight: CGFloat

        if aspectRatio > 1 {
            drawWidth = stickerSize
            drawHeight = stickerSize / aspectRatio
        } else {
            drawHeight = stickerSize
            drawWidth = stickerSize * aspectRatio
        }

        let stickerRect = CGRect(
            x: stamp.position.x - drawWidth / 2,
            y: stamp.position.y - drawHeight / 2,
            width: drawWidth,
            height: drawHeight
        )

        // Draw shadow
        let shadowOffset: CGFloat = 4
        let shadowRect = stickerRect.offsetBy(dx: shadowOffset, dy: shadowOffset)
        context.saveGState()
        context.setAlpha(0.3)
        image.draw(in: shadowRect)
        context.restoreGState()

        // Draw main image
        image.draw(in: stickerRect)
    }

    /// Draw a single stroke into a graphics context
    private func drawStroke(_ stroke: Stroke, in context: CGContext) {
        guard stroke.points.count > 0 else { return }

        context.saveGState()

        // Set up stroke properties
        context.setLineCap(.round)
        context.setLineJoin(.round)
        context.setLineWidth(stroke.lineWidth)
        context.setStrokeColor(stroke.color.cgColor)
        context.setAlpha(stroke.brushType.opacity)

        // Handle eraser
        if stroke.brushType == .eraser {
            context.setBlendMode(.clear)
        }

        // Get smoothed points for nice curves
        let smoothedPoints = stroke.smoothedPoints()

        guard let firstPoint = smoothedPoints.first else {
            context.restoreGState()
            return
        }

        // Draw the path
        context.beginPath()
        context.move(to: firstPoint)

        for i in 1..<smoothedPoints.count {
            context.addLine(to: smoothedPoints[i])
        }

        context.strokePath()

        // Add sparkle effect for sparkle brush
        if stroke.brushType == .sparkle {
            drawSparkles(on: smoothedPoints, color: stroke.color, in: context)
        }

        context.restoreGState()
    }

    /// Draw sparkle effects along a path
    private func drawSparkles(on points: [CGPoint], color: UIColor, in context: CGContext) {
        let sparkleInterval = 10
        for (index, point) in points.enumerated() where index % sparkleInterval == 0 {
            // Use deterministic noise for consistent sparkle sizes
            let sizeNoise = deterministicNoise(point.x, point.y, seed: index)
            let size = 2 + sizeNoise * 4 // Range: 2...6
            let rect = CGRect(
                x: point.x - size / 2,
                y: point.y - size / 2,
                width: size,
                height: size
            )

            context.setFillColor(UIColor.white.withAlphaComponent(0.8).cgColor)
            context.fillEllipse(in: rect)
        }
    }

    /// Deterministic pseudo-random noise based on position (consistent across redraws)
    private func deterministicNoise(_ x: CGFloat, _ y: CGFloat, seed: Int) -> CGFloat {
        let n = Int(x * 374761393 + y * 668265263 + CGFloat(seed) * 1013904223)
        let hash = (n ^ (n >> 13)) &* 1274126177
        return CGFloat(abs(hash) % 10000) / 10000.0
    }

    /// Save the document to a file
    func save(to url: URL) throws {
        let data = try JSONEncoder().encode(SerializableDocument(from: self))
        try data.write(to: url)
    }

    /// Load a document from a file
    func load(from url: URL) throws {
        let data = try Data(contentsOf: url)
        let serializable = try JSONDecoder().decode(SerializableDocument.self, from: data)
        serializable.restore(to: self)
        onDocumentChanged?()
    }
}

// MARK: - Serialization Support

private struct SerializableDocument: Codable {
    let strokes: [SerializableStroke]
    let stamps: [SerializableStamp]?  // Optional for backward compatibility
    let backgroundColor: SerializableColor

    init(from document: DrawingDocument) {
        self.strokes = document.strokes.map { SerializableStroke(from: $0) }
        self.stamps = document.stamps.map { SerializableStamp(from: $0) }
        self.backgroundColor = SerializableColor(from: document.backgroundColor)
    }

    func restore(to document: DrawingDocument) {
        // Use load methods to avoid creating undo history
        document.loadStrokes(strokes.map { $0.toStroke() })
        document.loadStamps((stamps ?? []).map { $0.toStamp() })
        document.backgroundColor = backgroundColor.toUIColor()
    }
}

private struct SerializableStamp: Codable {
    let id: String
    let type: String
    let positionX: CGFloat
    let positionY: CGFloat
    let scale: CGFloat
    let rotation: CGFloat
    let color: SerializableColor?
    let customStickerId: String?  // For custom stickers

    init(from stamp: Stamp) {
        self.id = stamp.id.uuidString
        self.type = stamp.type.rawValue
        self.positionX = stamp.position.x
        self.positionY = stamp.position.y
        self.scale = stamp.scale
        self.rotation = stamp.rotation
        self.color = stamp.color.map { SerializableColor(from: $0) }
        self.customStickerId = stamp.customStickerId?.uuidString
    }

    func toStamp() -> Stamp {
        let uuid = UUID(uuidString: id) ?? UUID()

        // Check if this is a custom sticker
        if let customIdString = customStickerId, let customId = UUID(uuidString: customIdString) {
            return Stamp(
                id: uuid,
                customStickerId: customId,
                position: CGPoint(x: positionX, y: positionY),
                scale: scale,
                rotation: rotation
            )
        }

        // Regular stamp
        let stampType = StampType(rawValue: type) ?? .star
        return Stamp(
            id: uuid,
            type: stampType,
            position: CGPoint(x: positionX, y: positionY),
            scale: scale,
            rotation: rotation,
            color: color?.toUIColor()
        )
    }
}

private struct SerializableStroke: Codable {
    let id: String?  // Optional for backward compatibility with old files
    let points: [SerializablePoint]
    let color: SerializableColor
    let brushType: String
    let lineWidth: CGFloat

    init(from stroke: Stroke) {
        self.id = stroke.id.uuidString
        self.points = stroke.points.map { SerializablePoint(from: $0) }
        self.color = SerializableColor(from: stroke.color)
        self.brushType = stroke.brushType.rawValue
        self.lineWidth = stroke.lineWidth
    }

    func toStroke() -> Stroke {
        let brush = BrushType(rawValue: brushType) ?? .pencil
        let stroke: Stroke
        if let idString = id, let uuid = UUID(uuidString: idString) {
            stroke = Stroke(id: uuid, color: color.toUIColor(), brushType: brush, lineWidth: lineWidth)
        } else {
            stroke = Stroke(color: color.toUIColor(), brushType: brush, lineWidth: lineWidth)
        }
        stroke.points = points.map { $0.toStrokePoint() }
        return stroke
    }
}

private struct SerializablePoint: Codable {
    let x: CGFloat
    let y: CGFloat
    let pressure: CGFloat
    let timestamp: TimeInterval

    init(from point: StrokePoint) {
        self.x = point.position.x
        self.y = point.position.y
        self.pressure = point.pressure
        self.timestamp = point.timestamp
    }

    func toStrokePoint() -> StrokePoint {
        return StrokePoint(
            position: CGPoint(x: x, y: y),
            pressure: pressure,
            timestamp: timestamp
        )
    }
}

private struct SerializableColor: Codable {
    let red: CGFloat
    let green: CGFloat
    let blue: CGFloat
    let alpha: CGFloat

    init(from color: UIColor) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        self.red = r
        self.green = g
        self.blue = b
        self.alpha = a
    }

    func toUIColor() -> UIColor {
        return UIColor(red: red, green: green, blue: blue, alpha: alpha)
    }
}
