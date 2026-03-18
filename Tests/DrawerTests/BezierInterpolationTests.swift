import Testing
import AppKit
@testable import DrawerCore

@Suite("BezierInterpolation")
struct BezierInterpolationTests {

    @Test("empty points returns empty path")
    func emptyPoints() {
        let path = BezierInterpolation.path(from: [])
        #expect(path.elementCount == 0)
    }

    @Test("single point returns path with move only")
    func singlePoint() {
        let path = BezierInterpolation.path(from: [NSPoint(x: 10, y: 20)])
        #expect(path.elementCount == 1)
        var pt = NSPoint.zero
        let type = path.element(at: 0, associatedPoints: &pt)
        #expect(type == .moveTo)
        #expect(pt.x == 10)
        #expect(pt.y == 20)
    }

    @Test("two points returns straight line")
    func twoPoints() {
        let p1 = NSPoint(x: 0, y: 0)
        let p2 = NSPoint(x: 100, y: 100)
        let path = BezierInterpolation.path(from: [p1, p2])
        // move + line = 2 elements
        #expect(path.elementCount == 2)
        var pts = [NSPoint](repeating: .zero, count: 3)
        let type1 = path.element(at: 0, associatedPoints: &pts)
        #expect(type1 == .moveTo)
        let type2 = path.element(at: 1, associatedPoints: &pts)
        #expect(type2 == .lineTo)
    }

    @Test("three points returns smooth curve segments")
    func threePoints() {
        let pts = [NSPoint(x: 0, y: 0), NSPoint(x: 50, y: 100), NSPoint(x: 100, y: 0)]
        let path = BezierInterpolation.path(from: pts)
        // move + curve = 2 elements
        #expect(path.elementCount == 2)
        var associated = [NSPoint](repeating: .zero, count: 3)
        let type2 = path.element(at: 1, associatedPoints: &associated)
        #expect(type2 == .curveTo)
    }

    @Test("many points — all intermediate segments are curves")
    func manyPoints() {
        let input: [NSPoint] = (0..<10).map { NSPoint(x: Double($0) * 10, y: Double($0 % 3) * 20) }
        let path = BezierInterpolation.path(from: input)
        // move + (n-2) curves (one per interior segment) + possibly more
        // At minimum: move + (count-2) curve segments
        #expect(path.elementCount >= input.count - 1)
        // First element is move
        var pts = [NSPoint](repeating: .zero, count: 3)
        let first = path.element(at: 0, associatedPoints: &pts)
        #expect(first == .moveTo)
        // All subsequent elements should be curveTo
        for i in 1..<path.elementCount {
            let t = path.element(at: i, associatedPoints: &pts)
            #expect(t == .curveTo)
        }
    }

    @Test("control point weight uses 1/6 factor")
    func controlPointWeight() {
        let p0 = NSPoint(x: 0, y: 0)
        let p1 = NSPoint(x: 10, y: 0)
        let p2 = NSPoint(x: 20, y: 0)
        let p3 = NSPoint(x: 30, y: 0)
        // With 3 points, we get one curve segment from p1 to p2
        // cp1 = p1 + (p2 - p0) / 6 = (10 + (20-0)/6, 0) = (10 + 3.333, 0) = (13.333, 0)
        // cp2 = p2 - (p3 - p1) / 6 = (20 - (30-10)/6, 0) = (20 - 3.333, 0) = (16.667, 0)
        let path = BezierInterpolation.path(from: [p0, p1, p2, p3])
        var associated = [NSPoint](repeating: .zero, count: 3)
        // Element at index 1 is the first curve (p0→p1), element at index 2 is p1→p2
        let _ = path.element(at: 1, associatedPoints: &associated)
        // cp1 for p0→p1: p1 + (p2-p0)/6 = (10 + 20/6, 0) = (13.33, 0)
        #expect(abs(associated[0].x - (10.0 + 20.0/6.0)) < 0.01)
        #expect(abs(associated[0].y) < 0.01)
    }
}
