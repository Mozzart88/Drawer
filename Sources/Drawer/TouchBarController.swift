import AppKit

private extension NSTouchBarItem.Identifier {
    static let colorRed    = NSTouchBarItem.Identifier("com.drawer.tb.colorRed")
    static let colorOrange = NSTouchBarItem.Identifier("com.drawer.tb.colorOrange")
    static let colorYellow = NSTouchBarItem.Identifier("com.drawer.tb.colorYellow")
    static let colorGreen  = NSTouchBarItem.Identifier("com.drawer.tb.colorGreen")
    static let colorBlue   = NSTouchBarItem.Identifier("com.drawer.tb.colorBlue")
    static let hueSlider   = NSTouchBarItem.Identifier("com.drawer.tb.hueSlider")
    static let widthPopover   = NSTouchBarItem.Identifier("com.drawer.tb.widthPopover")
    static let opacityPopover = NSTouchBarItem.Identifier("com.drawer.tb.opacityPopover")
    static let widthSlider    = NSTouchBarItem.Identifier("com.drawer.tb.widthSlider")
    static let opacitySlider  = NSTouchBarItem.Identifier("com.drawer.tb.opacitySlider")
}

final class TouchBarController: NSObject, NSTouchBarDelegate {
    private weak var drawingView: DrawingView?
    weak var widthSliderItem: NSSliderTouchBarItem?
    weak var opacitySliderItem: NSSliderTouchBarItem?
    private weak var hueSliderItem: NSSliderTouchBarItem?

    init(drawingView: DrawingView) {
        self.drawingView = drawingView
        super.init()

        drawingView.onWidthChanged = { [weak self] w in
            self?.widthSliderItem?.slider.doubleValue = Double(w)
        }
        drawingView.onOpacityChanged = { [weak self] a in
            self?.opacitySliderItem?.slider.doubleValue = Double(a)
        }
        drawingView.onColorChanged = { [weak self] color in
            guard let self, let item = self.hueSliderItem else { return }
            var hue: CGFloat = 0
            color.usingColorSpace(.deviceRGB)?.getHue(&hue, saturation: nil, brightness: nil, alpha: nil)
            item.slider.doubleValue = Double(hue)
        }
    }

    func makeTouchBar() -> NSTouchBar {
        let bar = NSTouchBar()
        bar.delegate = self
        bar.defaultItemIdentifiers = [
            .colorRed, .colorOrange, .colorYellow, .colorGreen, .colorBlue,
            .hueSlider,
            .flexibleSpace,
            .widthPopover, .opacityPopover
        ]
        return bar
    }

    func touchBar(_ touchBar: NSTouchBar, makeItemForIdentifier identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem? {
        switch identifier {
        case .colorRed:    return makeColorButton(identifier: identifier, color: .systemRed)
        case .colorOrange: return makeColorButton(identifier: identifier, color: .orange)
        case .colorYellow: return makeColorButton(identifier: identifier, color: .systemYellow)
        case .colorGreen:  return makeColorButton(identifier: identifier, color: .systemGreen)
        case .colorBlue:   return makeColorButton(identifier: identifier, color: .systemBlue)

        case .hueSlider:
            let item = NSSliderTouchBarItem(identifier: identifier)
            item.label = "Hue"
            item.slider.minValue = 0.0
            item.slider.maxValue = 1.0
            var hue: CGFloat = 0
            drawingView?.currentColor.usingColorSpace(.deviceRGB)?.getHue(&hue, saturation: nil, brightness: nil, alpha: nil)
            item.slider.doubleValue = Double(hue)
            item.target = self
            item.action = #selector(hueSliderChanged(_:))
            hueSliderItem = item
            return item

        case .widthPopover:
            let item = NSPopoverTouchBarItem(identifier: identifier)
            item.collapsedRepresentationImage = NSImage(systemSymbolName: "lineweight", accessibilityDescription: "Width")
            let innerBar = NSTouchBar()
            innerBar.delegate = self
            innerBar.defaultItemIdentifiers = [.widthSlider]
            item.popoverTouchBar = innerBar
            item.showsCloseButton = true
            return item

        case .opacityPopover:
            let item = NSPopoverTouchBarItem(identifier: identifier)
            item.collapsedRepresentationImage = NSImage(systemSymbolName: "circle.lefthalf.filled", accessibilityDescription: "Opacity")
            let innerBar = NSTouchBar()
            innerBar.delegate = self
            innerBar.defaultItemIdentifiers = [.opacitySlider]
            item.popoverTouchBar = innerBar
            item.showsCloseButton = true
            return item

        case .widthSlider:
            let item = NSSliderTouchBarItem(identifier: identifier)
            item.label = "Width"
            item.slider.minValue = 1.0
            item.slider.maxValue = 40.0
            item.slider.doubleValue = Double(drawingView?.currentWidth ?? 4)
            item.target = self
            item.action = #selector(widthSliderChanged(_:))
            widthSliderItem = item
            return item

        case .opacitySlider:
            let item = NSSliderTouchBarItem(identifier: identifier)
            item.label = "Opacity"
            item.slider.minValue = 0.05
            item.slider.maxValue = 1.0
            item.slider.doubleValue = Double(drawingView?.currentOpacity ?? 1)
            item.target = self
            item.action = #selector(opacitySliderChanged(_:))
            opacitySliderItem = item
            return item

        default:
            return nil
        }
    }

    private func makeColorButton(identifier: NSTouchBarItem.Identifier, color: NSColor) -> NSTouchBarItem {
        let item = NSCustomTouchBarItem(identifier: identifier)
        let image = colorCircleImage(color: color, size: NSSize(width: 16, height: 16))
        let button = NSButton(image: image, target: self, action: #selector(presetColorTapped(_:)))
        button.bezelStyle = .rounded
        button.isBordered = false
        button.tag = presetColorTag(for: color)
        item.view = button
        return item
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

    private func presetColorTag(for color: NSColor) -> Int {
        // Use pointer identity isn't reliable; map by name
        if color == .systemRed    { return 0 }
        if color == .orange       { return 1 }
        if color == .systemYellow { return 2 }
        if color == .systemGreen  { return 3 }
        return 4
    }

    private static let presetColors: [NSColor] = [.systemRed, .orange, .systemYellow, .systemGreen, .systemBlue]

    @objc private func presetColorTapped(_ sender: NSButton) {
        let color = TouchBarController.presetColors[sender.tag]
        drawingView?.currentColor = color
    }

    @objc private func hueSliderChanged(_ sender: NSSliderTouchBarItem) {
        let hue = CGFloat(sender.slider.doubleValue)
        let color = NSColor(hue: hue, saturation: 1, brightness: 1, alpha: 1)
        drawingView?.currentColor = color
    }

    @objc private func widthSliderChanged(_ sender: NSSliderTouchBarItem) {
        drawingView?.currentWidth = CGFloat(sender.slider.doubleValue)
    }

    @objc private func opacitySliderChanged(_ sender: NSSliderTouchBarItem) {
        drawingView?.currentOpacity = CGFloat(sender.slider.doubleValue)
    }
}
