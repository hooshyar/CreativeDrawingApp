//
//  DrawingCanvas.swift
//  CreativeDrawing
//
//  The main canvas where kids draw - handles touch and rendering
//

import UIKit

protocol DrawingCanvasDelegate: AnyObject {
    func canvasDidBeginDrawing(_ canvas: DrawingCanvas)
    func canvasDidEndDrawing(_ canvas: DrawingCanvas)
    func canvasDidChange(_ canvas: DrawingCanvas)
}

/// Drawing mode
enum DrawingMode {
    case draw
    case stamp(StampType)
}

/// Symmetry modes for mirrored drawing
enum SymmetryMode: String, CaseIterable {
    case none = "Off"
    case horizontal = "Mirror"      // Vertical line down the middle, left/right mirror
    case vertical = "Flip"          // Horizontal line, top/bottom mirror
    case quad = "Kaleidoscope"      // Both axes, 4-way symmetry

    var icon: String {
        switch self {
        case .none: return "rectangle"
        case .horizontal: return "arrow.left.and.right"
        case .vertical: return "arrow.up.and.down"
        case .quad: return "plus.viewfinder"
        }
    }

    /// Cycle to next mode
    var next: SymmetryMode {
        let all = SymmetryMode.allCases
        let currentIndex = all.firstIndex(of: self) ?? 0
        let nextIndex = (currentIndex + 1) % all.count
        return all[nextIndex]
    }
}

class DrawingCanvas: UIView {

    // MARK: - Properties

    weak var delegate: DrawingCanvasDelegate?

    /// The document containing all strokes
    let document = DrawingDocument()

    /// Current stroke being drawn
    private var currentStroke: Stroke?

    /// Currently selected color
    var selectedColor: UIColor = ColorPalette.rainbow[0] {
        didSet { setNeedsDisplay() }
    }

    /// Currently selected brush
    var selectedBrush: BrushType = .marker {
        didSet { setNeedsDisplay() }
    }

    /// Current line width multiplier (1.0 = normal)
    var lineWidthMultiplier: CGFloat = 1.0

    /// Current drawing mode
    var drawingMode: DrawingMode = .draw

    /// Symmetry drawing mode
    var symmetryMode: SymmetryMode = .none {
        didSet {
            updateSymmetryGuide()
            setNeedsDisplay()
        }
    }

    /// Mirrored strokes being drawn (for symmetry mode)
    private var mirroredStrokes: [Stroke] = []

    /// Visual guide layer for symmetry axis
    private let symmetryGuideLayer = CAShapeLayer()

    /// Cached image of completed strokes for performance
    private var cachedImage: UIImage?
    private var needsCacheUpdate = true

    /// Rainbow color index for rainbow brush
    private var rainbowColorIndex: Int = 0
    private let rainbowColors = ColorPalette.rainbowGradientColors(count: 360)

    // MARK: - Animation Properties

    /// Display link for animation loop
    private var displayLink: CADisplayLink?

    /// Time when animation started
    private var animationStartTime: CFTimeInterval = 0

    /// Whether live effects (twinkling sparkles, rainbow shimmer) are enabled
    var liveEffectsEnabled: Bool = true {
        didSet {
            if liveEffectsEnabled {
                startAnimationLoopIfNeeded()
            } else {
                stopAnimationLoop()
                // Force cache update to render static versions
                needsCacheUpdate = true
                setNeedsDisplay()
            }
        }
    }

    /// Whether there are any animated strokes in the document
    private var hasAnimatedStrokes: Bool {
        return document.strokes.contains { $0.brushType == .sparkle || $0.brushType == .rainbow }
    }

    /// When both animated AND eraser strokes exist, we must render all strokes each frame
    /// to maintain correct chronological eraser behavior
    private var shouldRenderAllStrokesEachFrame: Bool {
        guard liveEffectsEnabled else { return false }
        let hasAnimated = hasAnimatedStrokes
        let hasErasers = document.strokes.contains { $0.brushType == .eraser }
        return hasAnimated && hasErasers
    }

    /// Strokes that can be cached (rendered once until document changes)
    /// When live effects enabled and no erasers: cache non-animated strokes
    /// When live effects disabled OR no animated strokes: cache ALL strokes including erasers
    private var cacheableStrokes: [Stroke] {
        if shouldRenderAllStrokesEachFrame {
            // Can't cache - need to render all strokes each frame for correct eraser behavior
            return []
        }

        if liveEffectsEnabled {
            // Cache non-animated strokes (erasers included - they'll be in the transparent cache)
            return document.strokes.filter { $0.brushType != .sparkle && $0.brushType != .rainbow }
        } else {
            // Live effects disabled - cache ALL strokes
            return document.strokes
        }
    }

    /// Strokes that must be rendered each frame (only used when shouldRenderAllStrokesEachFrame is false)
    private var liveStrokes: [Stroke] {
        guard liveEffectsEnabled else { return [] }
        // Only animated strokes need live rendering
        return document.strokes.filter { $0.brushType == .sparkle || $0.brushType == .rainbow }
    }

    // MARK: - Initialization

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupCanvas()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupCanvas()
    }

    private func setupCanvas() {
        backgroundColor = .white
        isMultipleTouchEnabled = false
        contentMode = .redraw

        // Enable high-quality rendering
        layer.drawsAsynchronously = true

        // Setup symmetry guide layer
        symmetryGuideLayer.strokeColor = UIColor.systemBlue.withAlphaComponent(0.5).cgColor
        symmetryGuideLayer.lineWidth = 2
        symmetryGuideLayer.lineDashPattern = [8, 6]
        symmetryGuideLayer.fillColor = nil
        layer.addSublayer(symmetryGuideLayer)

        // Setup document callback
        document.onDocumentChanged = { [weak self] in
            guard let self = self else { return }
            self.needsCacheUpdate = true
            self.setNeedsDisplay()
            self.delegate?.canvasDidChange(self)
        }
    }

    /// Update the symmetry guide visual indicator
    private func updateSymmetryGuide() {
        guard bounds.width > 0 && bounds.height > 0 else {
            symmetryGuideLayer.path = nil
            return
        }

        let path = CGMutablePath()
        let centerX = bounds.midX
        let centerY = bounds.midY

        switch symmetryMode {
        case .none:
            symmetryGuideLayer.path = nil
            return

        case .horizontal:
            // Vertical line down the middle
            path.move(to: CGPoint(x: centerX, y: 0))
            path.addLine(to: CGPoint(x: centerX, y: bounds.height))

        case .vertical:
            // Horizontal line across the middle
            path.move(to: CGPoint(x: 0, y: centerY))
            path.addLine(to: CGPoint(x: bounds.width, y: centerY))

        case .quad:
            // Both lines for 4-way symmetry
            path.move(to: CGPoint(x: centerX, y: 0))
            path.addLine(to: CGPoint(x: centerX, y: bounds.height))
            path.move(to: CGPoint(x: 0, y: centerY))
            path.addLine(to: CGPoint(x: bounds.width, y: centerY))
        }

        symmetryGuideLayer.path = path

        // Animate the guide appearing
        let animation = CABasicAnimation(keyPath: "strokeEnd")
        animation.fromValue = 0
        animation.toValue = 1
        animation.duration = 0.3
        symmetryGuideLayer.add(animation, forKey: "drawGuide")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        symmetryGuideLayer.frame = bounds
        updateSymmetryGuide()
    }

    // MARK: - Animation Loop

    /// Start animation loop if needed (when there are animated strokes and live effects are enabled)
    private func startAnimationLoopIfNeeded() {
        guard liveEffectsEnabled, hasAnimatedStrokes, displayLink == nil else { return }

        animationStartTime = CACurrentMediaTime()
        displayLink = CADisplayLink(target: self, selector: #selector(animationTick(_:)))

        if #available(iOS 15.0, *) {
            displayLink?.preferredFrameRateRange = CAFrameRateRange(
                minimum: 30,
                maximum: 60,
                preferred: 60
            )
        }

        displayLink?.add(to: .main, forMode: .common)
    }

    /// Stop the animation loop
    private func stopAnimationLoop() {
        displayLink?.invalidate()
        displayLink = nil
    }

    /// Called each frame during animation
    @objc private func animationTick(_ link: CADisplayLink) {
        // Only redraw if we have animated content
        guard hasAnimatedStrokes else {
            stopAnimationLoop()
            return
        }
        setNeedsDisplay()
    }

    /// Check if animation loop should be running and update accordingly
    private func updateAnimationLoopState() {
        if liveEffectsEnabled && hasAnimatedStrokes {
            startAnimationLoopIfNeeded()
        } else {
            stopAnimationLoop()
        }
    }

    // MARK: - Touch Handling

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }

        let point = touch.location(in: self)

        // Handle custom sticker mode
        if let sticker = pendingCustomSticker {
            placeCustomSticker(sticker, at: point)
            return
        }

        // Handle stamp mode
        if case .stamp(let stampType) = drawingMode {
            placeStamp(stampType, at: point)
            return
        }

        let pressure = touch.force > 0 ? touch.force / touch.maximumPossibleForce : 1.0

        // Create new stroke with current settings
        let color = selectedBrush == .rainbow ? rainbowColors[rainbowColorIndex] : selectedColor
        currentStroke = Stroke(
            color: color,
            brushType: selectedBrush,
            lineWidth: selectedBrush.baseWidth * lineWidthMultiplier
        )
        currentStroke?.addPoint(at: point, pressure: pressure)

        // Create mirrored strokes for symmetry mode
        mirroredStrokes = createMirroredStrokes(for: currentStroke!, startPoint: point, pressure: pressure)

        delegate?.canvasDidBeginDrawing(self)

        // Play haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()

        setNeedsDisplay()
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first,
              let stroke = currentStroke else { return }

        let point = touch.location(in: self)
        let pressure = touch.force > 0 ? touch.force / touch.maximumPossibleForce : 1.0

        // For rainbow brush, cycle through colors
        if selectedBrush == .rainbow {
            rainbowColorIndex = (rainbowColorIndex + 3) % rainbowColors.count
            currentStroke?.color = rainbowColors[rainbowColorIndex]

            // Update mirrored stroke colors too
            for i in 0..<mirroredStrokes.count {
                mirroredStrokes[i].color = rainbowColors[rainbowColorIndex]
            }
        }

        currentStroke?.addPoint(at: point, pressure: pressure)

        // Add mirrored points to mirrored strokes
        let mirroredPoints = getMirroredPoints(for: point)
        for (index, mirroredPoint) in mirroredPoints.enumerated() where index < mirroredStrokes.count {
            mirroredStrokes[index].addPoint(at: mirroredPoint, pressure: pressure)
        }

        // Redraw - for symmetry we need to redraw more area
        if symmetryMode != .none {
            setNeedsDisplay()
        } else {
            // Only redraw the affected region for performance
            let lastPoints = stroke.points.suffix(2)
            if lastPoints.count >= 2 {
                let rect = rectForPoints(Array(lastPoints), lineWidth: stroke.lineWidth)
                setNeedsDisplay(rect.insetBy(dx: -stroke.lineWidth, dy: -stroke.lineWidth))
            } else {
                setNeedsDisplay()
            }
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let stroke = currentStroke else { return }

        // Only add stroke if it has points
        if stroke.points.count > 0 {
            document.addStroke(stroke)

            // Also add mirrored strokes
            for mirroredStroke in mirroredStrokes {
                if mirroredStroke.points.count > 0 {
                    document.addStroke(mirroredStroke)
                }
            }

            needsCacheUpdate = true
        }

        currentStroke = nil
        mirroredStrokes = []
        delegate?.canvasDidEndDrawing(self)

        // Play completion haptic
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        setNeedsDisplay()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        currentStroke = nil
        mirroredStrokes = []
        setNeedsDisplay()
    }

    // MARK: - Drawing

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }

        // Fill background
        document.backgroundColor.setFill()
        context.fill(rect)

        // Draw fill regions (underneath everything else)
        for fill in document.fills {
            fill.filledImage.draw(at: .zero)
        }

        // Handle stroke rendering based on caching strategy
        if shouldRenderAllStrokesEachFrame {
            // When both animated and eraser strokes exist, render ALL strokes each frame
            // on a transparent buffer to maintain correct eraser behavior
            let format = UIGraphicsImageRendererFormat()
            format.opaque = false

            let renderer = UIGraphicsImageRenderer(size: bounds.size, format: format)
            let strokesImage = renderer.image { rendererContext in
                let timeOffset = liveEffectsEnabled ? CACurrentMediaTime() - animationStartTime : 0
                for stroke in document.strokes {
                    drawStroke(stroke, in: rendererContext.cgContext, timeOffset: timeOffset)
                }
            }
            strokesImage.draw(at: .zero)
        } else {
            // Use cached image for static strokes
            if needsCacheUpdate {
                updateCache()
            }
            cachedImage?.draw(at: .zero)

            // Draw live strokes (animated) on top
            if liveEffectsEnabled && !liveStrokes.isEmpty {
                let timeOffset = CACurrentMediaTime() - animationStartTime
                for stroke in liveStrokes {
                    drawStroke(stroke, in: context, timeOffset: timeOffset)
                }
            }
        }

        // Draw stamps from document (stamps are not affected by eraser)
        for stamp in document.stamps {
            drawStamp(stamp, in: context)
        }

        // Draw current stroke (in progress)
        if let stroke = currentStroke {
            let timeOffset = liveEffectsEnabled ? CACurrentMediaTime() - animationStartTime : 0
            drawStroke(stroke, in: context, timeOffset: timeOffset)

            // Also draw mirrored strokes in progress
            for mirroredStroke in mirroredStrokes {
                drawStroke(mirroredStroke, in: context, timeOffset: timeOffset)
            }
        }
    }

    private func drawStamp(_ stamp: Stamp, in context: CGContext) {
        context.saveGState()

        // Handle custom stickers
        if stamp.isCustomSticker, let customImage = stamp.customImage {
            drawCustomSticker(stamp, image: customImage, in: context)
            context.restoreGState()
            return
        }

        // TRANSPARENT STICKER - Just the icon with subtle effects
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
            // Draw slightly larger white version behind for outline effect
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

    /// Draw a custom sticker (from user photos)
    private func drawCustomSticker(_ stamp: Stamp, image: UIImage, in context: CGContext) {
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

        // === LAYER 1: DROP SHADOW ===
        let shadowOffset: CGFloat = 4
        let shadowRect = stickerRect.offsetBy(dx: shadowOffset, dy: shadowOffset)

        // Create shadow image by drawing with black tint
        UIGraphicsPushContext(context)
        context.saveGState()
        context.setAlpha(0.3)
        context.clip(to: shadowRect, mask: image.cgImage!)
        context.setFillColor(UIColor.black.cgColor)
        context.fill(shadowRect)
        context.restoreGState()
        UIGraphicsPopContext()

        // === LAYER 2: WHITE BORDER ===
        let borderSize: CGFloat = 4
        let borderRect = stickerRect.insetBy(dx: -borderSize, dy: -borderSize)
        context.setFillColor(UIColor.white.cgColor)
        context.fillEllipse(in: borderRect)

        // === LAYER 3: MAIN IMAGE ===
        image.draw(in: stickerRect)
    }

    private func updateCache() {
        // Create transparent format - CRITICAL for eraser to work correctly
        // Without this, eraser paints background color instead of truly erasing
        let format = UIGraphicsImageRendererFormat()
        format.opaque = false

        let renderer = UIGraphicsImageRenderer(size: bounds.size, format: format)
        cachedImage = renderer.image { rendererContext in
            // Render cacheable strokes in chronological order
            // Erasers are included here and will punch holes in the transparent buffer
            for stroke in cacheableStrokes {
                drawStroke(stroke, in: rendererContext.cgContext)
            }
        }
        needsCacheUpdate = false

        // Update animation loop state after cache update
        updateAnimationLoopState()
    }

    private func drawStroke(_ stroke: Stroke, in context: CGContext, timeOffset: CFTimeInterval = 0) {
        BrushRenderer.drawStroke(stroke, in: context, timeOffset: timeOffset)
    }

    // MARK: - Symmetry Methods

    /// Create mirrored strokes for the current symmetry mode
    private func createMirroredStrokes(for stroke: Stroke, startPoint: CGPoint, pressure: CGFloat) -> [Stroke] {
        guard symmetryMode != .none else { return [] }

        var strokes: [Stroke] = []
        let mirroredPoints = getMirroredPoints(for: startPoint)

        for mirroredPoint in mirroredPoints {
            var mirroredStroke = Stroke(
                color: stroke.color,
                brushType: stroke.brushType,
                lineWidth: stroke.lineWidth
            )
            mirroredStroke.addPoint(at: mirroredPoint, pressure: pressure)
            strokes.append(mirroredStroke)
        }

        return strokes
    }

    /// Get mirrored points for a given point based on symmetry mode
    private func getMirroredPoints(for point: CGPoint) -> [CGPoint] {
        guard symmetryMode != .none else { return [] }

        var points: [CGPoint] = []
        let centerX = bounds.midX
        let centerY = bounds.midY

        switch symmetryMode {
        case .none:
            break

        case .horizontal:
            // Mirror across vertical axis (left/right)
            let mirroredX = centerX - (point.x - centerX)
            points.append(CGPoint(x: mirroredX, y: point.y))

        case .vertical:
            // Mirror across horizontal axis (top/bottom)
            let mirroredY = centerY - (point.y - centerY)
            points.append(CGPoint(x: point.x, y: mirroredY))

        case .quad:
            // Mirror across both axes (4-way symmetry)
            let mirroredX = centerX - (point.x - centerX)
            let mirroredY = centerY - (point.y - centerY)

            points.append(CGPoint(x: mirroredX, y: point.y))          // Left/right mirror
            points.append(CGPoint(x: point.x, y: mirroredY))          // Top/bottom mirror
            points.append(CGPoint(x: mirroredX, y: mirroredY))        // Diagonal mirror
        }

        return points
    }

    /// Toggle to next symmetry mode
    func cycleSymmetryMode() {
        symmetryMode = symmetryMode.next
        SoundManager.shared.play(.tap)
        SoundManager.shared.playHaptic(.selection)
    }

    // MARK: - Helper Methods

    private func rectForPoints(_ points: [StrokePoint], lineWidth: CGFloat) -> CGRect {
        guard let first = points.first else { return .zero }

        var minX = first.position.x
        var maxX = first.position.x
        var minY = first.position.y
        var maxY = first.position.y

        for point in points {
            minX = min(minX, point.position.x)
            maxX = max(maxX, point.position.x)
            minY = min(minY, point.position.y)
            maxY = max(maxY, point.position.y)
        }

        return CGRect(
            x: minX - lineWidth,
            y: minY - lineWidth,
            width: maxX - minX + lineWidth * 2,
            height: maxY - minY + lineWidth * 2
        )
    }

    // MARK: - Public Actions

    func undo() {
        document.undo()
        needsCacheUpdate = true
        setNeedsDisplay()
    }

    func redo() {
        document.redo()
        needsCacheUpdate = true
        setNeedsDisplay()
    }

    func clearCanvas() {
        document.clear()
        needsCacheUpdate = true
        setNeedsDisplay()

        // Play clear sound haptic
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)
    }

    func exportImage() -> UIImage? {
        return document.exportAsImage(size: bounds.size)
    }

    func setBackgroundColor(_ color: UIColor) {
        document.backgroundColor = color
        backgroundColor = color
        needsCacheUpdate = true
        setNeedsDisplay()
    }

    // MARK: - Stamp Methods

    func placeStamp(_ stampType: StampType, at position: CGPoint) {
        let stamp = Stamp(
            type: stampType,
            position: position,
            scale: lineWidthMultiplier,  // Use size slider for stamp size
            color: selectedColor
        )
        document.addStamp(stamp)
        needsCacheUpdate = true
        setNeedsDisplay()

        // Celebration feedback
        SoundManager.shared.play(.pop)
        SoundManager.shared.playHaptic(.heavy)

        // Professional stamp animation
        showProfessionalStampAnimation(at: position, stampType: stampType)
    }

    private func showProfessionalStampAnimation(at position: CGPoint, stampType: StampType) {
        let color = selectedColor

        // === MAIN STICKER ANIMATION (transparent icon with bounce) ===
        let iconView = UIImageView()
        let iconSize: CGFloat = 100
        let iconConfig = UIImage.SymbolConfiguration(pointSize: iconSize, weight: .regular)
        iconView.image = UIImage(systemName: stampType.rawValue, withConfiguration: iconConfig)
        iconView.tintColor = color
        iconView.contentMode = .scaleAspectFit
        iconView.frame = CGRect(x: 0, y: 0, width: iconSize, height: iconSize)
        iconView.center = position

        // Add subtle shadow to icon
        iconView.layer.shadowColor = UIColor.black.cgColor
        iconView.layer.shadowOffset = CGSize(width: 2, height: 2)
        iconView.layer.shadowOpacity = 0.3
        iconView.layer.shadowRadius = 4

        addSubview(iconView)

        // Start animation - icon bounces in
        iconView.transform = CGAffineTransform(scaleX: 1.5, y: 1.5)
        iconView.alpha = 0

        // Phase 1: Pop in
        UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseOut) {
            iconView.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
            iconView.alpha = 1
        } completion: { _ in
            // Phase 2: Bounce back
            UIView.animate(withDuration: 0.15, delay: 0, usingSpringWithDamping: 0.5, initialSpringVelocity: 0.8) {
                iconView.transform = .identity
            } completion: { _ in
                // Phase 3: Fade out
                UIView.animate(withDuration: 0.25, delay: 0.15, options: .curveEaseOut) {
                    iconView.alpha = 0
                    iconView.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
                } completion: { _ in
                    iconView.removeFromSuperview()
                }
            }
        }

        // === PARTICLE BURST EFFECT ===
        let particleColors: [UIColor] = [
            color,
            color.withAlphaComponent(0.7),
            .systemYellow,
            .white
        ]

        for i in 0..<8 {
            let particle = UIView()
            let particleSize: CGFloat = CGFloat.random(in: 6...12)
            particle.frame = CGRect(x: 0, y: 0, width: particleSize, height: particleSize)
            particle.center = position
            particle.backgroundColor = particleColors[i % particleColors.count]
            particle.layer.cornerRadius = particleSize / 2
            particle.alpha = 0
            addSubview(particle)

            let angle = CGFloat(i) * .pi / 4
            let distance: CGFloat = CGFloat.random(in: 60...100)

            UIView.animate(withDuration: 0.4, delay: 0.1, options: .curveEaseOut) {
                particle.center = CGPoint(
                    x: position.x + cos(angle) * distance,
                    y: position.y + sin(angle) * distance
                )
                particle.alpha = 1
                particle.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
            } completion: { _ in
                UIView.animate(withDuration: 0.2) {
                    particle.alpha = 0
                } completion: { _ in
                    particle.removeFromSuperview()
                }
            }
        }

        // === RING BURST EFFECT ===
        let ringView = UIView()
        ringView.frame = CGRect(x: 0, y: 0, width: 20, height: 20)
        ringView.center = position
        ringView.backgroundColor = .clear
        ringView.layer.borderColor = color.withAlphaComponent(0.6).cgColor
        ringView.layer.borderWidth = 3
        ringView.layer.cornerRadius = 10
        ringView.alpha = 0
        addSubview(ringView)

        UIView.animate(withDuration: 0.4, delay: 0.05, options: .curveEaseOut) {
            ringView.transform = CGAffineTransform(scaleX: 8, y: 8)
            ringView.alpha = 0.8
        } completion: { _ in
            UIView.animate(withDuration: 0.2) {
                ringView.alpha = 0
            } completion: { _ in
                ringView.removeFromSuperview()
            }
        }
    }

    /// Place a custom sticker from user photos
    func placeCustomSticker(_ sticker: CustomSticker, at position: CGPoint) {
        let stamp = Stamp(
            customSticker: sticker,
            position: position,
            scale: lineWidthMultiplier  // Use size slider for sticker size
        )
        document.addStamp(stamp)
        needsCacheUpdate = true
        setNeedsDisplay()

        // Celebration feedback
        SoundManager.shared.play(.pop)
        SoundManager.shared.playHaptic(.heavy)

        // Custom sticker animation
        showCustomStickerAnimation(at: position, image: stamp.customImage)
    }

    private func showCustomStickerAnimation(at position: CGPoint, image: UIImage?) {
        guard let image = image else { return }

        let imageView = UIImageView(image: image)
        let size: CGFloat = 100
        imageView.frame = CGRect(x: 0, y: 0, width: size, height: size)
        imageView.center = position
        imageView.contentMode = .scaleAspectFit

        // Add shadow
        imageView.layer.shadowColor = UIColor.black.cgColor
        imageView.layer.shadowOffset = CGSize(width: 2, height: 2)
        imageView.layer.shadowOpacity = 0.3
        imageView.layer.shadowRadius = 4

        addSubview(imageView)

        // Animate
        imageView.transform = CGAffineTransform(scaleX: 1.5, y: 1.5)
        imageView.alpha = 0

        UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseOut) {
            imageView.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
            imageView.alpha = 1
        } completion: { _ in
            UIView.animate(withDuration: 0.15, delay: 0, usingSpringWithDamping: 0.5, initialSpringVelocity: 0.8) {
                imageView.transform = .identity
            } completion: { _ in
                UIView.animate(withDuration: 0.25, delay: 0.15, options: .curveEaseOut) {
                    imageView.alpha = 0
                    imageView.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
                } completion: { _ in
                    imageView.removeFromSuperview()
                }
            }
        }

        // Sparkle particles
        for i in 0..<6 {
            let particle = UIView()
            let particleSize: CGFloat = CGFloat.random(in: 8...14)
            particle.frame = CGRect(x: 0, y: 0, width: particleSize, height: particleSize)
            particle.center = position
            particle.backgroundColor = [UIColor.systemYellow, .systemPink, .systemCyan, .systemPurple][i % 4]
            particle.layer.cornerRadius = particleSize / 2
            particle.alpha = 0
            addSubview(particle)

            let angle = CGFloat(i) * .pi / 3
            let distance: CGFloat = CGFloat.random(in: 50...80)

            UIView.animate(withDuration: 0.4, delay: 0.1, options: .curveEaseOut) {
                particle.center = CGPoint(
                    x: position.x + cos(angle) * distance,
                    y: position.y + sin(angle) * distance
                )
                particle.alpha = 1
            } completion: { _ in
                UIView.animate(withDuration: 0.2) {
                    particle.alpha = 0
                } completion: { _ in
                    particle.removeFromSuperview()
                }
            }
        }
    }

    /// Set mode to place a custom sticker
    var pendingCustomSticker: CustomSticker?

    func setCustomStickerMode(_ sticker: CustomSticker) {
        pendingCustomSticker = sticker
        drawingMode = .draw // We'll intercept in touchesBegan
    }

    func setStampMode(_ stampType: StampType) {
        pendingCustomSticker = nil
        drawingMode = .stamp(stampType)
    }

    func setDrawMode() {
        pendingCustomSticker = nil
        drawingMode = .draw
    }
}
