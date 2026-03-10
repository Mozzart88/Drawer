import AppKit
import AVFoundation
import ScreenCaptureKit

class RecordingControlPanel: NSPanel {

    // Called when user clicks Record — passes filter, pixel dimensions, audio device, output URL, presentation mode flag, sourceRect
    var onRecord: ((SCContentFilter, Int, Int, AVCaptureDevice?, URL, Bool, CGRect?) -> Void)?

    private var modeSegment: NSSegmentedControl!
    private var windowPicker: NSPopUpButton!
    private var audioSourcePicker: NSPopUpButton!
    private var outputPathField: NSTextField!
    private var presentationModeCheck: NSButton!
    private var recordButton: NSButton!
    private var statusLabel: NSTextField!

    private var shareableContent: SCShareableContent?
    private var audioDevices: [AVCaptureDevice] = []
    private var outputURL: URL
    private var windowPickerOverlay: WindowPickerOverlay?

    init() {
        let dir = RecordingPreferences.saveDirectory
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HH-mm-ss"
        outputURL = dir.appendingPathComponent("Recording-\(formatter.string(from: Date())).mp4")

        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 310),
            styleMask: [.titled, .closable, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        title = "Screen Recording"
        isFloatingPanel = true
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.floatingWindow)))
        hidesOnDeactivate = false
        isReleasedWhenClosed = false

        setupUI()
        center()
        loadContent()
    }

    // MARK: - UI Setup

    private func setupUI() {
        let content = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 310))
        contentView = content

        let lx: CGFloat = 10
        let lw: CGFloat = 90
        let cx: CGFloat = 108
        let cw: CGFloat = 282
        var y: CGFloat = 268
        let rh: CGFloat = 26
        let rs: CGFloat = 38

        // Mode
        content.addSubview(makeLabel("Mode", frame: NSRect(x: lx, y: y + 3, width: lw, height: 20)))
        modeSegment = NSSegmentedControl(frame: NSRect(x: cx, y: y, width: cw, height: rh))
        modeSegment.segmentCount = 2
        modeSegment.setLabel("Full Screen", forSegment: 0)
        modeSegment.setLabel("Window", forSegment: 1)
        modeSegment.selectedSegment = 0
        modeSegment.target = self
        modeSegment.action = #selector(modeChanged)
        content.addSubview(modeSegment)
        y -= rs

        // Window picker
        content.addSubview(makeLabel("Window", frame: NSRect(x: lx, y: y + 3, width: lw, height: 20)))
        windowPicker = NSPopUpButton(frame: NSRect(x: cx, y: y, width: cw, height: rh))
        windowPicker.addItem(withTitle: "Loading…")
        windowPicker.isEnabled = false
        content.addSubview(windowPicker)
        y -= rs

        // Audio source
        content.addSubview(makeLabel("Audio", frame: NSRect(x: lx, y: y + 3, width: lw, height: 20)))
        audioSourcePicker = NSPopUpButton(frame: NSRect(x: cx, y: y, width: cw, height: rh))
        audioSourcePicker.addItem(withTitle: "None")
        content.addSubview(audioSourcePicker)
        y -= rs

        // Output path
        content.addSubview(makeLabel("Save to", frame: NSRect(x: lx, y: y + 3, width: lw, height: 20)))
        outputPathField = NSTextField(frame: NSRect(x: cx, y: y, width: cw - 70, height: rh))
        outputPathField.stringValue = outputURL.path
        outputPathField.isEditable = false
        outputPathField.usesSingleLineMode = true
        outputPathField.lineBreakMode = .byTruncatingMiddle
        content.addSubview(outputPathField)
        let browseBtn = NSButton(frame: NSRect(x: cx + cw - 65, y: y, width: 62, height: rh))
        browseBtn.title = "Browse…"
        browseBtn.bezelStyle = .rounded
        browseBtn.target = self
        browseBtn.action = #selector(browse)
        content.addSubview(browseBtn)
        y -= rs

        // Presentation mode
        presentationModeCheck = NSButton(frame: NSRect(x: cx, y: y + 2, width: cw, height: 22))
        presentationModeCheck.setButtonType(.switch)
        presentationModeCheck.title = "Presentation Mode (DND + prevent sleep)"
        content.addSubview(presentationModeCheck)
        y -= rs - 4

        // Status label
        statusLabel = NSTextField(frame: NSRect(x: lx, y: y, width: 380, height: 18))
        statusLabel.isEditable = false
        statusLabel.isBezeled = false
        statusLabel.drawsBackground = false
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.font = .systemFont(ofSize: 11)
        statusLabel.stringValue = "Requesting screen recording permission…"
        content.addSubview(statusLabel)

        // Buttons
        let cancelBtn = NSButton(frame: NSRect(x: lx, y: 14, width: 80, height: 32))
        cancelBtn.title = "Cancel"
        cancelBtn.bezelStyle = .rounded
        cancelBtn.keyEquivalent = "\u{1B}"
        cancelBtn.target = self
        cancelBtn.action = #selector(cancel)
        content.addSubview(cancelBtn)

        recordButton = NSButton(frame: NSRect(x: 300, y: 14, width: 90, height: 32))
        recordButton.title = "Record"
        recordButton.bezelStyle = .rounded
        recordButton.keyEquivalent = "\r"
        recordButton.isEnabled = false
        recordButton.target = self
        recordButton.action = #selector(startRecording)
        content.addSubview(recordButton)
    }

    private func makeLabel(_ text: String, frame: NSRect) -> NSTextField {
        let tf = NSTextField(labelWithString: text)
        tf.frame = frame
        tf.alignment = .right
        return tf
    }

    // MARK: - Content loading

    private func loadContent() {
        // Audio devices (synchronous)
        let deviceTypes: [AVCaptureDevice.DeviceType]
        if #available(macOS 14.0, *) {
            deviceTypes = [.microphone]
        } else {
            deviceTypes = [.builtInMicrophone]
        }
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: deviceTypes,
            mediaType: .audio,
            position: .unspecified
        )
        audioDevices = discoverySession.devices
        audioSourcePicker.removeAllItems()
        audioSourcePicker.addItem(withTitle: "None")
        for device in audioDevices {
            audioSourcePicker.addItem(withTitle: device.localizedName)
        }

        // Restore saved audio device selection
        if let savedUID = RecordingPreferences.audioDeviceUID,
           let idx = audioDevices.firstIndex(where: { $0.uniqueID == savedUID }) {
            audioSourcePicker.selectItem(at: idx + 1) // +1 for leading "None" item
        }

        // Restore presentation mode checkbox
        presentationModeCheck.state = RecordingPreferences.presentationMode ? .on : .off

        // Shareable content (async — requires screen recording permission)
        Task {
            do {
                let content = try await SCShareableContent.current
                await MainActor.run {
                    self.shareableContent = content
                    self.populateWindowPicker(windows: content.windows)
                    self.recordButton.isEnabled = true
                }
            } catch {
                await MainActor.run {
                    self.statusLabel.stringValue = "Screen recording permission required in System Settings."
                    self.statusLabel.textColor = .systemRed
                }
            }
        }
    }

    private func populateWindowPicker(windows: [SCWindow]) {
        // Keep only normal on-screen windows belonging to a real app
        let visible = windows.filter {
            $0.isOnScreen &&
            $0.windowLayer == 0 &&
            $0.owningApplication != nil &&
            $0.frame.width > 50 &&
            $0.frame.height > 50
        }

        let appWindows = visible.sorted {
            let a0 = $0.owningApplication!.applicationName
            let a1 = $1.owningApplication!.applicationName
            let cmp = a0.localizedCaseInsensitiveCompare(a1)
            if cmp != .orderedSame { return cmp == .orderedAscending }
            let t0 = $0.title ?? ""
            let t1 = $1.title ?? ""
            return t0.localizedCaseInsensitiveCompare(t1) == .orderedAscending
        }

        windowPicker.removeAllItems()
        windowPicker.addItem(withTitle: "Click to pick…")
        for window in appWindows {
            let appName = window.owningApplication!.applicationName
            let winTitle = window.title.flatMap { $0.isEmpty ? nil : $0 } ?? appName
            let label = winTitle == appName ? appName : "\(appName) — \(winTitle)"
            windowPicker.addItem(withTitle: label)
            windowPicker.lastItem?.representedObject = window
        }
        windowPicker.isEnabled = modeSegment.selectedSegment == 1
        statusLabel.stringValue = "Ready. \(appWindows.count) windows available."
    }

    // MARK: - Actions

    @objc private func modeChanged() {
        windowPicker.isEnabled = modeSegment.selectedSegment == 1
    }

    @objc private func browse() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.mpeg4Movie]
        panel.nameFieldStringValue = URL(fileURLWithPath: outputPathField.stringValue).lastPathComponent
        panel.begin { [weak self] response in
            guard let self = self, response == .OK, let url = panel.url else { return }
            self.outputURL = url
            self.outputPathField.stringValue = url.path
            RecordingPreferences.saveDirectory = url.deletingLastPathComponent()
        }
    }

    @objc private func cancel() {
        orderOut(nil)
    }

    @objc private func startRecording() {
        guard let content = shareableContent else { return }

        let isPresentationMode = presentationModeCheck.state == .on
        let audioIndex = audioSourcePicker.indexOfSelectedItem - 1 // 0 = "None"
        let audioDevice: AVCaptureDevice? = audioIndex >= 0 && audioIndex < audioDevices.count
            ? audioDevices[audioIndex] : nil

        // Window mode + click-to-pick
        if modeSegment.selectedSegment == 1 && windowPicker.indexOfSelectedItem == 0 {
            orderOut(nil)
            showWindowPicker(
                windows: content.windows,
                audioDevice: audioDevice,
                presentationMode: isPresentationMode
            )
            return
        }

        let filter: SCContentFilter
        let width: Int
        let height: Int

        let sourceRect: CGRect?

        if modeSegment.selectedSegment == 0 {
            // Full screen — use NSScreen physical pixels (SCDisplay.width is in logical points)
            guard let display = content.displays.first else { return }
            filter = SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])
            let screen = NSScreen.main ?? NSScreen.screens[0]
            let scale = screen.backingScaleFactor
            width = (Int(screen.frame.width * scale) / 2) * 2
            height = (Int(screen.frame.height * scale) / 2) * 2
            sourceRect = nil
        } else {
            // Selected window — scWindow.frame is in points, convert to pixels
            guard let scWindow = selectedSCWindow() else {
                statusLabel.stringValue = "Please select a window."
                return
            }
            guard let (wFilter, sRect) = makeWindowFilter(for: scWindow) else { return }
            filter = wFilter
            sourceRect = sRect
            let scale = NSScreen.main?.backingScaleFactor ?? 2.0
            width = max(2, (Int(scWindow.frame.width * scale) / 2) * 2)
            height = max(2, (Int(scWindow.frame.height * scale) / 2) * 2)
            RecordingPreferences.windowBundleID = scWindow.owningApplication?.bundleIdentifier
            RecordingPreferences.windowTitle = scWindow.title
        }

        RecordingPreferences.recordingMode = modeSegment.selectedSegment
        RecordingPreferences.presentationMode = presentationModeCheck.state == .on
        RecordingPreferences.audioDeviceUID = audioDevice?.uniqueID
        RecordingPreferences.saveDirectory = outputURL.deletingLastPathComponent()

        orderOut(nil)
        onRecord?(filter, width, height, audioDevice, outputURL, isPresentationMode, sourceRect)
    }

    private func makeWindowFilter(for scWindow: SCWindow) -> (SCContentFilter, CGRect)? {
        guard let content = shareableContent,
              let display = content.displays.first(where: { $0.frame.intersects(scWindow.frame) })
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

    private func selectedSCWindow() -> SCWindow? {
        let idx = windowPicker.indexOfSelectedItem
        guard idx > 0 else { return nil }
        return windowPicker.item(at: idx)?.representedObject as? SCWindow
    }

    private func showWindowPicker(windows: [SCWindow], audioDevice: AVCaptureDevice?, presentationMode: Bool) {
        let overlay = WindowPickerOverlay(windows: windows)
        windowPickerOverlay = overlay
        overlay.completion = { [weak self] scWindow in
            DispatchQueue.main.async {
                self?.windowPickerOverlay = nil
                guard let scWindow = scWindow else {
                    self?.makeKeyAndOrderFront(nil)
                    return
                }
                guard let (wFilter, sRect) = self?.makeWindowFilter(for: scWindow) else { return }
                let scale = NSScreen.main?.backingScaleFactor ?? 2.0
                let width = max(2, (Int(scWindow.frame.width * scale) / 2) * 2)
                let height = max(2, (Int(scWindow.frame.height * scale) / 2) * 2)
                RecordingPreferences.windowBundleID = scWindow.owningApplication?.bundleIdentifier
                RecordingPreferences.windowTitle = scWindow.title
                self?.onRecord?(wFilter, width, height, audioDevice, self?.outputURL ?? URL(fileURLWithPath: ""), presentationMode, sRect)
            }
        }
        overlay.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
