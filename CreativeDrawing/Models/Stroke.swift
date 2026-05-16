//
//  Stroke.swift
//  CreativeDrawing
//
//  A single drawing stroke made by the user
//

import UIKit
import simd

/// Represents a single point in a stroke with pressure and timestamp
struct StrokePoint {
    let position: CGPoint
    let pressure: CGFloat
    let timestamp: TimeInterval

    init(position: CGPoint, pressure: CGFloat = 1.0, timestamp: TimeInterval = Date().timeIntervalSince1970) {
        self.position = position
        self.pressure = pressure
        self.timestamp = timestamp
    }
}

/// Brush types available for kids
enum BrushType: String, CaseIterable {
    case pencil = "pencil"
    case marker = "marker"
    case crayon = "crayon"
    case sparkle = "sparkle"
    case rainbow = "rainbow"
    case spray = "spray"
    case eraser = "eraser"

    var displayName: String {
        switch self {
        case .pencil: return "Pencil"
        case .marker: return "Marker"
        case .crayon: return "Crayon"
        case .sparkle: return "Sparkle"
        case .rainbow: return "Rainbow"
        case .spray: return "Spray"
        case .eraser: return "Eraser"
        }
    }

    var icon: String {
        switch self {
        case .pencil: return "pencil"
        case .marker: return "paintbrush.pointed.fill"
        case .crayon: return "paintbrush.fill"
        case .sparkle: return "sparkles"
        case .rainbow: return "rainbow"
        case .spray: return "aqi.medium"
        case .eraser: return "eraser.fill"
        }
    }

    var baseWidth: CGFloat {
        switch self {
        case .pencil: return 4
        case .marker: return 12
        case .crayon: return 16
        case .sparkle: return 20
        case .rainbow: return 24
        case .spray: return 30
        case .eraser: return 40
        }
    }

    var opacity: CGFloat {
        switch self {
        case .pencil: return 1.0
        case .marker: return 0.8
        case .crayon: return 0.9
        case .sparkle: return 1.0
        case .rainbow: return 1.0
        case .spray: return 1.0
        case .eraser: return 1.0
        }
    }
}

/// A complete stroke with all its properties
class Stroke {
    let id: UUID
    var points: [StrokePoint]
    var color: UIColor
    var brushType: BrushType
    var lineWidth: CGFloat
    let createdAt: Date

    init(color: UIColor, brushType: BrushType, lineWidth: CGFloat? = nil) {
        self.id = UUID()
        self.points = []
        self.color = color
        self.brushType = brushType
        self.lineWidth = lineWidth ?? brushType.baseWidth
        self.createdAt = Date()
    }

    /// Initialize with existing ID (for deserialization)
    init(id: UUID, color: UIColor, brushType: BrushType, lineWidth: CGFloat? = nil) {
        self.id = id
        self.points = []
        self.color = color
        self.brushType = brushType
        self.lineWidth = lineWidth ?? brushType.baseWidth
        self.createdAt = Date()
    }

    func addPoint(_ point: StrokePoint) {
        points.append(point)
    }

    func addPoint(at position: CGPoint, pressure: CGFloat = 1.0) {
        let point = StrokePoint(position: position, pressure: pressure)
        points.append(point)
    }

    /// Returns smoothed points using Catmull-Rom spline interpolation
    func smoothedPoints(granularity: Int = 4) -> [CGPoint] {
        guard points.count > 2 else {
            return points.map { $0.position }
        }

        var smoothed: [CGPoint] = []
        let positions = points.map { $0.position }

        for i in 0..<(positions.count - 1) {
            let p0 = i > 0 ? positions[i - 1] : positions[i]
            let p1 = positions[i]
            let p2 = positions[i + 1]
            let p3 = i + 2 < positions.count ? positions[i + 2] : p2

            for j in 0..<granularity {
                let t = CGFloat(j) / CGFloat(granularity)
                let point = catmullRom(p0: p0, p1: p1, p2: p2, p3: p3, t: t)
                smoothed.append(point)
            }
        }

        if let last = positions.last {
            smoothed.append(last)
        }

        return smoothed
    }

    private func catmullRom(p0: CGPoint, p1: CGPoint, p2: CGPoint, p3: CGPoint, t: CGFloat) -> CGPoint {
        let t2 = t * t
        let t3 = t2 * t

        let x = 0.5 * ((2 * p1.x) +
                       (-p0.x + p2.x) * t +
                       (2 * p0.x - 5 * p1.x + 4 * p2.x - p3.x) * t2 +
                       (-p0.x + 3 * p1.x - 3 * p2.x + p3.x) * t3)

        let y = 0.5 * ((2 * p1.y) +
                       (-p0.y + p2.y) * t +
                       (2 * p0.y - 5 * p1.y + 4 * p2.y - p3.y) * t2 +
                       (-p0.y + 3 * p1.y - 3 * p2.y + p3.y) * t3)

        return CGPoint(x: x, y: y)
    }

    /// Calculate bounding box for the stroke
    var boundingBox: CGRect {
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

        let padding = lineWidth / 2
        return CGRect(
            x: minX - padding,
            y: minY - padding,
            width: maxX - minX + lineWidth,
            height: maxY - minY + lineWidth
        )
    }
}

/// Extension to get SIMD colors for Metal rendering
extension UIColor {
    var simdFloat4: SIMD4<Float> {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return SIMD4<Float>(Float(r), Float(g), Float(b), Float(a))
    }
}
