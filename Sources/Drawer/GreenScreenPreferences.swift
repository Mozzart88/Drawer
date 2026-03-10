import AppKit

enum GreenScreenPreferences {
    private static let colorKey = "drawer.greenscreen.color"

    static var color: NSColor {
        get {
            guard let hex = UserDefaults.standard.string(forKey: colorKey) else {
                return NSColor(red: 0, green: 1, blue: 0, alpha: 1)
            }
            return NSColor(hex: hex) ?? NSColor(red: 0, green: 1, blue: 0, alpha: 1)
        }
        set {
            UserDefaults.standard.set(newValue.hexString, forKey: colorKey)
        }
    }
}

private extension NSColor {
    convenience init?(hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard h.count == 6, let value = UInt64(h, radix: 16) else { return nil }
        self.init(
            red: CGFloat((value >> 16) & 0xFF) / 255,
            green: CGFloat((value >> 8) & 0xFF) / 255,
            blue: CGFloat(value & 0xFF) / 255,
            alpha: 1
        )
    }

    var hexString: String {
        guard let rgb = usingColorSpace(.sRGB) else { return "00FF00" }
        return String(format: "%02X%02X%02X",
            Int(rgb.redComponent * 255),
            Int(rgb.greenComponent * 255),
            Int(rgb.blueComponent * 255))
    }
}
