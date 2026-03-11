import AppKit

class KeyCastOverlay: NSPanel {

    var keyLifetime: TimeInterval = 1.5

    var keyFontSize: CGFloat = 20 {
        didSet {
            keyLabel.font = NSFont.systemFont(ofSize: keyFontSize, weight: .medium)
            applySize(keepTopLeft: true)
        }
    }

    var modifierFontSize: CGFloat = 10 {
        didSet {
            updateModifiers(currentModifierFlags)
            applySize(keepTopLeft: true)
        }
    }

    private let keyLabel: NSTextField
    private var lastKeyWasSpecial = false
    private var currentModifierFlags: NSEvent.ModifierFlags = []
    private let modifierPairs: [(UInt, NSTextField)]
    private var clearTimer: Timer?
    private var divider: NSBox?
    private var isApplyingSize = false

    private static let overlayWidth: CGFloat = 220
    private static let modifierDefs: [(UInt, String)] = [
        (NSEvent.ModifierFlags.shift.rawValue,   "⇧"),
        (NSEvent.ModifierFlags.control.rawValue, "⌃"),
        (NSEvent.ModifierFlags.option.rawValue,  "⌥"),
        (NSEvent.ModifierFlags.command.rawValue, "⌘"),
    ]

    init() {
        keyLabel = NSTextField(labelWithString: "")
        modifierPairs = KeyCastOverlay.modifierDefs.map { (rawValue, title) in
            (rawValue, NSTextField(labelWithString: title))
        }

        super.init(
            contentRect: NSRect(x: 0, y: 0, width: KeyCastOverlay.overlayWidth, height: 80),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = true
        level = .screenSaver
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

    /// Computes the overlay height needed to fit both font sizes comfortably.
    private func computeNeededSize() -> NSSize {
        let w = contentView?.bounds.width ?? KeyCastOverlay.overlayWidth
        let modAreaH: CGFloat = max(22, ceil(modifierFontSize) + 10)
        let keyAreaH: CGFloat = max(28, ceil(keyFontSize) + 12)
        // 8 bottom + modArea + 2 gap + 1 divider + 4 gap + keyArea + 8 top
        let totalH = 8 + modAreaH + 2 + 1 + 4 + keyAreaH + 8
        return NSSize(width: w, height: totalH)
    }

    /// Resizes the window to fit the current font sizes, then lays out subviews.
    /// keepTopLeft: when true the top-left corner stays fixed while height grows/shrinks.
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

    /// Positions all subviews within the current content bounds,
    /// with text vertically centred in each zone.
    private func relayout() {
        guard let container = contentView else { return }
        let bounds = container.bounds

        let modAreaH: CGFloat = max(22, ceil(modifierFontSize) + 10)
        let keyAreaH: CGFloat = max(28, ceil(keyFontSize) + 12)
        let labelW = bounds.width - 16

        // Modifier row — bottom zone
        let modY: CGFloat = 8
        let modLabelH: CGFloat = ceil(modifierFontSize) + 4  // always < modAreaH
        let modLabelY = modY + (modAreaH - modLabelH) / 2

        // Divider
        let divY = modY + modAreaH + 2

        // Key label — top zone
        let keyY = divY + 1 + 4
        let keyLabelH: CGFloat = ceil(keyFontSize) + 4  // always < keyAreaH
        let keyLabelY = keyY + (keyAreaH - keyLabelH) / 2

        keyLabel.frame = NSRect(x: 8, y: keyLabelY, width: labelW, height: keyLabelH)
        divider?.frame = NSRect(x: 8, y: divY, width: labelW, height: 1)

        let modW = labelW / CGFloat(modifierPairs.count)
        for (i, (_, label)) in modifierPairs.enumerated() {
            label.frame = NSRect(x: 8 + CGFloat(i) * modW, y: modLabelY, width: modW, height: modLabelH)
        }
    }

    private func setupContent() {
        let container = DraggableView(frame: NSRect(
            x: 0, y: 0,
            width: KeyCastOverlay.overlayWidth,
            height: 80
        ))
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.75).cgColor
        container.layer?.cornerRadius = 10
        contentView = container

        keyLabel.font = NSFont.systemFont(ofSize: keyFontSize, weight: .medium)
        keyLabel.textColor = .white
        keyLabel.alignment = .center
        keyLabel.lineBreakMode = .byTruncatingHead
        keyLabel.isBezeled = false
        keyLabel.drawsBackground = false
        keyLabel.isEditable = false
        keyLabel.isSelectable = false
        container.addSubview(keyLabel)

        let div = NSBox()
        div.boxType = .separator
        div.borderColor = NSColor.white.withAlphaComponent(0.3)
        container.addSubview(div)
        divider = div

        for (_, label) in modifierPairs {
            label.font = NSFont.systemFont(ofSize: modifierFontSize, weight: .regular)
            label.textColor = NSColor.white.withAlphaComponent(0.5)
            label.alignment = .center
            label.isBezeled = false
            label.drawsBackground = false
            label.isEditable = false
            label.isSelectable = false
            container.addSubview(label)
        }

        applySize(keepTopLeft: false)
    }

    // MARK: - Public API

    func showKey(_ text: String, inline: Bool = false) {
        let current = keyLabel.stringValue
        let needsSeparator = !current.isEmpty && (!inline || lastKeyWasSpecial)
        keyLabel.stringValue = current + (needsSeparator ? " " : "") + text
        lastKeyWasSpecial = !inline
        clearTimer?.invalidate()
        clearTimer = Timer.scheduledTimer(withTimeInterval: keyLifetime, repeats: false) { [weak self] _ in
            self?.keyLabel.stringValue = ""
            self?.lastKeyWasSpecial = false
        }
    }

    func showDemoText() {
        clearTimer?.invalidate()
        clearTimer = nil
        keyLabel.stringValue = "Hello ⎵ World"
        lastKeyWasSpecial = false
    }

    func updateModifiers(_ flags: NSEvent.ModifierFlags) {
        currentModifierFlags = flags
        for (rawValue, label) in modifierPairs {
            let active = flags.rawValue & rawValue != 0
            label.textColor = active ? .white : NSColor.white.withAlphaComponent(0.5)
            label.font = active
                ? NSFont.systemFont(ofSize: modifierFontSize, weight: .bold)
                : NSFont.systemFont(ofSize: modifierFontSize, weight: .regular)
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
