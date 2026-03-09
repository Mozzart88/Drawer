import AppKit

struct BezierInterpolation {
    /// Build a full NSBezierPath from a stroke's points using Catmull-Rom interpolation
    static func path(from points: [NSPoint]) -> NSBezierPath {
        let path = NSBezierPath()
        guard points.count >= 2 else {
            if let first = points.first {
                path.move(to: first)
            }
            return path
        }

        path.move(to: points[0])

        if points.count == 2 {
            path.line(to: points[1])
            return path
        }

        for i in 1..<points.count - 1 {
            let p0 = points[max(i - 1, 0)]
            let p1 = points[i]
            let p2 = points[i + 1]
            let p3 = points[min(i + 2, points.count - 1)]

            let cp1 = NSPoint(
                x: p1.x + (p2.x - p0.x) / 6.0,
                y: p1.y + (p2.y - p0.y) / 6.0
            )
            let cp2 = NSPoint(
                x: p2.x - (p3.x - p1.x) / 6.0,
                y: p2.y - (p3.y - p1.y) / 6.0
            )
            path.curve(to: p2, controlPoint1: cp1, controlPoint2: cp2)
        }
        return path
    }
}
