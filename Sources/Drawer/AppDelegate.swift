import AppKit
import AVFoundation
import ScreenCaptureKit

class AppDelegate: NSObject, NSApplicationDelegate {
    var overlayWindow: OverlayWindow!
    var drawingView: DrawingView!
    var hotkeyManager: HotkeyManager!
    var colorPanelController: ColorPanelController!
    var statusItem: NSStatusItem!

    var recordingManager: RecordingManager!
    var presentationModeManager: PresentationModeManager!
    private var recordingControlPanel: RecordingControlPanel?
    private var recordingMenuItem: NSMenuItem!
    private var greenScreenMenuItem: NSMenuItem!
    private var tabletProximityMonitors: [Any] = []
    private var drawingAutoEnabledByTablet = false
    private var keyCastOverlay: KeyCastOverlay?
    private var keyCastMonitors: [Any] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        // Setup overlay
        overlayWindow = OverlayWindow()
        drawingView = DrawingView(frame: overlayWindow.contentView!.bounds)
        drawingView.autoresizingMask = [.width, .height]
        overlayWindow.contentView!.addSubview(drawingView)
        overlayWindow.makeKeyAndOrderFront(nil)

        // Tablet proximity
        drawingView.onTabletProximity = { [weak self] in self?.handleProximityEvent($0) }
        setupTabletProximityMonitor()

        // Color panel
        colorPanelController = ColorPanelController(drawingView: drawingView)

        // Recording
        recordingManager = RecordingManager()
        presentationModeManager = PresentationModeManager()
        recordingManager.onStateChanged = { [weak self] state in
            self?.updateStatusBarIcon()
            self?.updateRecordingMenuItem()
            if state == .recording {
                self?.startKeyCasting()
            } else {
                self?.stopKeyCasting()
                self?.presentationModeManager.disable()
            }
        }

        // Hotkeys
        hotkeyManager = HotkeyManager(
            toggleDrawing: { [weak self] in self?.toggleDrawing() },
            clearScreen: { [weak self] in self?.drawingView.clearStrokes() },
            toggleColorWheel: { [weak self] in self?.toggleColorWheel() },
            toggleRecording: { [weak self] in self?.toggleRecording() },
            toggleGreenScreen: { [weak self] in self?.toggleGreenScreen() }
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
        menu.addItem(NSMenuItem(title: "Color (F8)", action: #selector(toggleColorWheel), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        greenScreenMenuItem = NSMenuItem(title: "Green Screen (F5)", action: #selector(toggleGreenScreen), keyEquivalent: "")
        menu.addItem(greenScreenMenuItem)
        menu.addItem(NSMenuItem(title: "Green Screen Color…", action: #selector(showGreenScreenColor), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        recordingMenuItem = NSMenuItem(title: "Start Recording (F7)", action: #selector(toggleRecording), keyEquivalent: "")
        menu.addItem(recordingMenuItem)
        menu.addItem(NSMenuItem(title: "Recording Preferences…", action: #selector(showRecordingPreferences), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu

        // Request permissions at startup so the user can grant them before first use.
        requestPermissions()
    }

    private func requestPermissions() {
        // Screen recording — CGRequestScreenCaptureAccess triggers the system permission
        // dialog on first run. Actual content is fetched later when the recording panel opens.
        CGRequestScreenCaptureAccess()

        // Accessibility — required for global .keyDown monitoring (key casting).
        // Request always so the user can grant it before they start recording.
        if !AXIsProcessTrusted() {
            let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            AXIsProcessTrustedWithOptions(opts)
        }
    }

    @objc func toggleDrawing() {
        drawingAutoEnabledByTablet = false   // manual action overrides auto state
        drawingView.isDrawingMode ? disableDrawing() : enableDrawing()
    }

    private func enableDrawing() {
        drawingView.isDrawingMode = true
        overlayWindow.ignoresMouseEvents = false
        updateStatusBarIcon()
    }

    private func disableDrawing() {
        drawingView.isDrawingMode = false
        overlayWindow.ignoresMouseEvents = true
        updateStatusBarIcon()
    }

    private func setupTabletProximityMonitor() {
        let handler: (NSEvent) -> Void = { [weak self] event in
            DispatchQueue.main.async { self?.handleProximityEvent(event) }
        }
        // Global: fires when other apps are focused (pen hovers before drawing starts)
        if let m = NSEvent.addGlobalMonitorForEvents(matching: .tabletProximity, handler: handler) {
            tabletProximityMonitors.append(m)
        }
        // Local: fires when our app is focused (pen leaves while drawing is active)
        if let m = NSEvent.addLocalMonitorForEvents(matching: .tabletProximity, handler: { event in
            handler(event); return event
        }) {
            tabletProximityMonitors.append(m)
        }

    }

    private func handleProximityEvent(_ event: NSEvent) {
        // Don't filter by pointingDeviceType — Sidecar may report .unknown on leave events
        if event.isEnteringProximity {
            if !drawingView.isDrawingMode {
                drawingAutoEnabledByTablet = true
                enableDrawing()
            }
        } else if drawingAutoEnabledByTablet {
            drawingAutoEnabledByTablet = false
            disableDrawing()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        tabletProximityMonitors.forEach { NSEvent.removeMonitor($0) }
        stopKeyCasting()
    }

    // MARK: - Key Casting

    private func startKeyCasting() {
        guard RecordingPreferences.keyCastingEnabled else { return }

        // .keyDown global monitoring requires Accessibility permission.
        // .flagsChanged works without it, which is why modifiers highlight but keys don't appear.
        // The user was already prompted at startup; silently skip if they haven't granted it yet.
        guard AXIsProcessTrusted() else { return }

        let overlay = KeyCastOverlay()
        overlay.keyLifetime = RecordingPreferences.keyCastingLifetime
        overlay.keyFontSize = RecordingPreferences.keyCastingKeyFontSize
        overlay.modifierFontSize = RecordingPreferences.keyCastingModifierFontSize
        overlay.overlayBackgroundColor = RecordingPreferences.keyCastingBgColor
        overlay.overlayBackgroundOpacity = RecordingPreferences.keyCastingBgOpacity
        overlay.moveToSavedPosition()
        overlay.orderFront(nil)
        keyCastOverlay = overlay

        let handler: (NSEvent) -> Void = { [weak overlay] event in
            DispatchQueue.main.async {
                switch event.type {
                case .flagsChanged: overlay?.updateModifiers(event.modifierFlags)
                case .keyDown:
                    let (text, inline) = AppDelegate.keyDisplay(for: event)
                    overlay?.showKey(text, inline: inline)
                default: break
                }
            }
        }
        if let m = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown, .flagsChanged], handler: handler) {
            keyCastMonitors.append(m)
        }
        if let m = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged], handler: { event in
            handler(event); return event
        }) {
            keyCastMonitors.append(m)
        }
    }

    private func stopKeyCasting() {
        keyCastMonitors.forEach { NSEvent.removeMonitor($0) }
        keyCastMonitors.removeAll()
        keyCastOverlay?.orderOut(nil)
        keyCastOverlay = nil
    }

    /// Returns (display string, isInline).
    /// Inline = printable character that should be concatenated directly with neighbours.
    /// Non-inline = special key that gets space-separated from adjacent keys.
    private static func keyDisplay(for event: NSEvent) -> (String, Bool) {
        switch event.keyCode {
        case 49:  return ("⎵", false)
        case 36:  return ("↩", false)
        case 51:  return ("⌫", false)
        case 117: return ("⌦", false)
        case 53:  return ("<Esc>", false)
        case 48:  return ("⇥", false)
        case 126: return ("↑", false)
        case 125: return ("↓", false)
        case 123: return ("←", false)
        case 124: return ("→", false)
        case 115: return ("↖", false)
        case 119: return ("↘", false)
        case 116: return ("⇞", false)
        case 121: return ("⇟", false)
        case 122: return ("<F1>", false)
        case 120: return ("<F2>", false)
        case 99:  return ("<F3>", false)
        case 118: return ("<F4>", false)
        case 96:  return ("<F5>", false)
        case 97:  return ("<F6>", false)
        case 98:  return ("<F7>", false)
        case 100: return ("<F8>", false)
        case 101: return ("<F9>", false)
        case 109: return ("<F10>", false)
        case 103: return ("<F11>", false)
        case 111: return ("<F12>", false)
        default:
            let char = event.charactersIgnoringModifiers ?? "?"
            return (char, true)
        }
    }

    @objc func clearScreen() {
        drawingView.clearStrokes()
    }

    @objc func toggleColorWheel() {
        colorPanelController.toggle()
    }

    @objc func toggleGreenScreen() {
        overlayWindow.toggleGreenScreen()
        greenScreenMenuItem.title = overlayWindow.isGreenScreenOn
            ? "Green Screen On (F5)"
            : "Green Screen (F5)"
    }

    @objc func showGreenScreenColor() {
        let panel = NSColorPanel.shared
        panel.isContinuous = true
        panel.setTarget(self)
        panel.setAction(#selector(colorPanelDidChange(_:)))
        panel.showsAlpha = false
        panel.accessoryView = nil
        panel.color = GreenScreenPreferences.color
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    @objc private func colorPanelDidChange(_ sender: NSColorPanel) {
        overlayWindow.updateGreenScreenColor(sender.color)
    }

    @objc func toggleRecording() {
        if recordingManager.state == .recording {
            Task { await recordingManager.stopRecording() }
        } else if RecordingPreferences.hasPreferences {
            Task { await resumeRecording() }
        } else {
            showRecordingPanel()
        }
    }

    private func showRecordingPanel() {
        let panel = RecordingControlPanel()
        recordingControlPanel = panel
        panel.onRecord = { [weak self] filter, width, height, audioDevice, outputURL, presentationMode, sourceRect, virtualChromakey in
            guard let self = self else { return }
            if presentationMode { self.presentationModeManager.enable() }
            Task {
                do {
                    if virtualChromakey {
                        let screen = NSScreen.main ?? NSScreen.screens[0]
                        let scale = screen.backingScaleFactor
                        let vcWidth = (Int(screen.frame.width * scale) / 2) * 2
                        let vcHeight = (Int(screen.frame.height * scale) / 2) * 2
                        try await self.recordingManager.startVirtualChromakeyRecording(
                            width: vcWidth,
                            height: vcHeight,
                            audioDevice: audioDevice,
                            outputURL: outputURL,
                            drawingView: self.drawingView
                        )
                    } else {
                        try await self.recordingManager.startRecording(
                            filter: filter,
                            width: width,
                            height: height,
                            audioDevice: audioDevice,
                            outputURL: outputURL,
                            sourceRect: sourceRect
                        )
                    }
                } catch {
                    await MainActor.run {
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

    private func resumeRecording() async {
        let dir = RecordingPreferences.saveDirectory
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HH-mm-ss"
        let outputURL = dir.appendingPathComponent("Recording-\(formatter.string(from: Date())).mp4")

        let audioDevice: AVCaptureDevice? = RecordingPreferences.audioDeviceUID.flatMap { uid in
            let deviceTypes: [AVCaptureDevice.DeviceType]
            if #available(macOS 14.0, *) { deviceTypes = [.microphone] }
            else { deviceTypes = [.builtInMicrophone] }
            return AVCaptureDevice.DiscoverySession(
                deviceTypes: deviceTypes, mediaType: .audio, position: .unspecified
            ).devices.first(where: { $0.uniqueID == uid })
        }

        let presentationMode = RecordingPreferences.presentationMode
        let virtualChromakey = RecordingPreferences.virtualChromakeyEnabled

        do {
            await MainActor.run { if presentationMode { presentationModeManager.enable() } }

            if virtualChromakey {
                let (vcWidth, vcHeight): (Int, Int) = await MainActor.run {
                    let screen = NSScreen.main ?? NSScreen.screens[0]
                    let scale = screen.backingScaleFactor
                    return ((Int(screen.frame.width * scale) / 2) * 2,
                            (Int(screen.frame.height * scale) / 2) * 2)
                }
                try await recordingManager.startVirtualChromakeyRecording(
                    width: vcWidth,
                    height: vcHeight,
                    audioDevice: audioDevice,
                    outputURL: outputURL,
                    drawingView: drawingView
                )
            } else {
                let content = try await SCShareableContent.current
                let filter: SCContentFilter
                let width: Int
                let height: Int
                let sourceRect: CGRect?

                if RecordingPreferences.recordingMode == 0 {
                    guard let display = content.displays.first else { return }
                    filter = SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])
                    let screen = NSScreen.main ?? NSScreen.screens[0]
                    let scale = screen.backingScaleFactor
                    width = (Int(screen.frame.width * scale) / 2) * 2
                    height = (Int(screen.frame.height * scale) / 2) * 2
                    sourceRect = nil
                } else {
                    guard let scWindow = findSavedWindow(in: content.windows) else {
                        await MainActor.run { showRecordingPanel() }
                        return
                    }
                    guard let (wFilter, sRect) = makeWindowFilter(for: scWindow, content: content) else { return }
                    filter = wFilter
                    sourceRect = sRect
                    let scale = NSScreen.main?.backingScaleFactor ?? 2.0
                    width = max(2, (Int(scWindow.frame.width * scale) / 2) * 2)
                    height = max(2, (Int(scWindow.frame.height * scale) / 2) * 2)
                }

                try await recordingManager.startRecording(
                    filter: filter, width: width, height: height,
                    audioDevice: audioDevice, outputURL: outputURL, sourceRect: sourceRect
                )
            }
        } catch {
            await MainActor.run {
                presentationModeManager.disable()
                let alert = NSAlert()
                alert.messageText = "Recording failed"
                alert.informativeText = error.localizedDescription
                alert.runModal()
            }
        }
    }

    private func findSavedWindow(in windows: [SCWindow]) -> SCWindow? {
        guard let bundleID = RecordingPreferences.windowBundleID else { return nil }
        let candidates = windows.filter {
            $0.owningApplication?.bundleIdentifier == bundleID &&
            $0.isOnScreen && $0.windowLayer == 0 &&
            $0.frame.width > 50 && $0.frame.height > 50
        }
        if let title = RecordingPreferences.windowTitle {
            return candidates.first(where: { $0.title == title }) ?? candidates.first
        }
        return candidates.first
    }

    private func makeWindowFilter(for scWindow: SCWindow, content: SCShareableContent) -> (SCContentFilter, CGRect)? {
        guard let display = content.displays.first(where: { $0.frame.intersects(scWindow.frame) })
                  ?? content.displays.first else { return nil }
        let myBundleID = Bundle.main.bundleIdentifier ?? ""
        let overlayWindows = content.windows.filter {
            $0.owningApplication?.bundleIdentifier == myBundleID
        }
        let filter = SCContentFilter(display: display, including: [scWindow] + overlayWindows)
        let dispFrame = display.frame
        let winFrame = scWindow.frame
        let sourceRect = CGRect(
            x: winFrame.minX - dispFrame.minX,
            y: dispFrame.maxY - winFrame.maxY,
            width: winFrame.width,
            height: winFrame.height
        )
        return (filter, sourceRect)
    }

    @objc private func showRecordingPreferences() {
        showRecordingPanel()
    }

    private func updateStatusBarIcon() {
        guard let button = statusItem.button else { return }
        let name: String
        if recordingManager.state == .recording {
            name = recordingManager.isVirtualChromakey ? "camera.filters" : "record.circle.fill"
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
