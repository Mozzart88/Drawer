import AppKit

final class StrokeHUDPanel: NSPanel, NSWindowDelegate {
    private weak var drawingView: DrawingView?

    private let hueSlider     = NSSlider()
    private let widthSlider   = NSSlider()
    private let opacitySlider = NSSlider()

    init(drawingView: DrawingView) {
        self.drawingView = drawingView

        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 1, height: 1),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        level = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue + 1)
        sharingType = .none
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        isMovableByWindowBackground = true
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        delegate = self

        let screen = NSScreen.main ?? NSScreen.screens[0]
        let hudHeight = screen.frame.height * hudHeightRatio
        buildLayout(hudHeight: hudHeight)
        restoreOrDefaultPosition()

        drawingView.onColorChanged   = { [weak self] c in self?.syncColor(c) }
        drawingView.onWidthChanged   = { [weak self] w in self?.widthSlider.doubleValue = Double(w) }
        drawingView.onOpacityChanged = { [weak self] a in self?.opacitySlider.doubleValue = Double(a) }
    }

    override var canBecomeKey: Bool { false }

    // MARK: - Layout

    private let hudHeightRatio: CGFloat = 0.05
    private let edgeInset: CGFloat = 8

    private func buildLayout(hudHeight: CGFloat) {
        let effect = NSVisualEffectView()
        effect.material = .hudWindow
        effect.blendingMode = .behindWindow
        effect.state = .active
        effect.wantsLayer = true
        effect.layer?.cornerRadius = 12

        let circleSize = max(14, (hudHeight - edgeInset * 2) * 0.75)

        let outer = NSStackView()
        outer.orientation = .horizontal
        outer.distribution = .fillEqually
        outer.spacing = 1
        outer.edgeInsets = NSEdgeInsets(top: edgeInset, left: 12, bottom: edgeInset, right: 12)
        outer.alignment = .centerY

        // Section 1: color swatches
        let swatchStack = NSStackView()
        swatchStack.orientation = .horizontal
        swatchStack.distribution = .equalSpacing
        swatchStack.alignment = .centerY
        swatchStack.edgeInsets = NSEdgeInsets(top: 0, left: 4, bottom: 0, right: 4)

        let swatchColors: [NSColor] = [.systemRed, .orange, .systemYellow, .systemGreen, .systemBlue]
        for (i, color) in swatchColors.enumerated() {
            let btn = NSButton()
            btn.bezelStyle = .rounded
            btn.isBordered = false
            btn.image = colorCircleImage(color: color, size: NSSize(width: circleSize, height: circleSize))
            btn.tag = i
            btn.target = self
            btn.action = #selector(swatchTapped(_:))
            btn.widthAnchor.constraint(equalToConstant: circleSize).isActive = true
            btn.heightAnchor.constraint(equalToConstant: circleSize).isActive = true
            swatchStack.addArrangedSubview(btn)
        }
        outer.addArrangedSubview(swatchStack)

        // Sections 2–4: slider sections
        func addSliderSection(label: String, slider: NSSlider) {
            let s = NSStackView()
            s.orientation = .horizontal
            s.spacing = 4
            s.alignment = .centerY
            s.edgeInsets = NSEdgeInsets(top: 0, left: 4, bottom: 0, right: 4)
            s.addArrangedSubview(labelView(label))
            slider.isContinuous = true
            slider.target = self
            slider.setContentHuggingPriority(.defaultLow, for: .horizontal)
            slider.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            s.addArrangedSubview(slider)
            outer.addArrangedSubview(s)
        }

        hueSlider.minValue = 0; hueSlider.maxValue = 1
        var hue: CGFloat = 0
        drawingView?.currentColor.usingColorSpace(.deviceRGB)?.getHue(&hue, saturation: nil, brightness: nil, alpha: nil)
        hueSlider.doubleValue = Double(hue)
        hueSlider.action = #selector(hueChanged(_:))
        addSliderSection(label: "H", slider: hueSlider)

        widthSlider.minValue = 1; widthSlider.maxValue = 40
        widthSlider.doubleValue = Double(drawingView?.currentWidth ?? 4)
        widthSlider.action = #selector(widthChanged(_:))
        addSliderSection(label: "W", slider: widthSlider)

        opacitySlider.minValue = 0.05; opacitySlider.maxValue = 1
        opacitySlider.doubleValue = Double(drawingView?.currentOpacity ?? 1)
        opacitySlider.action = #selector(opacityChanged(_:))
        addSliderSection(label: "O", slider: opacitySlider)

        effect.addSubview(outer)
        outer.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            outer.topAnchor.constraint(equalTo: effect.topAnchor),
            outer.bottomAnchor.constraint(equalTo: effect.bottomAnchor),
            outer.leadingAnchor.constraint(equalTo: effect.leadingAnchor),
            outer.trailingAnchor.constraint(equalTo: effect.trailingAnchor),
        ])

        contentView = effect
    }

    private func labelView(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        return label
    }

    private func colorCircleImage(color: NSColor, size: NSSize) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        let path = NSBezierPath(ovalIn: NSRect(origin: .zero, size: size))
        color.setFill()
        path.fill()
        image.unlockFocus()
        return image
    }

    // MARK: - Actions

    private static let presetColors: [NSColor] = [.systemRed, .orange, .systemYellow, .systemGreen, .systemBlue]

    @objc private func swatchTapped(_ sender: NSButton) {
        drawingView?.currentColor = StrokeHUDPanel.presetColors[sender.tag]
    }

    @objc private func hueChanged(_ sender: NSSlider) {
        drawingView?.currentColor = NSColor(hue: CGFloat(sender.doubleValue), saturation: 1, brightness: 1, alpha: 1)
    }

    @objc private func widthChanged(_ sender: NSSlider) {
        drawingView?.currentWidth = CGFloat(sender.doubleValue)
    }

    @objc private func opacityChanged(_ sender: NSSlider) {
        drawingView?.currentOpacity = CGFloat(sender.doubleValue)
    }

    // MARK: - Sync

    private func syncColor(_ color: NSColor) {
        var hue: CGFloat = 0
        color.usingColorSpace(.deviceRGB)?.getHue(&hue, saturation: nil, brightness: nil, alpha: nil)
        hueSlider.doubleValue = Double(hue)
    }

    // MARK: - Positioning

    func reposition(to screen: NSScreen) {
        let targetSize = hudSize(for: screen)
        let ox = screen.frame.minX + (screen.frame.width - targetSize.width) / 2
        let oy = screen.frame.minY + 24
        setFrame(NSRect(origin: NSPoint(x: ox, y: oy), size: targetSize), display: false)
    }

    private func hudSize(for screen: NSScreen) -> NSSize {
        NSSize(width: screen.frame.width * 0.25, height: screen.frame.height * hudHeightRatio)
    }

    private func savePosition() {
        let o = frame.origin
        UserDefaults.standard.set("\(o.x),\(o.y)", forKey: "strokeHUDOrigin")
    }

    private func restoreOrDefaultPosition() {
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let targetSize = hudSize(for: screen)
        if let saved = UserDefaults.standard.string(forKey: "strokeHUDOrigin") {
            let parts = saved.split(separator: ",")
            if parts.count == 2, let x = Double(parts[0]), let y = Double(parts[1]) {
                let origin = NSPoint(x: x, y: y)
                let testRect = NSRect(origin: origin, size: targetSize)
                let onScreen = NSScreen.screens.contains { $0.frame.intersects(testRect) }
                if onScreen {
                    setFrame(NSRect(origin: origin, size: targetSize), display: false)
                    return
                }
            }
        }
        reposition(to: screen)
    }

    // MARK: - NSWindowDelegate

    func windowDidMove(_ notification: Notification) {
        savePosition()
    }
}
