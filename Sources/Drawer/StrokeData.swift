import AppKit

struct StrokeData {
    var points: [NSPoint]
    var color: NSColor
    var width: CGFloat

    init(startPoint: NSPoint, color: NSColor, width: CGFloat) {
        self.points = [startPoint]
        self.color = color
        self.width = width
    }
}
