import AppKit

class TeleprompterOverlay: NSPanel {
    private let scrollView = NSScrollView()
    private let textView = NSTextView()
    private let backgroundView = NSView()
    private var autoScrollTimer: Timer?
    private(set) var currentFilePath: String?

    init() {
        super.init(
            contentRect: TeleprompterPreferences.overlayFrame,
            styleMask: [.nonactivatingPanel, .resizable, .titled, .closable],
            backing: .buffered,
            defer: false
        )
        level = .screenSaver
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isMovableByWindowBackground = true
        collectionBehavior = [.canJoinAllSpaces, .stationary]
        title = "Teleprompter"

        setupViews()
        applyPreferences()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowMoved(_:)),
            name: NSWindow.didMoveNotification,
            object: self
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillTerminate),
            name: NSApplication.willTerminateNotification,
            object: nil
        )
    }

    private func setupViews() {
        backgroundView.wantsLayer = true
        backgroundView.autoresizingMask = [.width, .height]

        scrollView.frame = contentView!.bounds
        scrollView.autoresizingMask = [.width, .height]
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false
        scrollView.backgroundColor = .clear

        textView.isEditable = false
        textView.isSelectable = false
        textView.drawsBackground = false
        textView.backgroundColor = .clear
        textView.textContainerInset = NSSize(width: 12, height: 12)
        textView.autoresizingMask = [.width]

        scrollView.documentView = textView

        contentView!.addSubview(backgroundView)
        contentView!.addSubview(scrollView)
    }

    func applyPreferences() {
        let prefFrame = TeleprompterPreferences.overlayFrame
        if frame != prefFrame {
            setFrame(prefFrame, display: true)
        }

        let color = TeleprompterPreferences.fontColor.withAlphaComponent(
            CGFloat(TeleprompterPreferences.textOpacity)
        )
        let font = NSFont.systemFont(ofSize: CGFloat(TeleprompterPreferences.fontSize))

        if let storage = textView.textStorage, storage.length > 0 {
            let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
            storage.addAttributes(attrs, range: NSRange(location: 0, length: storage.length))
        }
        textView.font = font
        textView.textColor = color

        let bgColor = NSColor(teleprompterHex: TeleprompterPreferences.backgroundColorHex) ?? .black
        let opacity = TeleprompterPreferences.backgroundOpacity
        backgroundView.layer?.backgroundColor = bgColor.withAlphaComponent(CGFloat(opacity)).cgColor
        backgroundView.frame = contentView!.bounds

        if TeleprompterPreferences.autoScroll {
            startAutoScroll()
        } else {
            stopAutoScroll()
        }
    }

    func loadFile(_ path: String) {
        currentFilePath = path
        guard let content = try? String(contentsOfFile: path, encoding: .utf8) else { return }

        let font = NSFont.systemFont(ofSize: CGFloat(TeleprompterPreferences.fontSize))
        let color = TeleprompterPreferences.fontColor.withAlphaComponent(
            CGFloat(TeleprompterPreferences.textOpacity)
        )
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        let attrStr = NSAttributedString(string: content, attributes: attrs)
        textView.textStorage?.setAttributedString(attrStr)
        textView.sizeToFit()

        let savedPosition = TeleprompterPreferences.scrollPosition(for: path)
        restoreScrollPosition(savedPosition)
    }

    private func restoreScrollPosition(_ position: Double) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let clipView = self.scrollView.contentView
            let docHeight = self.textView.frame.height
            let visibleHeight = clipView.bounds.height
            let maxScroll = max(0, docHeight - visibleHeight)
            let y = CGFloat(position) * maxScroll
            clipView.setBoundsOrigin(NSPoint(x: 0, y: y))
            self.scrollView.reflectScrolledClipView(clipView)
        }
    }

    private func currentScrollFraction() -> Double {
        let clipView = scrollView.contentView
        let docHeight = textView.frame.height
        let visibleHeight = clipView.bounds.height
        let maxScroll = max(0, docHeight - visibleHeight)
        guard maxScroll > 0 else { return 0 }
        return Double(clipView.bounds.origin.y / maxScroll)
    }

    private func saveCurrentScrollPosition() {
        guard let path = currentFilePath else { return }
        TeleprompterPreferences.saveScrollPosition(currentScrollFraction(), for: path)
    }

    func scrollUp() {
        let clipView = scrollView.contentView
        let newY = max(0, clipView.bounds.origin.y - 100)
        clipView.setBoundsOrigin(NSPoint(x: 0, y: newY))
        scrollView.reflectScrolledClipView(clipView)
        saveCurrentScrollPosition()
    }

    func scrollDown() {
        let clipView = scrollView.contentView
        let docHeight = textView.frame.height
        let maxScroll = max(0, docHeight - clipView.bounds.height)
        let newY = min(maxScroll, clipView.bounds.origin.y + 100)
        clipView.setBoundsOrigin(NSPoint(x: 0, y: newY))
        scrollView.reflectScrolledClipView(clipView)
        saveCurrentScrollPosition()
    }

    func toggleVisibility() {
        if isVisible {
            orderOut(nil)
        } else {
            makeKeyAndOrderFront(nil)
        }
    }

    func toggleAutoScroll() {
        TeleprompterPreferences.autoScroll = !TeleprompterPreferences.autoScroll
        if TeleprompterPreferences.autoScroll {
            startAutoScroll()
        } else {
            stopAutoScroll()
        }
    }

    func startAutoScroll() {
        stopAutoScroll()
        let speed = TeleprompterPreferences.autoScrollSpeed
        let fontSize = TeleprompterPreferences.fontSize
        let pixelsPerSecond = speed * fontSize * 0.6

        autoScrollTimer = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let clipView = self.scrollView.contentView
            let docHeight = self.textView.frame.height
            let maxScroll = max(0, docHeight - clipView.bounds.height)
            let currentY = clipView.bounds.origin.y
            if currentY >= maxScroll {
                self.stopAutoScroll()
                return
            }
            let newY = min(maxScroll, currentY + CGFloat(pixelsPerSecond / 30.0))
            clipView.setBoundsOrigin(NSPoint(x: 0, y: newY))
            self.scrollView.reflectScrolledClipView(clipView)
        }
        RunLoop.main.add(autoScrollTimer!, forMode: .common)
    }

    func stopAutoScroll() {
        autoScrollTimer?.invalidate()
        autoScrollTimer = nil
    }

    @objc private func windowMoved(_ notification: Notification) {
        TeleprompterPreferences.overlayFrame = frame
    }

    @objc private func appWillTerminate() {
        saveCurrentScrollPosition()
    }

    deinit {
        stopAutoScroll()
        NotificationCenter.default.removeObserver(self)
    }
}
