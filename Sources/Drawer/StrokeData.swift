import AppKit

struct StrokeData {
    enum InputSource { case mouse, pen }

    var points:    [NSPoint]
    var widths:    [CGFloat]   // same count as points
    var color:     NSColor
    var baseWidth: CGFloat
    var source:    InputSource

    init(startPoint: NSPoint, startWidth: CGFloat, color: NSColor,
         baseWidth: CGFloat, source: InputSource) {
        self.points    = [startPoint]
        self.widths    = [startWidth]
        self.color     = color
        self.baseWidth = baseWidth
        self.source    = source
    }

    mutating func append(point: NSPoint, width: CGFloat) {
        points.append(point)
        widths.append(width)
    }
}
