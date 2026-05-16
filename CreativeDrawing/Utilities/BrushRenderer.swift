//
//  BrushRenderer.swift
//  CreativeDrawing
//
//  Shared brush rendering utilities used by DrawingCanvas and PlaybackCanvas
//

import UIKit

/// Shared brush rendering utilities for consistent rendering across canvas views
final class BrushRenderer {

    // MARK: - Main Stroke Drawing

    /// Draw a stroke with the appropriate brush type
    /// - Parameters:
    ///   - stroke: The stroke to render
    ///   - context: The graphics context to draw into
    ///   - timeOffset: Animation time offset for animated brushes (sparkle, rainbow)
    static func drawStroke(_ stroke: Stroke, in context: CGContext, timeOffset: CFTimeInterval = 0) {
        guard stroke.points.count > 0 else { return }

        context.saveGState()

        // Configure stroke style
        context.setLineCap(.round)
        context.setLineJoin(.round)
        context.setLineWidth(stroke.lineWidth)
        context.setAlpha(stroke.brushType.opacity)

        // Handle eraser
        if stroke.brushType == .eraser {
            context.setBlendMode(.clear)
            context.setStrokeColor(UIColor.white.cgColor)
        } else {
            context.setStrokeColor(stroke.color.cgColor)
        }

        // Draw based on brush type
        switch stroke.brushType {
        case .pencil:
            drawPencilStroke(stroke, in: context)
        case .marker:
            drawMarkerStroke(stroke, in: context)
        case .crayon:
            drawCrayonStroke(stroke, in: context)
        case .sparkle:
            drawSparkleStroke(stroke, in: context, timeOffset: timeOffset)
        case .rainbow:
            drawRainbowStroke(stroke, in: context, timeOffset: timeOffset)
        case .spray:
            drawSprayStroke(stroke, in: context)
        case .eraser:
            drawMarkerStroke(stroke, in: context)
        }

        context.restoreGState()
    }

    // MARK: - Brush Implementations

    /// Draw a pencil stroke with sketchy texture
    static func drawPencilStroke(_ stroke: Stroke, in context: CGContext) {
        let points = stroke.points
        guard points.count > 0 else { return }

        let baseColor = stroke.color
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        baseColor.getRed(&r, green: &g, blue: &b, alpha: &a)

        // Draw multiple thin lines for pencil texture effect
        for pass in 0..<3 {
            context.setLineWidth(stroke.lineWidth * 0.4)
            context.setAlpha(0.5)

            let offset = CGFloat(pass - 1) * 0.8

            context.beginPath()
            for (index, point) in points.enumerated() {
                // Add sketchy variation based on position
                let noise = deterministicNoise(point.position.x, point.position.y, seed: pass + index)
                let sketchOffset = (noise - 0.5) * stroke.lineWidth * 0.5

                let adjustedPoint = CGPoint(
                    x: point.position.x + offset + sketchOffset,
                    y: point.position.y + sketchOffset
                )

                if index == 0 {
                    context.move(to: adjustedPoint)
                } else {
                    context.addLine(to: adjustedPoint)
                }
            }
            context.strokePath()
        }

        // Add graphite grain texture
        let smoothPoints = stroke.smoothedPoints(granularity: 2)
        for (index, point) in smoothPoints.enumerated() where index % 3 == 0 {
            let grainSize = stroke.lineWidth * 0.15
            let noise = deterministicNoise(point.x, point.y, seed: index * 7)
            if noise > 0.4 {
                let grainRect = CGRect(
                    x: point.x - grainSize / 2 + (noise - 0.5) * stroke.lineWidth,
                    y: point.y - grainSize / 2 + (deterministicNoise(point.x, point.y, seed: index * 13) - 0.5) * stroke.lineWidth,
                    width: grainSize,
                    height: grainSize
                )
                context.setFillColor(baseColor.withAlphaComponent(0.3).cgColor)
                context.fillEllipse(in: grainRect)
            }
        }
    }

    /// Draw a marker stroke with bold, smooth chisel-tip effect
    static func drawMarkerStroke(_ stroke: Stroke, in context: CGContext) {
        let points = stroke.smoothedPoints(granularity: 4)
        guard points.count > 1 else { return }

        // Draw a thick soft glow underneath for marker bleed effect
        context.setLineWidth(stroke.lineWidth * 1.3)
        context.setAlpha(0.3)
        context.setStrokeColor(stroke.color.cgColor)

        context.beginPath()
        context.move(to: points[0])
        for point in points.dropFirst() {
            context.addLine(to: point)
        }
        context.strokePath()

        // Main marker stroke - bold and saturated
        context.setLineWidth(stroke.lineWidth)
        context.setAlpha(0.85)
        context.setStrokeColor(stroke.color.cgColor)

        context.beginPath()
        context.move(to: points[0])
        for point in points.dropFirst() {
            context.addLine(to: point)
        }
        context.strokePath()

        // Add highlight streak for glossy marker effect
        context.setLineWidth(stroke.lineWidth * 0.3)
        context.setAlpha(0.4)
        context.setStrokeColor(UIColor.white.cgColor)

        context.beginPath()
        let highlightOffset: CGFloat = -stroke.lineWidth * 0.25
        for (index, point) in points.enumerated() {
            let adjustedPoint = CGPoint(x: point.x + highlightOffset, y: point.y + highlightOffset)
            if index == 0 {
                context.move(to: adjustedPoint)
            } else {
                context.addLine(to: adjustedPoint)
            }
        }
        context.strokePath()
    }

    /// Draw a crayon stroke with waxy texture
    static func drawCrayonStroke(_ stroke: Stroke, in context: CGContext) {
        let points = stroke.smoothedPoints(granularity: 2)
        guard points.count > 1 else { return }

        // Draw multiple waxy layers with texture gaps (paper showing through)
        for layer in 0..<4 {
            let layerOffset = CGFloat(layer - 2) * stroke.lineWidth * 0.15

            context.setLineWidth(stroke.lineWidth * 0.9)
            context.setAlpha(0.4)
            context.setStrokeColor(stroke.color.cgColor)

            context.beginPath()
            for (index, point) in points.enumerated() {
                let noise1 = deterministicNoise(point.x, point.y, seed: layer * 100 + index)
                let noise2 = deterministicNoise(point.y, point.x, seed: layer * 200 + index)

                let waxyOffset = CGPoint(
                    x: (noise1 - 0.5) * stroke.lineWidth * 0.4 + layerOffset,
                    y: (noise2 - 0.5) * stroke.lineWidth * 0.4
                )

                let adjustedPoint = CGPoint(x: point.x + waxyOffset.x, y: point.y + waxyOffset.y)

                if index == 0 {
                    context.move(to: adjustedPoint)
                } else {
                    context.addLine(to: adjustedPoint)
                }
            }
            context.strokePath()
        }

        // Add waxy dots for that crayon texture
        for (index, point) in points.enumerated() where index % 2 == 0 {
            let noise = deterministicNoise(point.x * 2, point.y * 2, seed: index)

            // Only draw some dots (simulate paper texture showing through)
            if noise > 0.3 {
                let dotSize = stroke.lineWidth * (0.2 + noise * 0.3)
                let offsetX = (deterministicNoise(point.x, point.y, seed: index * 3) - 0.5) * stroke.lineWidth * 0.8
                let offsetY = (deterministicNoise(point.y, point.x, seed: index * 5) - 0.5) * stroke.lineWidth * 0.8

                let dotRect = CGRect(
                    x: point.x - dotSize / 2 + offsetX,
                    y: point.y - dotSize / 2 + offsetY,
                    width: dotSize,
                    height: dotSize
                )

                context.setFillColor(stroke.color.withAlphaComponent(0.5 + noise * 0.3).cgColor)
                context.fillEllipse(in: dotRect)
            }
        }
    }

    /// Draw a sparkle stroke with magical glitter effects
    static func drawSparkleStroke(_ stroke: Stroke, in context: CGContext, timeOffset: CFTimeInterval = 0) {
        let points = stroke.smoothedPoints(granularity: 3)
        guard points.count > 1 else { return }

        // Draw glowing base line
        context.setLineWidth(stroke.lineWidth * 1.5)
        context.setAlpha(0.3)
        context.setStrokeColor(stroke.color.cgColor)

        context.beginPath()
        context.move(to: points[0])
        for point in points.dropFirst() {
            context.addLine(to: point)
        }
        context.strokePath()

        // Core line with sparkle color
        context.setLineWidth(stroke.lineWidth * 0.6)
        context.setAlpha(0.9)
        context.setStrokeColor(stroke.color.cgColor)

        context.beginPath()
        context.move(to: points[0])
        for point in points.dropFirst() {
            context.addLine(to: point)
        }
        context.strokePath()

        // Add magical sparkles and stars along the path
        let rawPoints = stroke.points
        for (index, point) in rawPoints.enumerated() {
            let noise = deterministicNoise(point.position.x, point.position.y, seed: index)

            // Every point gets some sparkle effect
            if index % 3 == 0 {
                // Calculate twinkle animation for this star
                let twinklePhase = timeOffset * 3.0 + Double(index) * 0.5
                let twinkleValue = (sin(twinklePhase) + 1.0) / 2.0  // 0.0 to 1.0

                // Animated star size and alpha
                let baseStarSize = stroke.lineWidth * (0.5 + noise * 1.0)
                let animatedSize = baseStarSize * CGFloat(0.7 + twinkleValue * 0.6)
                let animatedAlpha = 0.6 + CGFloat(twinkleValue) * 0.4

                // Draw 4-point star sparkle with animation
                drawStar(at: point.position, size: animatedSize, color: UIColor.white.withAlphaComponent(animatedAlpha), in: context)

                // Add colored glow around star (also animated)
                let glowSize = animatedSize * 2.5
                let glowRect = CGRect(
                    x: point.position.x - glowSize / 2,
                    y: point.position.y - glowSize / 2,
                    width: glowSize,
                    height: glowSize
                )
                context.setFillColor(stroke.color.withAlphaComponent(0.15 + CGFloat(twinkleValue) * 0.15).cgColor)
                context.fillEllipse(in: glowRect)
            }

            // Scatter small glitter particles (also with subtle animation)
            if index % 2 == 0 {
                let scatterCount = 2 + Int(noise * 3)
                for scatter in 0..<scatterCount {
                    let scatterNoise1 = deterministicNoise(point.position.x, point.position.y, seed: index * 10 + scatter)
                    let scatterNoise2 = deterministicNoise(point.position.y, point.position.x, seed: index * 20 + scatter)

                    // Add subtle position jitter based on time for a shimmering effect
                    let jitterPhase = timeOffset * 2.0 + Double(scatter) * 0.7
                    let jitterX = sin(jitterPhase) * stroke.lineWidth * 0.1
                    let jitterY = cos(jitterPhase * 1.3) * stroke.lineWidth * 0.1

                    let offsetX = (scatterNoise1 - 0.5) * stroke.lineWidth * 2.5 + CGFloat(jitterX)
                    let offsetY = (scatterNoise2 - 0.5) * stroke.lineWidth * 2.5 + CGFloat(jitterY)

                    // Animate particle size
                    let particlePhase = timeOffset * 4.0 + Double(index + scatter) * 0.3
                    let particleTwinkle = (sin(particlePhase) + 1.0) / 2.0
                    let baseParticleSize = stroke.lineWidth * (0.1 + scatterNoise1 * 0.25)
                    let particleSize = baseParticleSize * CGFloat(0.8 + particleTwinkle * 0.4)

                    let particleRect = CGRect(
                        x: point.position.x + offsetX - particleSize / 2,
                        y: point.position.y + offsetY - particleSize / 2,
                        width: particleSize,
                        height: particleSize
                    )

                    // Alternate between white and colored particles with animated alpha
                    let particleColor = scatter % 2 == 0 ? UIColor.white : stroke.color
                    let particleAlpha = 0.5 + CGFloat(particleTwinkle) * 0.5
                    context.setFillColor(particleColor.withAlphaComponent(particleAlpha).cgColor)
                    context.fillEllipse(in: particleRect)
                }
            }
        }
    }

    /// Draw a rainbow stroke with animated hue cycling
    static func drawRainbowStroke(_ stroke: Stroke, in context: CGContext, timeOffset: CFTimeInterval = 0) {
        let points = stroke.smoothedPoints(granularity: 3)
        guard points.count > 1 else { return }

        // Calculate hue shift for animation (full cycle every ~3.3 seconds)
        let hueShift = CGFloat(fmod(timeOffset * 0.3, 1.0))

        // Draw outer glow for dreamy rainbow effect
        context.setLineWidth(stroke.lineWidth * 1.4)
        for i in 0..<points.count - 1 {
            let progress = CGFloat(i) / CGFloat(points.count)
            let baseHue = fmod(progress * 2.0, 1.0) // Cycle through colors twice
            let animatedHue = fmod(baseHue + hueShift, 1.0)
            let color = UIColor(hue: animatedHue, saturation: 0.8, brightness: 1.0, alpha: 0.25)

            context.setStrokeColor(color.cgColor)
            context.beginPath()
            context.move(to: points[i])
            context.addLine(to: points[i + 1])
            context.strokePath()
        }

        // Main rainbow stroke with vivid colors (animated)
        context.setLineWidth(stroke.lineWidth)
        for i in 0..<points.count - 1 {
            let progress = CGFloat(i) / CGFloat(points.count)
            let baseHue = fmod(progress * 2.0, 1.0)
            let animatedHue = fmod(baseHue + hueShift, 1.0)
            let color = UIColor(hue: animatedHue, saturation: 1.0, brightness: 1.0, alpha: 1.0)

            context.setStrokeColor(color.cgColor)
            context.beginPath()
            context.move(to: points[i])
            context.addLine(to: points[i + 1])
            context.strokePath()
        }

        // Add white highlight for glossy effect (slightly pulsing)
        let highlightPulse = 0.4 + sin(timeOffset * 2.0) * 0.1
        context.setLineWidth(stroke.lineWidth * 0.2)
        context.setStrokeColor(UIColor.white.withAlphaComponent(CGFloat(highlightPulse)).cgColor)

        context.beginPath()
        let highlightOffset: CGFloat = -stroke.lineWidth * 0.3
        for (index, point) in points.enumerated() {
            let adjustedPoint = CGPoint(x: point.x + highlightOffset, y: point.y + highlightOffset)
            if index == 0 {
                context.move(to: adjustedPoint)
            } else {
                context.addLine(to: adjustedPoint)
            }
        }
        context.strokePath()

        // Add occasional sparkle accents (animated)
        let rawPoints = stroke.points
        for (index, point) in rawPoints.enumerated() where index % 8 == 0 {
            let noise = deterministicNoise(point.position.x, point.position.y, seed: index)
            if noise > 0.5 {
                // Animate sparkle size and alpha
                let sparklePhase = timeOffset * 3.5 + Double(index) * 0.4
                let sparkleTwinkle = (sin(sparklePhase) + 1.0) / 2.0
                let baseSparkleSize = stroke.lineWidth * 0.4
                let sparkleSize = baseSparkleSize * CGFloat(0.6 + sparkleTwinkle * 0.8)
                let sparkleAlpha = 0.5 + CGFloat(sparkleTwinkle) * 0.5

                let sparkleRect = CGRect(
                    x: point.position.x - sparkleSize / 2,
                    y: point.position.y - sparkleSize / 2,
                    width: sparkleSize,
                    height: sparkleSize
                )
                context.setFillColor(UIColor.white.withAlphaComponent(sparkleAlpha).cgColor)
                context.fillEllipse(in: sparkleRect)
            }
        }
    }

    /// Draw a spray/airbrush stroke with scattered particles
    static func drawSprayStroke(_ stroke: Stroke, in context: CGContext) {
        let points = stroke.points
        guard points.count > 0 else { return }

        let color = stroke.color
        let radius = stroke.lineWidth / 2

        // For each point in the stroke, scatter particles
        for (index, point) in points.enumerated() {
            // Number of particles varies by brush size
            let particleCount = Int(stroke.lineWidth * 1.5)

            for p in 0..<particleCount {
                // Use deterministic noise for consistent rendering
                let noise1 = deterministicNoise(point.position.x, point.position.y, seed: index * 100 + p)
                let noise2 = deterministicNoise(point.position.y, point.position.x, seed: index * 200 + p)
                let noise3 = deterministicNoise(point.position.x + point.position.y, point.position.y - point.position.x, seed: index * 300 + p)

                // Random angle and distance from center (Gaussian-ish distribution)
                let angle = noise1 * .pi * 2
                let distanceFactor = noise2 * noise3  // Clusters toward center
                let distance = distanceFactor * radius

                let offsetX = cos(angle) * distance
                let offsetY = sin(angle) * distance

                // Particle size varies
                let particleSize = stroke.lineWidth * (0.03 + noise3 * 0.08)

                // Alpha falls off from center
                let centerDistance = distance / radius
                let alpha = max(0.2, 0.8 - centerDistance * 0.5)

                let particleRect = CGRect(
                    x: point.position.x + offsetX - particleSize / 2,
                    y: point.position.y + offsetY - particleSize / 2,
                    width: particleSize,
                    height: particleSize
                )

                context.setFillColor(color.withAlphaComponent(alpha).cgColor)
                context.fillEllipse(in: particleRect)
            }
        }
    }

    // MARK: - Helper Methods

    /// Draw a 4-point star at the given position
    static func drawStar(at center: CGPoint, size: CGFloat, color: UIColor, in context: CGContext) {
        context.saveGState()

        let outerRadius = size
        let innerRadius = size * 0.4

        context.setFillColor(color.cgColor)

        let path = CGMutablePath()
        let pointCount = 4

        for i in 0..<(pointCount * 2) {
            let radius = i % 2 == 0 ? outerRadius : innerRadius
            let angle = CGFloat(i) * .pi / CGFloat(pointCount) - .pi / 2

            let x = center.x + radius * cos(angle)
            let y = center.y + radius * sin(angle)

            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        path.closeSubpath()

        context.addPath(path)
        context.fillPath()

        context.restoreGState()
    }

    /// Deterministic pseudo-random noise based on position (consistent across redraws)
    static func deterministicNoise(_ x: CGFloat, _ y: CGFloat, seed: Int) -> CGFloat {
        let n = Int(x * 374761393 + y * 668265263 + CGFloat(seed) * 1013904223)
        let hash = (n ^ (n >> 13)) &* 1274126177
        return CGFloat(abs(hash) % 10000) / 10000.0
    }
}
