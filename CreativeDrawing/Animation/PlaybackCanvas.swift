//
//  PlaybackCanvas.swift
//  CreativeDrawing
//
//  Canvas view for rendering animation playback
//

import UIKit

/// A canvas specifically for rendering animation playback
class PlaybackCanvas: UIView {

    // MARK: - Properties

    /// Current render state from the playback engine
    var renderState: PlaybackRenderState? {
        didSet {
            setNeedsDisplay()
        }
    }

    /// Whether to show the pen tip indicator during playback
    var showPenTip: Bool = true

    /// Whether to animate sparkle/rainbow strokes during playback
    var animateBrushEffects: Bool = true

    /// Animation time offset for brush effects
    private var animationTimeOffset: CFTimeInterval = 0

    /// Pen tip indicator view
    private var penTipView: UIView?

    /// Size of the pen tip indicator
    var penTipSize: CGFloat = 20

    /// Animation time for animated brush effects
    var currentAnimationTime: CFTimeInterval = 0 {
        didSet {
            animationTimeOffset = currentAnimationTime
        }
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
        contentMode = .redraw
        layer.cornerRadius = 12
        clipsToBounds = true
    }

    // MARK: - Drawing

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }

        guard let state = renderState else {
            // Draw empty white canvas
            UIColor.white.setFill()
            context.fill(rect)
            return
        }

        // Fill background
        state.backgroundColor.setFill()
        context.fill(rect)

        // Draw fill regions
        for fill in state.completedFills {
            fill.filledImage.draw(at: .zero)
        }

        // Check if we have any eraser strokes - need transparent buffer for correct rendering
        let allStrokes = state.completedStrokes + (state.activeStroke.map { active in
            [StrokeAnimator.partialStroke(from: active.stroke, pointCount: active.visiblePointCount)]
        } ?? [])
        let hasEraserStrokes = allStrokes.contains { $0.brushType == .eraser }

        if hasEraserStrokes {
            // Render all strokes on transparent buffer for correct eraser behavior
            let format = UIGraphicsImageRendererFormat()
            format.opaque = false

            let renderer = UIGraphicsImageRenderer(size: bounds.size, format: format)
            let strokesImage = renderer.image { rendererContext in
                let timeOffset = animateBrushEffects ? animationTimeOffset : 0

                // Draw completed strokes
                for stroke in state.completedStrokes {
                    drawStroke(stroke, in: rendererContext.cgContext, timeOffset: timeOffset)
                }

                // Draw active (partial) stroke
                if let active = state.activeStroke {
                    let partialStroke = StrokeAnimator.partialStroke(
                        from: active.stroke,
                        pointCount: active.visiblePointCount
                    )
                    drawStroke(partialStroke, in: rendererContext.cgContext, timeOffset: timeOffset)
                }
            }
            strokesImage.draw(at: .zero)
        } else {
            // No erasers - draw strokes directly for better performance
            let timeOffset = animateBrushEffects ? animationTimeOffset : 0

            // Draw completed strokes
            for stroke in state.completedStrokes {
                drawStroke(stroke, in: context, timeOffset: timeOffset)
            }

            // Draw active (partial) stroke
            if let active = state.activeStroke {
                let partialStroke = StrokeAnimator.partialStroke(
                    from: active.stroke,
                    pointCount: active.visiblePointCount
                )
                drawStroke(partialStroke, in: context, timeOffset: timeOffset)
            }
        }

        // Draw completed stamps
        for stamp in state.completedStamps {
            drawStamp(stamp, in: context)
        }

        // Update pen tip position
        updatePenTip(state: state)
    }

    // MARK: - Pen Tip

    private func updatePenTip(state: PlaybackRenderState) {
        guard showPenTip, let position = state.penTipPosition else {
            penTipView?.removeFromSuperview()
            penTipView = nil
            return
        }

        if penTipView == nil {
            let view = UIView(frame: CGRect(x: 0, y: 0, width: penTipSize, height: penTipSize))
            view.layer.cornerRadius = penTipSize / 2
            view.layer.shadowRadius = 4
            view.layer.shadowOpacity = 0.5
            view.layer.shadowOffset = .zero
            addSubview(view)
            penTipView = view
        }

        // Update pen tip appearance based on active stroke
        if let active = state.activeStroke {
            penTipView?.backgroundColor = active.stroke.color.withAlphaComponent(0.8)
            penTipView?.layer.shadowColor = active.stroke.color.cgColor
        } else {
            penTipView?.backgroundColor = UIColor.gray.withAlphaComponent(0.5)
            penTipView?.layer.shadowColor = UIColor.gray.cgColor
        }

        // Animate to new position
        UIView.animate(withDuration: 0.05) {
            self.penTipView?.center = position
        }
    }

    // MARK: - Stroke Drawing

    private func drawStroke(_ stroke: Stroke, in context: CGContext, timeOffset: CFTimeInterval = 0) {
        BrushRenderer.drawStroke(stroke, in: context, timeOffset: timeOffset)
    }

    // MARK: - Stamp Drawing

    private func drawStamp(_ stamp: Stamp, in context: CGContext) {
        context.saveGState()

        if stamp.isCustomSticker, let customImage = stamp.customImage {
            drawCustomSticker(stamp, image: customImage, in: context)
            context.restoreGState()
            return
        }

        let baseSize: CGFloat = 80
        let stampSize: CGFloat = baseSize * stamp.scale
        let color = stamp.color ?? stamp.type.defaultColor

        context.translateBy(x: stamp.position.x, y: stamp.position.y)
        context.rotate(by: stamp.rotation)
        context.translateBy(x: -stamp.position.x, y: -stamp.position.y)

        let config = UIImage.SymbolConfiguration(pointSize: stampSize, weight: .regular)
            .applying(UIImage.SymbolConfiguration(paletteColors: [color]))

        if let image = UIImage(systemName: stamp.type.rawValue, withConfiguration: config) {
            let imageSize = image.size
            let aspectRatio = imageSize.width / imageSize.height

            var drawWidth: CGFloat
            var drawHeight: CGFloat

            if aspectRatio > 1 {
                drawWidth = stampSize
                drawHeight = stampSize / aspectRatio
            } else {
                drawHeight = stampSize
                drawWidth = stampSize * aspectRatio
            }

            let iconRect = CGRect(
                x: stamp.position.x - drawWidth / 2,
                y: stamp.position.y - drawHeight / 2,
                width: drawWidth,
                height: drawHeight
            )

            let shadowOffset: CGFloat = 3
            let shadowRect = iconRect.offsetBy(dx: shadowOffset, dy: shadowOffset)
            let shadowImage = image.withTintColor(UIColor.black.withAlphaComponent(0.3), renderingMode: .alwaysOriginal)
            shadowImage.draw(in: shadowRect)

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

            let tintedImage = image.withTintColor(color, renderingMode: .alwaysOriginal)
            tintedImage.draw(in: iconRect)
        }

        context.restoreGState()
    }

    private func drawCustomSticker(_ stamp: Stamp, image: UIImage, in context: CGContext) {
        let baseSize: CGFloat = 100
        let stickerSize: CGFloat = baseSize * stamp.scale

        context.translateBy(x: stamp.position.x, y: stamp.position.y)
        context.rotate(by: stamp.rotation)
        context.translateBy(x: -stamp.position.x, y: -stamp.position.y)

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

        let shadowOffset: CGFloat = 4
        let shadowRect = stickerRect.offsetBy(dx: shadowOffset, dy: shadowOffset)
        context.saveGState()
        context.setAlpha(0.3)
        image.draw(in: shadowRect)
        context.restoreGState()

        image.draw(in: stickerRect)
    }

    // MARK: - Public Methods

    /// Update the render state and trigger a redraw
    func updateRenderState(_ state: PlaybackRenderState) {
        self.currentAnimationTime = state.currentTime
        self.renderState = state
    }

    // MARK: - Frame Capture

    /// Capture the current render state as an image
    func captureFrame() -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: bounds.size)
        return renderer.image { context in
            self.layer.render(in: context.cgContext)
        }
    }

    /// Render a specific render state to an image
    func renderState(_ state: PlaybackRenderState, size: CGSize, timeOffset: CFTimeInterval = 0) -> UIImage {
        let previousState = self.renderState
        let previousTimeOffset = self.animationTimeOffset

        self.renderState = state
        self.animationTimeOffset = timeOffset

        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            self.draw(CGRect(origin: .zero, size: size))
        }

        self.renderState = previousState
        self.animationTimeOffset = previousTimeOffset

        return image
    }
}
