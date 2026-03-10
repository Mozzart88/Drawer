import AppKit

enum TabletInput {
    static func widthMultiplier(pressure: Float, tilt: NSPoint) -> CGFloat {
        let p = CGFloat(max(0, pressure))
        let tiltMag = sqrt(tilt.x * tilt.x + tilt.y * tilt.y) / CGFloat(2).squareRoot()
        // sqrt curve: light pressure ≈ base width (~0.2 pressure → 1×),
        // heavy pressure gives up to 2.5×; tilt adds a subtle broadening
        let pressureCurved = pow(p, 0.5) * 2.5
        return max(0.1, min(3.0, pressureCurved + tiltMag * 0.25))
    }

    static func pointWidth(for event: NSEvent, baseWidth: CGFloat) -> CGFloat {
        baseWidth * widthMultiplier(pressure: event.pressure, tilt: event.tilt)
    }

    static func isPenEvent(_ event: NSEvent) -> Bool {
        event.subtype == .tabletPoint
    }
}
