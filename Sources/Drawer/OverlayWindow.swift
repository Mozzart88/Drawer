import AppKit

class OverlayWindow: NSWindow {
    init() {
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let frame = screen.frame
        super.init(
            contentRect: frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        level = .screenSaver
        ignoresMouseEvents = true
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        isReleasedWhenClosed = false
        alphaValue = 1.0
    }

    override var canBecomeKey: Bool { false }

    private(set) var isGreenScreenOn = false

    func toggleGreenScreen() {
        isGreenScreenOn.toggle()
        backgroundColor = isGreenScreenOn ? GreenScreenPreferences.color : .clear
        isOpaque = isGreenScreenOn
    }

    func updateGreenScreenColor(_ color: NSColor) {
        GreenScreenPreferences.color = color
        if isGreenScreenOn {
            backgroundColor = color
        }
    }
}
