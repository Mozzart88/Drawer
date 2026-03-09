import AppKit

class ColorWheelPanel: NSPanel, NSTextFieldDelegate {
    weak var drawingView: DrawingView?
    private var wheelView: ColorWheelView!
    private var brightnessSlider: NSSlider!
    private var currentHue: CGFloat = 0.0
    private var currentSaturation: CGFloat = 1.0
    private var currentBrightness: CGFloat = 1.0

    private var hexField: NSTextField!
    private var opacitySlider: NSSlider!
    private var opacityValueLabel: NSTextField!
    private var currentOpacity: CGFloat = 1.0
    private var widthSlider: NSSlider!
    private var widthValueLabel: NSTextField!

    init(drawingView: DrawingView) {
        self.drawingView = drawingView
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 220, height: 350),
            styleMask: [.titled, .closable, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        title = "Color"
        isFloatingPanel = true
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.floatingWindow)))
        hidesOnDeactivate = false
        isReleasedWhenClosed = false

        setupUI()
        center()

        drawingView.onWidthChanged = { [weak self] width in
            self?.updateWidth(width)
        }
        drawingView.onOpacityChanged = { [weak self] opacity in
            self?.updateOpacity(opacity)
        }
    }

    private func setupUI() {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 220, height: 350))
        contentView = container

        wheelView = ColorWheelView(frame: NSRect(x: 10, y: 140, width: 200, height: 200))
        wheelView.onColorSelected = { [weak self] hue, saturation in
            self?.currentHue = hue
            self?.currentSaturation = saturation
            self?.updateColor()
        }
        container.addSubview(wheelView)

        let sliderLabel = NSTextField(labelWithString: "Brightness")
        sliderLabel.frame = NSRect(x: 10, y: 115, width: 80, height: 20)
        container.addSubview(sliderLabel)

        brightnessSlider = NSSlider(frame: NSRect(x: 90, y: 115, width: 120, height: 20))
        brightnessSlider.minValue = 0.1
        brightnessSlider.maxValue = 1.0
        brightnessSlider.doubleValue = 1.0
        brightnessSlider.target = self
        brightnessSlider.action = #selector(brightnessChanged)
        container.addSubview(brightnessSlider)

        // Opacity row
        let opacityLabel = NSTextField(labelWithString: "Opacity")
        opacityLabel.frame = NSRect(x: 10, y: 88, width: 55, height: 20)
        container.addSubview(opacityLabel)

        opacitySlider = NSSlider(frame: NSRect(x: 70, y: 88, width: 120, height: 20))
        opacitySlider.minValue = 0.05
        opacitySlider.maxValue = 1.0
        opacitySlider.doubleValue = 1.0
        opacitySlider.target = self
        opacitySlider.action = #selector(opacityChanged)
        container.addSubview(opacitySlider)

        opacityValueLabel = NSTextField(labelWithString: "100%")
        opacityValueLabel.frame = NSRect(x: 193, y: 88, width: 27, height: 20)
        opacityValueLabel.alignment = .right
        container.addSubview(opacityValueLabel)

        // Hex label
        let hexLabel = NSTextField(labelWithString: "Hex")
        hexLabel.frame = NSRect(x: 10, y: 60, width: 35, height: 20)
        container.addSubview(hexLabel)

        // Hex text field
        hexField = NSTextField(frame: NSRect(x: 50, y: 57, width: 160, height: 22))
        hexField.stringValue = "#FF0000"
        hexField.delegate = self
        container.addSubview(hexField)

        // Width label
        let widthLabel = NSTextField(labelWithString: "Width")
        widthLabel.frame = NSRect(x: 10, y: 28, width: 40, height: 20)
        container.addSubview(widthLabel)

        // Width slider
        widthSlider = NSSlider(frame: NSRect(x: 55, y: 28, width: 120, height: 20))
        widthSlider.minValue = 1.0
        widthSlider.maxValue = 40.0
        widthSlider.doubleValue = Double(drawingView?.currentWidth ?? 4.0)
        widthSlider.target = self
        widthSlider.action = #selector(widthChanged)
        container.addSubview(widthSlider)

        // Width value label
        widthValueLabel = NSTextField(labelWithString: String(format: "%.0f", drawingView?.currentWidth ?? 4.0))
        widthValueLabel.frame = NSRect(x: 180, y: 28, width: 30, height: 20)
        widthValueLabel.alignment = .right
        container.addSubview(widthValueLabel)
    }

    @objc private func brightnessChanged() {
        currentBrightness = CGFloat(brightnessSlider.doubleValue)
        updateColor()
    }

    @objc private func opacityChanged() {
        currentOpacity = CGFloat(opacitySlider.doubleValue)
        opacityValueLabel.stringValue = String(format: "%.0f%%", currentOpacity * 100)
        updateColor()
    }

    func updateOpacity(_ value: CGFloat) {
        currentOpacity = value
        opacitySlider.doubleValue = Double(value)
        opacityValueLabel.stringValue = String(format: "%.0f%%", value * 100)
        updateColor()
    }

    @objc private func widthChanged() {
        let value = CGFloat(widthSlider.doubleValue)
        drawingView?.currentWidth = value
        widthValueLabel.stringValue = String(format: "%.0f", value)
    }

    func updateWidth(_ value: CGFloat) {
        widthSlider.doubleValue = Double(value)
        widthValueLabel.stringValue = String(format: "%.0f", value)
    }

    private func updateColor() {
        let color = NSColor(hue: currentHue, saturation: currentSaturation, brightness: currentBrightness, alpha: currentOpacity)
        drawingView?.currentColor = color
        updateHexField()
    }

    private func updateHexField() {
        guard let rgb = NSColor(hue: currentHue, saturation: currentSaturation, brightness: currentBrightness, alpha: 1.0)
                .usingColorSpace(.deviceRGB) else { return }
        let r = Int(rgb.redComponent * 255)
        let g = Int(rgb.greenComponent * 255)
        let b = Int(rgb.blueComponent * 255)
        hexField.stringValue = String(format: "#%02X%02X%02X", r, g, b)
    }

    // MARK: - NSTextFieldDelegate

    func controlTextDidEndEditing(_ obj: Notification) {
        var hex = hexField.stringValue.trimmingCharacters(in: .whitespaces)
        if hex.hasPrefix("#") { hex = String(hex.dropFirst()) }
        guard hex.count == 6, let value = UInt64(hex, radix: 16) else { return }
        let r = CGFloat((value >> 16) & 0xFF) / 255.0
        let g = CGFloat((value >> 8) & 0xFF) / 255.0
        let b = CGFloat(value & 0xFF) / 255.0
        let color = NSColor(red: r, green: g, blue: b, alpha: 1.0)
        guard let hsb = color.usingColorSpace(.deviceRGB) else { return }
        var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
        hsb.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        currentHue = hue
        currentSaturation = saturation
        currentBrightness = brightness
        brightnessSlider.doubleValue = Double(brightness)
        updateColor()
        updateHexField()
    }
}

class ColorWheelView: NSView {
    var onColorSelected: ((CGFloat, CGFloat) -> Void)?
    private var wheelImage: NSImage?

    override init(frame: NSRect) {
        super.init(frame: frame)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ dirtyRect: NSRect) {
        if wheelImage == nil {
            wheelImage = renderWheelImage()
        }
        wheelImage?.draw(in: bounds)
    }

    private func renderWheelImage() -> NSImage {
        let size = bounds.size
        let image = NSImage(size: size)
        image.lockFocus()

        let cx = size.width / 2
        let cy = size.height / 2
        let radius = min(cx, cy) - 2

        for py in 0..<Int(size.height) {
            for px in 0..<Int(size.width) {
                let dx = CGFloat(px) - cx
                let dy = CGFloat(py) - cy
                let dist = sqrt(dx * dx + dy * dy)
                if dist <= radius {
                    let hue = (atan2(dy, dx) + .pi) / (2 * .pi)
                    let saturation = dist / radius
                    let color = NSColor(hue: hue, saturation: saturation, brightness: 1.0, alpha: 1.0)
                    color.setFill()
                    NSRect(x: CGFloat(px), y: CGFloat(py), width: 1, height: 1).fill()
                }
            }
        }

        image.unlockFocus()
        return image
    }

    override func mouseDown(with event: NSEvent) {
        handleClick(event)
    }

    override func mouseDragged(with event: NSEvent) {
        handleClick(event)
    }

    private func handleClick(_ event: NSEvent) {
        let loc = convert(event.locationInWindow, from: nil)
        let cx = bounds.width / 2
        let cy = bounds.height / 2
        let radius = min(cx, cy) - 2
        let dx = loc.x - cx
        let dy = loc.y - cy
        let dist = min(sqrt(dx * dx + dy * dy), radius)
        let hue = (atan2(dy, dx) + .pi) / (2 * .pi)
        let saturation = dist / radius
        onColorSelected?(hue, saturation)
    }
}
