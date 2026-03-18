import Testing
import AppKit
@testable import DrawerCore

@Suite("StrokeData")
struct StrokeDataTests {

    @Test("init creates single point and width")
    func initCreatesPointsAndWidths() {
        let start = NSPoint(x: 5, y: 10)
        let stroke = StrokeData(startPoint: start, startWidth: 3.0,
                                color: .red, baseWidth: 4.0, source: .mouse)
        #expect(stroke.points.count == 1)
        #expect(stroke.widths.count == 1)
        #expect(stroke.points[0] == start)
        #expect(stroke.widths[0] == 3.0)
    }

    @Test("append adds both point and width")
    func appendAddsBoth() {
        var stroke = StrokeData(startPoint: .zero, startWidth: 1.0,
                                color: .blue, baseWidth: 2.0, source: .pen)
        stroke.append(point: NSPoint(x: 10, y: 20), width: 5.0)
        stroke.append(point: NSPoint(x: 30, y: 40), width: 7.0)
        #expect(stroke.points.count == 3)
        #expect(stroke.widths.count == 3)
        #expect(stroke.points[1] == NSPoint(x: 10, y: 20))
        #expect(stroke.widths[2] == 7.0)
    }

    @Test("mouse source stored correctly")
    func mouseSource() {
        let stroke = StrokeData(startPoint: .zero, startWidth: 1.0,
                                color: .black, baseWidth: 1.0, source: .mouse)
        #expect(stroke.source == .mouse)
    }

    @Test("pen source stored correctly")
    func penSource() {
        let stroke = StrokeData(startPoint: .zero, startWidth: 1.0,
                                color: .black, baseWidth: 1.0, source: .pen)
        #expect(stroke.source == .pen)
    }

    @Test("color retained from init")
    func colorRetained() {
        let stroke = StrokeData(startPoint: .zero, startWidth: 1.0,
                                color: .green, baseWidth: 1.0, source: .mouse)
        #expect(stroke.color == .green)
    }

    @Test("baseWidth stored correctly")
    func baseWidthStored() {
        let stroke = StrokeData(startPoint: .zero, startWidth: 1.0,
                                color: .red, baseWidth: 6.5, source: .mouse)
        #expect(stroke.baseWidth == 6.5)
    }
}
