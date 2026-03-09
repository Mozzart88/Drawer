import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    var overlayWindow: OverlayWindow!
    var drawingView: DrawingView!
    var hotkeyManager: HotkeyManager!
    var colorWheelPanel: ColorWheelPanel!
    var statusItem: NSStatusItem!

    var recordingManager: RecordingManager!
    var presentationModeManager: PresentationModeManager!
    private var recordingControlPanel: RecordingControlPanel?
    private var recordingMenuItem: NSMenuItem!

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

        // Recording
        recordingManager = RecordingManager()
        presentationModeManager = PresentationModeManager()
        recordingManager.onStateChanged = { [weak self] state in
            self?.updateStatusBarIcon()
            self?.updateRecordingMenuItem()
            if state == .idle {
                self?.presentationModeManager.disable()
            }
        }

        // Hotkeys
        hotkeyManager = HotkeyManager(
            toggleDrawing: { [weak self] in self?.toggleDrawing() },
            clearScreen: { [weak self] in self?.drawingView.clearStrokes() },
            toggleColorWheel: { [weak self] in self?.toggleColorWheel() },
            toggleRecording: { [weak self] in self?.toggleRecording() }
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
        recordingMenuItem = NSMenuItem(title: "Start Recording (F7)", action: #selector(toggleRecording), keyEquivalent: "")
        menu.addItem(recordingMenuItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    @objc func toggleDrawing() {
        drawingView.isDrawingMode.toggle()
        overlayWindow.ignoresMouseEvents = !drawingView.isDrawingMode
        updateStatusBarIcon()
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

    @objc func toggleRecording() {
        if recordingManager.state == .recording {
            Task { await recordingManager.stopRecording() }
        } else {
            showRecordingPanel()
        }
    }

    private func showRecordingPanel() {
        let panel = RecordingControlPanel()
        recordingControlPanel = panel
        panel.onRecord = { [weak self] filter, width, height, audioDevice, outputURL, presentationMode in
            guard let self = self else { return }
            if presentationMode { self.presentationModeManager.enable() }
            Task {
                do {
                    try await self.recordingManager.startRecording(
                        filter: filter,
                        width: width,
                        height: height,
                        audioDevice: audioDevice,
                        outputURL: outputURL
                    )
                } catch {
                    DispatchQueue.main.async {
                        self.presentationModeManager.disable()
                        let alert = NSAlert()
                        alert.messageText = "Recording failed"
                        alert.informativeText = error.localizedDescription
                        alert.runModal()
                    }
                }
            }
        }
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func updateStatusBarIcon() {
        guard let button = statusItem.button else { return }
        let name: String
        if recordingManager.state == .recording {
            name = "record.circle.fill"
        } else {
            name = drawingView.isDrawingMode ? "pencil.tip" : "pencil.slash"
        }
        let img = NSImage(systemSymbolName: name, accessibilityDescription: "Drawer")
        img?.isTemplate = recordingManager.state != .recording
        button.image = img
    }

    private func updateRecordingMenuItem() {
        let isRecording = recordingManager.state == .recording
        recordingMenuItem.title = isRecording ? "Stop Recording (F7)" : "Start Recording (F7)"
    }
}
