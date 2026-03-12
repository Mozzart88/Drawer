import AppKit

final class ColorPanelController: NSObject {
    private weak var drawingView: DrawingView?
    private let widthSlider    = NSSlider()
    private let widthLabel     = NSTextField(labelWithString: "4")
    private var accessoryView: NSView!

    init(drawingView: DrawingView) {
        self.drawingView = drawingView
        super.init()
        configure()
        drawingView.onWidthChanged   = { [weak self] w in self?.syncWidth(w) }
        drawingView.onOpacityChanged = { [weak self] a in self?.syncOpacity(a) }
        drawingView.onColorChanged   = { [weak self] _ in self?.syncPanelColor() }
    }

    private func configure() {
        let panel = NSColorPanel.shared
        panel.showsAlpha  = true
        panel.isContinuous = true
        panel.setTarget(self)
        panel.setAction(#selector(colorChanged))
        syncPanelColor()

        // Accessory: Width label + slider + value
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 220, height: 36))
        let label = NSTextField(labelWithString: "Width")
        label.frame = NSRect(x: 8, y: 8, width: 42, height: 20)
        widthSlider.frame = NSRect(x: 56, y: 8, width: 126, height: 20)
        widthSlider.minValue = 1; widthSlider.maxValue = 40
        widthSlider.doubleValue = Double(drawingView?.currentWidth ?? 4)
        widthSlider.target = self; widthSlider.action = #selector(widthChanged)
        widthLabel.frame = NSRect(x: 188, y: 8, width: 28, height: 20)
        widthLabel.alignment = .right
        widthLabel.stringValue = String(format: "%.0f", drawingView?.currentWidth ?? 4)
        container.addSubview(label)
        container.addSubview(widthSlider)
        container.addSubview(widthLabel)
        accessoryView = container
        panel.accessoryView = container
    }

    func show() {
        let panel = NSColorPanel.shared
        panel.setTarget(self)
        panel.setAction(#selector(colorChanged))
        panel.showsAlpha = true
        panel.accessoryView = accessoryView
        syncPanelColor()
        syncWidth(drawingView?.currentWidth ?? 4)
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    func toggle() {
        NSColorPanel.shared.isVisible ? NSColorPanel.shared.orderOut(nil) : show()
    }

    @objc private func colorChanged() {
        guard let dv = drawingView else { return }
        let c = NSColorPanel.shared.color
        dv.currentColor   = c.withAlphaComponent(1.0)
        dv.currentOpacity = c.alphaComponent
    }

    @objc private func widthChanged() {
        let v = CGFloat(widthSlider.doubleValue)
        drawingView?.currentWidth = v
        widthLabel.stringValue = String(format: "%.0f", v)
    }

    private func syncWidth(_ w: CGFloat) {
        widthSlider.doubleValue = Double(w)
        widthLabel.stringValue  = String(format: "%.0f", w)
    }

    private func syncOpacity(_ a: CGFloat) {
        guard let dv = drawingView else { return }
        NSColorPanel.shared.color = dv.currentColor.withAlphaComponent(a)
    }

    private func syncPanelColor() {
        guard let dv = drawingView else { return }
        NSColorPanel.shared.color = dv.currentColor.withAlphaComponent(dv.currentOpacity)
    }
}
