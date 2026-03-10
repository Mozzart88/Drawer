import AppKit
import ScreenCaptureKit

class WindowPickerOverlay: NSWindow {

    var completion: ((SCWindow?) -> Void)?

    private var highlightView: HighlightOverlayView!
    private var availableWindows: [SCWindow] = []

    init(windows: [SCWindow]) {
        let screen = NSScreen.main ?? NSScreen.screens[0]
        super.init(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        availableWindows = windows
        backgroundColor = NSColor.black.withAlphaComponent(0.01)
        isOpaque = false
        hasShadow = false
        level = .popUpMenu
        collectionBehavior = [.canJoinAllSpaces, .stationary]
        acceptsMouseMovedEvents = true
        isReleasedWhenClosed = false

        highlightView = HighlightOverlayView(frame: contentView!.bounds)
        highlightView.autoresizingMask = [.width, .height]
        contentView!.addSubview(highlightView)

        let area = NSTrackingArea(
            rect: contentView!.bounds,
            options: [.mouseMoved, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        contentView!.addTrackingArea(area)
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func mouseMoved(with event: NSEvent) {
        updateHighlight(at: NSEvent.mouseLocation)
    }

    override func mouseDown(with event: NSEvent) {
        let match = findSCWindow(at: NSEvent.mouseLocation)
        completion?(match)
        close()
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Escape
            completion?(nil)
            close()
        }
    }

    // MARK: - Window detection

    private func updateHighlight(at screenPoint: NSPoint) {
        guard let info = topWindowInfo(at: screenPoint),
              let boundsDict = info[kCGWindowBounds as String] as? [String: CGFloat] else {
            highlightView.highlightFrame = .zero
            highlightView.setNeedsDisplay(highlightView.bounds)
            return
        }

        // CGWindowBounds use screen coordinates with top-left origin
        let cgBounds = CGRect(
            x: boundsDict["X"] ?? 0,
            y: boundsDict["Y"] ?? 0,
            width: boundsDict["Width"] ?? 0,
            height: boundsDict["Height"] ?? 0
        )

        // Convert to AppKit coordinates (bottom-left origin)
        if let screen = NSScreen.main {
            let flippedY = screen.frame.height - cgBounds.maxY
            let screenRect = NSRect(x: cgBounds.minX, y: flippedY, width: cgBounds.width, height: cgBounds.height)
            let localFrame = convertFromScreen(screenRect)
            highlightView.highlightFrame = localFrame
        }

        highlightView.setNeedsDisplay(highlightView.bounds)
    }

    private func topWindowInfo(at screenPoint: NSPoint) -> [String: Any]? {
        guard let windowList = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else { return nil }

        let myNumber = windowNumber
        // CGWindowListCopyWindowInfo returns windows front-to-back
        for info in windowList {
            guard let winNum = info[kCGWindowNumber as String] as? Int, winNum != myNumber,
                  let layer = info[kCGWindowLayer as String] as? Int, layer == 0,
                  let boundsDict = info[kCGWindowBounds as String] as? [String: CGFloat] else { continue }

            let cgBounds = CGRect(
                x: boundsDict["X"] ?? 0,
                y: boundsDict["Y"] ?? 0,
                width: boundsDict["Width"] ?? 0,
                height: boundsDict["Height"] ?? 0
            )

            // CGWindowBounds Y is from top-left; convert mouse point to same space
            let cgPoint = CGPoint(
                x: screenPoint.x,
                y: (NSScreen.main?.frame.height ?? 0) - screenPoint.y
            )

            if cgBounds.contains(cgPoint) {
                return info
            }
        }
        return nil
    }

    private func findSCWindow(at screenPoint: NSPoint) -> SCWindow? {
        guard let info = topWindowInfo(at: screenPoint),
              let windowID = info[kCGWindowNumber as String] as? Int else { return nil }
        return availableWindows.first { $0.windowID == CGWindowID(windowID) }
    }
}

// MARK: - Highlight view

class HighlightOverlayView: NSView {

    var highlightFrame: NSRect = .zero

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = CGColor.clear
    }

    required init?(coder: NSCoder) { fatalError() }

    override var isFlipped: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        guard highlightFrame != .zero else { return }
        let inset = highlightFrame.insetBy(dx: 2, dy: 2)
        let path = NSBezierPath(rect: inset)
        path.lineWidth = 4
        NSColor.systemBlue.withAlphaComponent(0.9).setStroke()
        path.stroke()
        NSColor.systemBlue.withAlphaComponent(0.12).setFill()
        path.fill()
    }
}
