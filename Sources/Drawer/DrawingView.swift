import AppKit

class DrawingView: NSView {
    var strokes: [StrokeData] = []
    var currentStroke: StrokeData?
    private var undoStack: [[StrokeData]] = []
    private var redoStack: [[StrokeData]] = []
    private let maxUndoSteps = 100
    var currentColor: NSColor = .red {
        didSet {
            StrokeSettings.save(color: currentColor, opacity: currentOpacity, width: currentWidth)
            colorObservers.forEach { $0(currentColor) }
        }
    }
    var currentWidth: CGFloat = 4.0 {
        didSet { StrokeSettings.save(color: currentColor, opacity: currentOpacity, width: currentWidth) }
    }
    var currentOpacity: CGFloat = 1.0 {
        didSet { StrokeSettings.save(color: currentColor, opacity: currentOpacity, width: currentWidth) }
    }
    private var widthObservers:   [(CGFloat) -> Void] = []
    private var opacityObservers: [(CGFloat) -> Void] = []
    private var colorObservers:   [(NSColor) -> Void] = []

    var onWidthChanged:   ((CGFloat) -> Void)? { get { nil } set { if let f = newValue { widthObservers.append(f) } } }
    var onOpacityChanged: ((CGFloat) -> Void)? { get { nil } set { if let f = newValue { opacityObservers.append(f) } } }
    var onColorChanged:   ((NSColor) -> Void)? { get { nil } set { if let f = newValue { colorObservers.append(f) } } }
    var onTabletProximity: ((NSEvent) -> Void)?
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
        let s = StrokeSettings.load()
        currentColor   = s.color
        currentWidth   = s.width
        currentOpacity = s.opacity
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = CGColor.clear
    }

    required init?(coder: NSCoder) { fatalError() }

    override var isFlipped: Bool { false }
    override var acceptsFirstResponder: Bool { true }

    private var touchBarController: TouchBarController?

    override func makeTouchBar() -> NSTouchBar? {
        let c = TouchBarController(drawingView: self)
        touchBarController = c
        return c.makeTouchBar()
    }

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

    override func tabletProximity(with event: NSEvent) {
        onTabletProximity?(event)
        super.tabletProximity(with: event)
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.clear.set()
        dirtyRect.fill()

        for stroke in strokes {
            drawStroke(stroke)
        }

        if let stroke = currentStroke {
            drawStroke(stroke)
        }

        if showingSizeIndicator {
            drawSizeIndicator()
        }
    }

    private func drawStroke(_ stroke: StrokeData) {
        guard stroke.points.count >= 1 else { return }
        switch stroke.source {
        case .pen:   drawVariableWidthStroke(stroke)
        case .mouse: drawUniformStroke(stroke)
        }
    }

    private func drawUniformStroke(_ stroke: StrokeData) {
        let path = BezierInterpolation.path(from: stroke.points)
        stroke.color.setStroke()
        path.lineWidth = stroke.widths.first ?? stroke.baseWidth
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        path.stroke()
    }

    private func drawVariableWidthStroke(_ stroke: StrokeData) {
        let pts = stroke.points
        let wids = stroke.widths

        // Single point: draw a filled circle
        if pts.count == 1 {
            let r = wids[0] / 2.0
            let rect = NSRect(x: pts[0].x - r, y: pts[0].y - r, width: wids[0], height: wids[0])
            let circle = NSBezierPath(ovalIn: rect)
            stroke.color.setFill()
            circle.fill()
            return
        }

        // Build left/right edge arrays for variable-width outline
        var leftPts: [NSPoint] = []
        var rightPts: [NSPoint] = []

        for i in 0..<pts.count {
            let p = pts[i]
            let r = wids[i] / 2.0

            // Direction vector along stroke at this point
            let dir: NSPoint
            if i == 0 {
                dir = normalize(dx: pts[1].x - pts[0].x, dy: pts[1].y - pts[0].y)
            } else if i == pts.count - 1 {
                dir = normalize(dx: pts[i].x - pts[i-1].x, dy: pts[i].y - pts[i-1].y)
            } else {
                let d1 = normalize(dx: pts[i].x - pts[i-1].x, dy: pts[i].y - pts[i-1].y)
                let d2 = normalize(dx: pts[i+1].x - pts[i].x, dy: pts[i+1].y - pts[i].y)
                dir = normalize(dx: d1.x + d2.x, dy: d1.y + d2.y)
            }

            // Perpendicular offset
            let perp = NSPoint(x: -dir.y, y: dir.x)
            leftPts.append(NSPoint(x: p.x + perp.x * r, y: p.y + perp.y * r))
            rightPts.append(NSPoint(x: p.x - perp.x * r, y: p.y - perp.y * r))
        }

        // Build closed polygon: left edge forward, right edge backward
        let outline = NSBezierPath()
        outline.move(to: leftPts[0])
        for pt in leftPts.dropFirst() { outline.line(to: pt) }
        for pt in rightPts.reversed() { outline.line(to: pt) }
        outline.close()

        stroke.color.setFill()
        outline.fill()
    }

    private func normalize(dx: CGFloat, dy: CGFloat) -> NSPoint {
        let len = sqrt(dx * dx + dy * dy)
        guard len > 0 else { return NSPoint(x: 1, y: 0) }
        return NSPoint(x: dx / len, y: dy / len)
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
        let isPen = TabletInput.isPenEvent(event)
        let color = currentColor.withAlphaComponent(currentOpacity)
        let startWidth = isPen
            ? TabletInput.pointWidth(for: event, baseWidth: currentWidth)
            : currentWidth
        currentStroke = StrokeData(
            startPoint: point,
            startWidth: startWidth,
            color: color,
            baseWidth: currentWidth,
            source: isPen ? .pen : .mouse
        )
        setNeedsDisplay(bounds)
    }

    override func mouseDragged(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let width: CGFloat
        if let stroke = currentStroke, stroke.source == .pen {
            width = TabletInput.pointWidth(for: event, baseWidth: stroke.baseWidth)
        } else {
            width = currentWidth
        }
        currentStroke?.append(point: point, width: width)
        setNeedsDisplay(bounds)
    }

    private func saveUndoPoint() {
        undoStack.append(strokes)
        redoStack.removeAll()
        if undoStack.count > maxUndoSteps { undoStack.removeFirst() }
    }

    func undo() {
        guard !undoStack.isEmpty else { return }
        redoStack.append(strokes)
        strokes = undoStack.removeLast()
        setNeedsDisplay(bounds)
    }

    func redo() {
        guard !redoStack.isEmpty else { return }
        undoStack.append(strokes)
        strokes = redoStack.removeLast()
        setNeedsDisplay(bounds)
    }

    override func mouseUp(with event: NSEvent) {
        if let stroke = currentStroke {
            saveUndoPoint()
            strokes.append(stroke)
            currentStroke = nil
        }
        setNeedsDisplay(bounds)
    }

    override func scrollWheel(with event: NSEvent) {
        let delta = event.deltaY
        if event.modifierFlags.contains(.control) {
            currentOpacity = max(0.05, min(1.0, currentOpacity - delta * 0.02))
            opacityObservers.forEach { $0(currentOpacity) }
        } else {
            currentWidth = max(1.0, min(40.0, currentWidth - delta))
            widthObservers.forEach { $0(currentWidth) }
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
        saveUndoPoint()
        strokes.removeAll()
        currentStroke = nil
        setNeedsDisplay(bounds)
    }

    var allStrokes: [StrokeData] {
        var result = strokes
        if let s = currentStroke { result.append(s) }
        return result
    }

    func render(into cgContext: CGContext) {
        let nsCtx = NSGraphicsContext(cgContext: cgContext, flipped: false)
        let previous = NSGraphicsContext.current
        NSGraphicsContext.current = nsCtx
        defer { NSGraphicsContext.current = previous }
        for stroke in allStrokes { drawStroke(stroke) }
    }
}
