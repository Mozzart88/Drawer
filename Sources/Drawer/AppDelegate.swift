import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    var overlayWindow: OverlayWindow!
    var drawingView: DrawingView!
    var hotkeyManager: HotkeyManager!
    var colorWheelPanel: ColorWheelPanel!
    var statusItem: NSStatusItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        // Setup overlay
        overlayWindow = OverlayWindow()
        drawingView = DrawingView(frame: overlayWindow.contentView!.bounds)
        drawingView.autoresizingMask = [.width, .height]
        overlayWindow.contentView!.addSubview(drawingView)
        overlayWindow.makeKeyAndOrderFront(nil)

        // Color wheel
        colorWheelPanel = ColorWheelPanel(drawingView: drawingView)

        // Hotkeys
        hotkeyManager = HotkeyManager(
            toggleDrawing: { [weak self] in self?.toggleDrawing() },
            clearScreen: { [weak self] in self?.drawingView.clearStrokes() },
            toggleColorWheel: { [weak self] in self?.toggleColorWheel() }
        )

        // Status bar
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            let img = NSImage(systemSymbolName: "pencil.slash", accessibilityDescription: "Drawer")
            img?.isTemplate = true
            button.image = img
        }
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Toggle Drawing (F9)", action: #selector(toggleDrawing), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Clear (F10)", action: #selector(clearScreen), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Color Wheel (F8)", action: #selector(toggleColorWheel), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    @objc func toggleDrawing() {
        drawingView.isDrawingMode.toggle()
        overlayWindow.ignoresMouseEvents = !drawingView.isDrawingMode
        if let button = statusItem.button {
            let name = drawingView.isDrawingMode ? "pencil.tip" : "pencil.slash"
            let img = NSImage(systemSymbolName: name, accessibilityDescription: "Drawer")
            img?.isTemplate = true
            button.image = img
        }
    }

    @objc func clearScreen() {
        drawingView.clearStrokes()
    }

    @objc func toggleColorWheel() {
        if colorWheelPanel.isVisible {
            colorWheelPanel.orderOut(nil)
        } else {
            colorWheelPanel.makeKeyAndOrderFront(nil)
        }
    }
}
