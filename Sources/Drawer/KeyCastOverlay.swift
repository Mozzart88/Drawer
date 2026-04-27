import AppKit

class KeyCastOverlay: NSPanel {

    var keyLifetime: TimeInterval = 1.5

    var keyFontSize: CGFloat = 20 {
        didSet {
            keyLabel.font = NSFont.systemFont(ofSize: keyFontSize, weight: .medium)
            modifierIconLabel.font = NSFont.systemFont(ofSize: keyFontSize, weight: .medium)
            applySize(keepTopLeft: true)
        }
    }

    var overlayBackgroundColor: NSColor = .black { didSet { applyBackground() } }
    var overlayBackgroundOpacity: CGFloat = 0.75  { didSet { applyBackground() } }
    var demoText: String = "Hello ⎵ World"

    private let keyLabel: NSTextField
    private let modifierIconLabel: NSTextField
    private var sectionSeparator: NSView?
    private var lastKeyWasSpecial = false
    private var currentModifierFlags: NSEvent.ModifierFlags = []
    private var sessionPeakFlags: NSEvent.ModifierFlags = []
    private var clearTimer: Timer?
    private var modClearTimer: Timer?
    private var isApplyingSize = false

    private func applyBackground() {
        contentView?.layer?.backgroundColor =
            overlayBackgroundColor.withAlphaComponent(overlayBackgroundOpacity).cgColor
    }

    private static let overlayWidth: CGFloat = 220
    private static let modifierDefs: [(UInt, String)] = [
        (NSEvent.ModifierFlags.shift.rawValue,   "⇧"),
        (NSEvent.ModifierFlags.control.rawValue, "⌃"),
        (NSEvent.ModifierFlags.option.rawValue,  "⌥"),
        (NSEvent.ModifierFlags.command.rawValue, "⌘"),
    ]

    init() {
        keyLabel = NSTextField(labelWithString: "")
        modifierIconLabel = NSTextField(labelWithString: "")

        super.init(
            contentRect: NSRect(x: 0, y: 0, width: KeyCastOverlay.overlayWidth, height: 80),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = true
        level = .screenSaver
        sharingType = .readOnly   // allow ScreenCaptureKit to capture this window
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        ignoresMouseEvents = false
        isMovableByWindowBackground = false
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        setupContent()
    }

    // MARK: - Layout

    private func skRowHeight() -> CGFloat { max(28, ceil(keyFontSize) + 8) }
    private func keyRowHeight() -> CGFloat { max(32, ceil(keyFontSize) + 12) }

    private func computeNeededSize() -> NSSize {
        let h = 6 + skRowHeight() + 1 + keyRowHeight() + 6
        return NSSize(width: KeyCastOverlay.overlayWidth, height: h)
    }

    private func applySize(keepTopLeft: Bool) {
        guard !isApplyingSize else { return }
        isApplyingSize = true
        defer { isApplyingSize = false }

        let newSize = computeNeededSize()
        if keepTopLeft {
            let topY = frame.origin.y + frame.height
            setContentSize(newSize)
            setFrameOrigin(CGPoint(x: frame.origin.x, y: topY - frame.height))
        } else {
            setContentSize(newSize)
        }
        relayout()
    }

    private func relayout() {
        guard let container = contentView else { return }
        let bounds = container.bounds
        let w = bounds.width
        let labelH = ceil(keyFontSize) + 4
        let skH = skRowHeight()
        let keyH = keyRowHeight()

        // SK row — top
        let skRowY = bounds.height - 6 - skH
        modifierIconLabel.frame = NSRect(x: 8, y: skRowY + (skH - labelH) / 2, width: w - 16, height: labelH)

        // Separator
        let sepY = skRowY - 1
        sectionSeparator?.frame = NSRect(x: 8, y: sepY, width: w - 16, height: 1)

        // Key row — bottom
        let keyRowY = sepY - keyH
        keyLabel.frame = NSRect(x: 8, y: keyRowY + (keyH - labelH) / 2, width: w - 16, height: labelH)
    }

    private func setupContent() {
        let size = computeNeededSize()
        let container = DraggableView(frame: NSRect(x: 0, y: 0, width: size.width, height: size.height))
        container.wantsLayer = true
        container.layer?.cornerRadius = 10
        contentView = container
        applyBackground()

        for label in [modifierIconLabel, keyLabel] {
            label.font = NSFont.systemFont(ofSize: keyFontSize, weight: .medium)
            label.textColor = .white
            label.alignment = .center
            label.lineBreakMode = .byTruncatingHead
            label.isBezeled = false
            label.drawsBackground = false
            label.isEditable = false
            label.isSelectable = false
            container.addSubview(label)
        }
        modifierIconLabel.textColor = NSColor.white.withAlphaComponent(0.0)  // invisible until pressed

        let sep = NSView()
        sep.wantsLayer = true
        sep.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.25).cgColor
        container.addSubview(sep)
        sectionSeparator = sep

        applySize(keepTopLeft: false)
    }

    // MARK: - Modifier icon

    private func clearModifierIcon() {
        modClearTimer?.invalidate()
        modClearTimer = nil
        modifierIconLabel.stringValue = ""
        modifierIconLabel.textColor = NSColor.white.withAlphaComponent(0.0)
    }

    // MARK: - Public API

    func showKey(_ text: String, inline: Bool = false) {
        modClearTimer?.invalidate()
        modClearTimer = nil
        let current = keyLabel.stringValue
        let needsSeparator = !current.isEmpty && (!inline || lastKeyWasSpecial)
        keyLabel.stringValue = current + (needsSeparator ? " " : "") + text
        lastKeyWasSpecial = !inline
        clearTimer?.invalidate()
        clearTimer = Timer.scheduledTimer(withTimeInterval: keyLifetime, repeats: false) { [weak self] _ in
            guard let self else { return }
            self.clearTimer = nil
            self.keyLabel.stringValue = ""
            self.lastKeyWasSpecial = false
            let anyHeld = KeyCastOverlay.modifierDefs.contains { self.currentModifierFlags.rawValue & $0.0 != 0 }
            if !anyHeld { self.clearModifierIcon() }
        }
    }

    func showDemoText() {
        clearTimer?.invalidate()
        clearTimer = nil
        keyLabel.stringValue = demoText
        lastKeyWasSpecial = false
    }

    func updateModifiers(_ flags: NSEvent.ModifierFlags) {
        currentModifierFlags = flags
        let activeSymbols = KeyCastOverlay.modifierDefs
            .filter { flags.rawValue & $0.0 != 0 }
            .map { $0.1 }
            .joined(separator: " ")

        if !activeSymbols.isEmpty {
            // Accumulate into peak; always display the peak set (never shrink while held)
            sessionPeakFlags = NSEvent.ModifierFlags(rawValue: sessionPeakFlags.rawValue | flags.rawValue)
            let peakSymbols = KeyCastOverlay.modifierDefs
                .filter { sessionPeakFlags.rawValue & $0.0 != 0 }
                .map { $0.1 }
                .joined(separator: " ")
            modifierIconLabel.stringValue = peakSymbols
            modifierIconLabel.textColor = .white
            modClearTimer?.invalidate()
            modClearTimer = nil
        } else {
            // All released — dim the peak set, then clear after timeout
            modifierIconLabel.textColor = NSColor.white.withAlphaComponent(0.4)
            sessionPeakFlags = []
            modClearTimer?.invalidate()
            if clearTimer == nil {
                modClearTimer = Timer.scheduledTimer(withTimeInterval: keyLifetime, repeats: false) { [weak self] _ in
                    self?.modClearTimer = nil
                    self?.clearModifierIcon()
                }
            }
        }
    }

    func moveToSavedPosition() {
        applySize(keepTopLeft: false)
        if let saved = RecordingPreferences.keyCastingPosition {
            setFrameOrigin(saved)
        } else {
            if let screen = NSScreen.main {
                let margin: CGFloat = 40
                let origin = CGPoint(
                    x: screen.visibleFrame.maxX - frame.width - margin,
                    y: screen.visibleFrame.minY + margin
                )
                setFrameOrigin(origin)
            }
        }
    }
}

// MARK: - Draggable content view

private class DraggableView: NSView {
    override func mouseDown(with event: NSEvent) {}

    override func mouseDragged(with event: NSEvent) {
        window?.performDrag(with: event)
    }

    override func mouseUp(with event: NSEvent) {
        if let origin = window?.frame.origin {
            RecordingPreferences.keyCastingPosition = origin
        }
    }
}
