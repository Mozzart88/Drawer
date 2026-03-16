import AppKit

class TeleprompterOverlay: NSPanel {
    private let scrollView = NSScrollView()
    private let textView = NSTextView()
    private let backgroundView = NSView()
    private var autoScrollTimer: Timer?
    private(set) var currentFilePath: String?
    private var cachedContent: String?
    private var drawingModeActive = false
    private var ctrlCmdHeld = false
    private var modifierMonitors: [Any] = []

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
        ignoresMouseEvents = true

        setupViews()
        applyPreferences()
        setupModifierMonitors()

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

        // Re-render text with new preferences
        if let content = cachedContent, let path = currentFilePath {
            updateTextView(content: content, filePath: path)
            textView.sizeToFit()
        }

        let bgColor = NSColor(teleprompterHex: TeleprompterPreferences.backgroundColorHex) ?? .black
        backgroundView.layer?.backgroundColor = bgColor.withAlphaComponent(
            CGFloat(TeleprompterPreferences.backgroundOpacity)
        ).cgColor
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
        cachedContent = content
        updateTextView(content: content, filePath: path)
        textView.sizeToFit()
        restoreScrollPosition(TeleprompterPreferences.scrollPosition(for: path))
    }

    private func updateTextView(content: String, filePath: String) {
        let font = NSFont.systemFont(ofSize: CGFloat(TeleprompterPreferences.fontSize))
        let color = TeleprompterPreferences.fontColor.withAlphaComponent(
            CGFloat(TeleprompterPreferences.textOpacity)
        )
        let isMarkdown = filePath.hasSuffix(".md") || filePath.hasSuffix(".markdown")
        let attrStr = isMarkdown
            ? renderMarkdown(content, baseFont: font, color: color)
            : NSAttributedString(string: content, attributes: [.font: font, .foregroundColor: color])
        textView.textStorage?.setAttributedString(attrStr)
    }

    // MARK: - Scroll helpers

    private func restoreScrollPosition(_ position: Double) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let clipView = self.scrollView.contentView
            let maxScroll = max(0, self.textView.frame.height - clipView.bounds.height)
            clipView.setBoundsOrigin(NSPoint(x: 0, y: CGFloat(position) * maxScroll))
            self.scrollView.reflectScrolledClipView(clipView)
        }
    }

    private func currentScrollFraction() -> Double {
        let clipView = scrollView.contentView
        let maxScroll = max(0, textView.frame.height - clipView.bounds.height)
        guard maxScroll > 0 else { return 0 }
        return Double(clipView.bounds.origin.y / maxScroll)
    }

    private func saveCurrentScrollPosition() {
        guard let path = currentFilePath else { return }
        TeleprompterPreferences.saveScrollPosition(currentScrollFraction(), for: path)
    }

    func scrollUp() {
        let clipView = scrollView.contentView
        clipView.setBoundsOrigin(NSPoint(x: 0, y: max(0, clipView.bounds.origin.y - 100)))
        scrollView.reflectScrolledClipView(clipView)
        saveCurrentScrollPosition()
    }

    func scrollDown() {
        let clipView = scrollView.contentView
        let maxScroll = max(0, textView.frame.height - clipView.bounds.height)
        clipView.setBoundsOrigin(NSPoint(x: 0, y: min(maxScroll, clipView.bounds.origin.y + 100)))
        scrollView.reflectScrolledClipView(clipView)
        saveCurrentScrollPosition()
    }

    private func setupModifierMonitors() {
        let handler: (NSEvent) -> Void = { [weak self] event in
            guard let self = self else { return }
            let flags = event.modifierFlags
            let held = flags.contains(.control) && flags.contains(.command)
            guard held != self.ctrlCmdHeld else { return }
            self.ctrlCmdHeld = held
            self.updateMouseEventHandling()
        }
        if let m = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged, handler: handler) {
            modifierMonitors.append(m)
        }
        if let m = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged, handler: { event in
            handler(event); return event
        }) {
            modifierMonitors.append(m)
        }
    }

    private func updateMouseEventHandling() {
        let interact = ctrlCmdHeld && !drawingModeActive
        ignoresMouseEvents = !interact
        textView.isSelectable = interact
    }

    func setDrawingMode(_ active: Bool) {
        drawingModeActive = active
        updateMouseEventHandling()
    }

    func toggleVisibility() {
        isVisible ? orderOut(nil) : makeKeyAndOrderFront(nil)
    }

    func toggleAutoScroll() {
        TeleprompterPreferences.autoScroll = !TeleprompterPreferences.autoScroll
        TeleprompterPreferences.autoScroll ? startAutoScroll() : stopAutoScroll()
    }

    func startAutoScroll() {
        stopAutoScroll()
        let pixelsPerSecond = TeleprompterPreferences.autoScrollSpeed * TeleprompterPreferences.fontSize * 0.6
        autoScrollTimer = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let clipView = self.scrollView.contentView
            let maxScroll = max(0, self.textView.frame.height - clipView.bounds.height)
            let currentY = clipView.bounds.origin.y
            if currentY >= maxScroll { self.stopAutoScroll(); return }
            clipView.setBoundsOrigin(NSPoint(x: 0, y: min(maxScroll, currentY + CGFloat(pixelsPerSecond / 30.0))))
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
        modifierMonitors.forEach { NSEvent.removeMonitor($0) }
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - Markdown renderer

private extension TeleprompterOverlay {

    func renderMarkdown(_ text: String, baseFont: NSFont, color: NSColor) -> NSAttributedString {
        let result = NSMutableAttributedString()
        // Normalize line endings
        let lines = text.replacingOccurrences(of: "\r\n", with: "\n")
                        .replacingOccurrences(of: "\r", with: "\n")
                        .components(separatedBy: "\n")
        var i = 0

        while i < lines.count {
            let line = lines[i]

            // ── Fenced code block ────────────────────────────────────────────
            if line.hasPrefix("```") {
                i += 1
                var codeLines: [String] = []
                while i < lines.count && !lines[i].hasPrefix("```") {
                    codeLines.append(lines[i])
                    i += 1
                }
                if i < lines.count { i += 1 } // skip closing ```
                let codeFont = NSFont.monospacedSystemFont(ofSize: baseFont.pointSize * 0.85, weight: .regular)
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: codeFont,
                    .foregroundColor: color.withAlphaComponent(0.8)
                ]
                let codeText = codeLines.joined(separator: "\n")
                if !codeText.isEmpty {
                    result.append(NSAttributedString(string: codeText + "\n", attributes: attrs))
                }
                continue
            }

            i += 1

            // ── ATX Heading  # / ## / ### ────────────────────────────────────
            let hashes = line.prefix(while: { $0 == "#" }).count
            if hashes > 0 && hashes <= 6 {
                let afterHashes = line.dropFirst(hashes)
                if afterHashes.hasPrefix(" ") || afterHashes.isEmpty {
                    let headingText = afterHashes.hasPrefix(" ") ? String(afterHashes.dropFirst()) : ""
                    let scales: [CGFloat] = [1.8, 1.5, 1.3, 1.15, 1.05, 1.0]
                    let scale = scales[min(hashes - 1, 5)]
                    let headingFont = styledFont(base: baseFont, size: baseFont.pointSize * scale, bold: true, italic: false)
                    let style = paragraphStyle(spaceBelow: 4, spaceAbove: hashes == 1 ? 8 : 4)
                    result.append(renderInline(headingText, baseFont: headingFont, color: color, style: style))
                    result.append(NSAttributedString(string: "\n", attributes: [.font: headingFont, .foregroundColor: color]))
                    continue
                }
            }

            // ── Horizontal rule  --- / *** / ___ ─────────────────────────────
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed == "---" || trimmed == "***" || trimmed == "___" {
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: baseFont,
                    .foregroundColor: color.withAlphaComponent(0.35)
                ]
                result.append(NSAttributedString(string: "───────────────────────\n", attributes: attrs))
                continue
            }

            // ── Blockquote  > ────────────────────────────────────────────────
            if line.hasPrefix("> ") || line == ">" {
                let quoteText = line.hasPrefix("> ") ? String(line.dropFirst(2)) : ""
                let quoteColor = color.withAlphaComponent(0.65)
                let style = paragraphStyle(spaceBelow: 0, headIndent: 20, firstLineIndent: 20)
                result.append(renderInline(quoteText, baseFont: baseFont, color: quoteColor, style: style))
                result.append(NSAttributedString(string: "\n", attributes: [.font: baseFont]))
                continue
            }

            // ── Unordered list  - / * / + ─────────────────────────────────
            if (line.hasPrefix("- ") || line.hasPrefix("* ") || line.hasPrefix("+ ")) && line.count > 2 {
                let itemText = "• " + String(line.dropFirst(2))
                let style = paragraphStyle(spaceBelow: 0, headIndent: 20, firstLineIndent: 8)
                result.append(renderInline(itemText, baseFont: baseFont, color: color, style: style))
                result.append(NSAttributedString(string: "\n", attributes: [.font: baseFont]))
                continue
            }

            // ── Ordered list  1. / 2. ───────────────────────────────────────
            if let dotRange = line.range(of: "^[0-9]+\\. ", options: .regularExpression) {
                let itemText = String(line[dotRange]) + String(line[dotRange.upperBound...])
                let style = paragraphStyle(spaceBelow: 0, headIndent: 28, firstLineIndent: 8)
                result.append(renderInline(itemText, baseFont: baseFont, color: color, style: style))
                result.append(NSAttributedString(string: "\n", attributes: [.font: baseFont]))
                continue
            }

            // ── Empty line ───────────────────────────────────────────────────
            if trimmed.isEmpty {
                result.append(NSAttributedString(
                    string: "\n",
                    attributes: [.font: baseFont, .foregroundColor: color]
                ))
                continue
            }

            // ── Normal paragraph ─────────────────────────────────────────────
            let style = paragraphStyle(spaceBelow: 2)
            result.append(renderInline(line, baseFont: baseFont, color: color, style: style))
            result.append(NSAttributedString(string: "\n", attributes: [.font: baseFont, .foregroundColor: color]))
        }

        return result
    }

    /// Renders inline Markdown spans: **bold**, *italic*, ***bold+italic***, `code`, [link](url)
    func renderInline(_ text: String, baseFont: NSFont, color: NSColor, style: NSParagraphStyle) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let chars = Array(text)
        var i = 0
        var pending = ""
        var bold = false
        var italic = false
        var inCode = false

        func flush() {
            guard !pending.isEmpty else { return }
            let font: NSFont
            if inCode {
                font = NSFont.monospacedSystemFont(ofSize: baseFont.pointSize * 0.9, weight: .regular)
            } else {
                font = styledFont(base: baseFont, size: baseFont.pointSize, bold: bold, italic: italic)
            }
            let c = inCode ? color.withAlphaComponent(0.85) : color
            result.append(NSAttributedString(string: pending,
                attributes: [.font: font, .foregroundColor: c, .paragraphStyle: style]))
            pending = ""
        }

        while i < chars.count {
            let c = chars[i]

            // Inline code `…`
            if c == "`" {
                flush()
                inCode.toggle()
                i += 1
                continue
            }

            if inCode {
                pending.append(c)
                i += 1
                continue
            }

            // Bold+Italic ***…*** or ___…___
            if i + 2 < chars.count &&
               ((c == "*" && chars[i+1] == "*" && chars[i+2] == "*") ||
                (c == "_" && chars[i+1] == "_" && chars[i+2] == "_")) {
                flush()
                if bold && italic { bold = false; italic = false }
                else              { bold = true;  italic = true  }
                i += 3
                continue
            }

            // Bold **…** or __…__
            if i + 1 < chars.count &&
               ((c == "*" && chars[i+1] == "*") ||
                (c == "_" && chars[i+1] == "_")) {
                flush()
                bold.toggle()
                i += 2
                continue
            }

            // Italic *…* (single star only; skip lone underscore to avoid mid-word splits)
            if c == "*" {
                flush()
                italic.toggle()
                i += 1
                continue
            }

            // Link [text](url) → show text, discard URL
            if c == "[" {
                flush()
                i += 1
                var linkText = ""
                while i < chars.count && chars[i] != "]" { linkText.append(chars[i]); i += 1 }
                if i < chars.count { i += 1 } // skip ]
                if i < chars.count && chars[i] == "(" {
                    i += 1
                    while i < chars.count && chars[i] != ")" { i += 1 }
                    if i < chars.count { i += 1 } // skip )
                }
                pending = linkText
                flush()
                continue
            }

            pending.append(c)
            i += 1
        }

        flush()
        return result
    }

    func styledFont(base: NSFont, size: CGFloat, bold: Bool, italic: Bool) -> NSFont {
        var traits = NSFontDescriptor.SymbolicTraits()
        if bold   { traits.insert(.bold) }
        if italic { traits.insert(.italic) }
        let descriptor = base.fontDescriptor.withSymbolicTraits(traits)
        return NSFont(descriptor: descriptor, size: size) ?? base
    }

    func paragraphStyle(spaceBelow: CGFloat = 0, spaceAbove: CGFloat = 0,
                        headIndent: CGFloat = 0, firstLineIndent: CGFloat = 0) -> NSParagraphStyle {
        let s = NSMutableParagraphStyle()
        s.paragraphSpacing = spaceBelow
        s.paragraphSpacingBefore = spaceAbove
        s.headIndent = headIndent
        s.firstLineHeadIndent = firstLineIndent
        return s
    }
}
