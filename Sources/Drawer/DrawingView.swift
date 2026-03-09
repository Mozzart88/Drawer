import AppKit

class DrawingView: NSView {
    var strokes: [StrokeData] = []
    var currentStroke: StrokeData?
    var currentColor: NSColor = .red
    var currentWidth: CGFloat = 4.0
    var currentOpacity: CGFloat = 1.0
    var onWidthChanged: ((CGFloat) -> Void)?
    var onOpacityChanged: ((CGFloat) -> Void)?
    var isDrawingMode: Bool = false {
        didSet {
            updateTrackingAreas()
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                if self.isDrawingMode {
                    NSCursor.crosshair.set()
                } else {
                    NSCursor.arrow.set()
                }
            }
        }
    }

    // For size indicator
    private var showingSizeIndicator: Bool = false
    private var sizeIndicatorTimer: Timer?

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = CGColor.clear
    }

    required init?(coder: NSCoder) { fatalError() }

    override var isFlipped: Bool { false }

    override func updateTrackingAreas() {
        trackingAreas.forEach { removeTrackingArea($0) }
        if isDrawingMode {
            addTrackingArea(NSTrackingArea(
                rect: bounds,
                options: [.cursorUpdate, .activeAlways, .inVisibleRect],
                owner: self,
                userInfo: nil
            ))
        }
        super.updateTrackingAreas()
    }

    override func cursorUpdate(with event: NSEvent) {
        if isDrawingMode { NSCursor.crosshair.set() }
    }

override func draw(_ dirtyRect: NSRect) {
        NSColor.clear.set()
        dirtyRect.fill()

        // Draw all completed strokes
        for stroke in strokes {
            drawStroke(stroke)
        }

        // Draw current in-progress stroke
        if let stroke = currentStroke {
            drawStroke(stroke)
        }

        // Draw size indicator if needed
        if showingSizeIndicator {
            drawSizeIndicator()
        }
    }

    private func drawStroke(_ stroke: StrokeData) {
        guard stroke.points.count >= 1 else { return }
        let path = BezierInterpolation.path(from: stroke.points)
        stroke.color.setStroke()
        path.lineWidth = stroke.width
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        path.stroke()
    }

    private func drawSizeIndicator() {
        let center = NSPoint(x: bounds.midX, y: bounds.midY)
        let radius = currentWidth / 2.0
        let rect = NSRect(
            x: center.x - radius,
            y: center.y - radius,
            width: currentWidth,
            height: currentWidth
        )
        let circle = NSBezierPath(ovalIn: rect)
        currentColor.withAlphaComponent(currentOpacity).setFill()
        circle.fill()
        NSColor.white.withAlphaComponent(0.6).setStroke()
        circle.lineWidth = 1
        circle.stroke()
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        currentStroke = StrokeData(startPoint: point, color: currentColor, width: currentWidth)
        setNeedsDisplay(bounds)
    }

    override func mouseDragged(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        currentStroke?.points.append(point)
        setNeedsDisplay(bounds)
    }

    override func mouseUp(with event: NSEvent) {
        if let stroke = currentStroke {
            strokes.append(stroke)
            currentStroke = nil
        }
        setNeedsDisplay(bounds)
    }

    override func scrollWheel(with event: NSEvent) {
        let delta = event.deltaY
        if event.modifierFlags.contains(.control) {
            currentOpacity = max(0.05, min(1.0, currentOpacity - delta * 0.02))
            onOpacityChanged?(currentOpacity)
        } else {
            currentWidth = max(1.0, min(40.0, currentWidth - delta))
            onWidthChanged?(currentWidth)
        }
        showSizeIndicator()
    }

    private func showSizeIndicator() {
        showingSizeIndicator = true
        sizeIndicatorTimer?.invalidate()
        sizeIndicatorTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { [weak self] _ in
            self?.showingSizeIndicator = false
            self?.setNeedsDisplay(self?.bounds ?? .zero)
        }
        setNeedsDisplay(bounds)
    }

    func clearStrokes() {
        strokes.removeAll()
        currentStroke = nil
        setNeedsDisplay(bounds)
    }
}
