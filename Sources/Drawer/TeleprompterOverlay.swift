import AppKit

private extension NSAttributedString.Key {
    static let codeType = NSAttributedString.Key("drawer.codeType") // "inline" | "block"
}

private class CopyButton: NSButton {
    var codeContent: String = ""
}

private class TeleprompterTextView: NSTextView {

    /// Checks whether `event` lands on a `.codeType` run and, if so, copies the
    /// appropriate text to the pasteboard.  Called from the overlay's local event
    /// monitor which has already verified that Ctrl+Cmd is held — no modifier
    /// re-check needed here.
    /// - Returns: `true` if a copy was performed and the event should be swallowed.
    fileprivate func copyCodeIfHit(at event: NSEvent) -> Bool {
        guard let storage = textStorage,
              let lm = layoutManager,
              let tc = textContainer else { return false }

        // `characterIndex(for:in:)` expects text-container coordinates,
        // not text-view coordinates — subtract the inset to convert.
        let rawPoint = convert(event.locationInWindow, from: nil)
        let inset = textContainerInset
        let point = NSPoint(x: rawPoint.x - inset.width, y: rawPoint.y - inset.height)
        let charIdx = lm.characterIndex(for: point, in: tc,
                                         fractionOfDistanceBetweenInsertionPoints: nil)
        guard charIdx < storage.length else { return false }

        var effectiveRange = NSRange()
        guard let type = storage.attribute(.codeType, at: charIdx,
                                            effectiveRange: &effectiveRange) as? String
        else { return false }

        let nsString = storage.string as NSString
        let textToCopy: String
        if type == "inline" {
            textToCopy = nsString.substring(with: effectiveRange)
        } else { // "block" — copy only the clicked line
            let lineRange = nsString.lineRange(for: NSRange(location: charIdx, length: 0))
            textToCopy = nsString.substring(with: lineRange)
                .trimmingCharacters(in: .newlines)
        }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(textToCopy, forType: .string)
        return true
    }
}

class TeleprompterOverlay: NSPanel {
    private let scrollView = NSScrollView()
    private var textView = TeleprompterTextView()
    private let backgroundView = NSView()
    private var copyButtons: [NSButton] = []
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
        sharingType = .none  // hide from screen recordings

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

        textView = TeleprompterTextView()
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

        alphaValue = CGFloat(TeleprompterPreferences.overlayOpacity)

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

        // Intercept leftMouseDown BEFORE NSApplication.sendEvent converts
        // Ctrl+LeftClick into a rightMouseDown event.
        if let m = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown, handler: { [weak self] event in
            guard let self = self,
                  self.ctrlCmdHeld && !self.drawingModeActive,
                  event.modifierFlags.contains(.control),
                  event.windowNumber == self.windowNumber else { return event }

            // Copy button hit — trigger directly.
            let locationInTextView = self.textView.convert(event.locationInWindow, from: nil)
            for btn in self.copyButtons {
                if btn.frame.contains(locationInTextView) {
                    _ = btn.target?.perform(btn.action, with: btn)
                    return nil
                }
            }

            // Code run hit — copy and swallow.
            if self.textView.copyCodeIfHit(at: event) { return nil }

            // Plain text — forward as a clean left-click so NSTextView resets
            // selection instead of extending it (Cmd strips to "add-to-selection").
            let clean = NSEvent.mouseEvent(
                with: .leftMouseDown,
                location: event.locationInWindow,
                modifierFlags: [],
                timestamp: event.timestamp,
                windowNumber: event.windowNumber,
                context: nil,
                eventNumber: event.eventNumber,
                clickCount: event.clickCount,
                pressure: event.pressure
            ) ?? event
            self.textView.mouseDown(with: clean)
            return nil  // swallow — prevents the Ctrl→rightMouseDown conversion
        }) {
            modifierMonitors.append(m)
        }
    }

    private func updateMouseEventHandling() {
        let interact = ctrlCmdHeld && !drawingModeActive
        ignoresMouseEvents = !interact
        textView.isSelectable = interact
        updateCopyButtons()
    }

    private func updateCopyButtons() {
        copyButtons.forEach { $0.removeFromSuperview() }
        copyButtons = []

        guard ctrlCmdHeld && !drawingModeActive,
              let storage = textView.textStorage,
              let lm = textView.layoutManager,
              let tc = textView.textContainer else { return }

        storage.enumerateAttribute(.codeType,
                                    in: NSRange(location: 0, length: storage.length),
                                    options: []) { val, range, _ in
            guard val as? String == "block" else { return }

            let blockText = (storage.string as NSString).substring(with: range)
            let glyphRange = lm.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
            var rect = lm.boundingRect(forGlyphRange: glyphRange, in: tc)
            let inset = self.textView.textContainerInset
            rect.origin.x += inset.width
            rect.origin.y += inset.height

            let btn = CopyButton(frame: NSRect(x: rect.maxX - 56, y: rect.minY - 22,
                                               width: 52, height: 20))
            btn.codeContent = blockText
            btn.title = "Copy"
            btn.bezelStyle = .inline
            btn.font = NSFont.systemFont(ofSize: 11, weight: .medium)
            btn.contentTintColor = .white
            btn.wantsLayer = true
            btn.layer?.backgroundColor = NSColor(white: 0.15, alpha: 0.85).cgColor
            btn.layer?.cornerRadius = 4
            btn.target = self
            btn.action = #selector(copyButtonTapped(_:))
            self.textView.addSubview(btn)
            self.copyButtons.append(btn)
        }
    }

    @objc private func copyButtonTapped(_ sender: CopyButton) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(sender.codeContent, forType: .string)
        let original = sender.title
        sender.title = "✓"
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            sender.title = original
        }
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
                    .foregroundColor: color.withAlphaComponent(0.8),
                    .codeType: "block"
                ]
                let codeText = codeLines.joined(separator: "\n")
                if !codeText.isEmpty {
                    result.append(NSAttributedString(string: codeText, attributes: attrs))
                    result.append(NSAttributedString(string: "\n"))
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

            // ── Alert block  > [!NOTE|TIP|IMPORTANT|WARNING|CAUTION] ────────────────
            let alertKeywords = ["NOTE", "TIP", "IMPORTANT", "WARNING", "CAUTION"]
            if line.hasPrefix("> [!"),
               let keyword = alertKeywords.first(where: {
                   line.uppercased().hasPrefix("> [!\($0)]")
               }) {
                // Collect subsequent "> " lines as the body
                var bodyLines: [String] = []
                while i < lines.count && (lines[i].hasPrefix("> ") || lines[i] == ">") {
                    bodyLines.append(lines[i].hasPrefix("> ") ? String(lines[i].dropFirst(2)) : "")
                    i += 1
                }

                let ac = alertColor(for: keyword)
                let labelFont = styledFont(base: baseFont, size: baseFont.pointSize, bold: true, italic: false)
                let bodyStyle = paragraphStyle(spaceBelow: 0, headIndent: 20, firstLineIndent: 0)

                // Label:  ┃ NOTE
                result.append(NSAttributedString(string: "┃ \(keyword)\n",
                    attributes: [.font: labelFont, .foregroundColor: ac]))

                // Body lines:  ┃ <text>
                for bodyLine in bodyLines {
                    result.append(NSAttributedString(string: "┃ ",
                        attributes: [.font: baseFont, .foregroundColor: ac]))
                    result.append(renderInline(bodyLine, baseFont: baseFont,
                                               color: ac.withAlphaComponent(0.85), style: bodyStyle))
                    result.append(NSAttributedString(string: "\n",
                        attributes: [.font: baseFont, .foregroundColor: ac]))
                }
                result.append(NSAttributedString(string: "\n",
                    attributes: [.font: baseFont, .foregroundColor: color]))
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
            if inCode {
                result.append(NSAttributedString(string: pending,
                    attributes: [.font: font, .foregroundColor: c, .paragraphStyle: style,
                                 .codeType: "inline"]))
            } else {
                result.append(NSAttributedString(string: pending,
                    attributes: [.font: font, .foregroundColor: c, .paragraphStyle: style]))
            }
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

    func alertColor(for type: String) -> NSColor {
        switch type {
        case "NOTE":      return NSColor(calibratedRed: 0.31, green: 0.51, blue: 0.97, alpha: 1)
        case "TIP":       return NSColor(calibratedRed: 0.12, green: 0.73, blue: 0.37, alpha: 1)
        case "IMPORTANT": return NSColor(calibratedRed: 0.62, green: 0.33, blue: 0.97, alpha: 1)
        case "WARNING":   return NSColor(calibratedRed: 0.97, green: 0.70, blue: 0.14, alpha: 1)
        case "CAUTION":   return NSColor(calibratedRed: 0.95, green: 0.30, blue: 0.25, alpha: 1)
        default:          return NSColor(calibratedRed: 0.6,  green: 0.6,  blue: 0.6,  alpha: 1)
        }
    }
}
