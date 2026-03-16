import AppKit

enum TeleprompterPreferences {
    private static let ud = UserDefaults.standard
    private static let prefix = "drawer.teleprompter."

    static var enabled: Bool {
        get { ud.bool(forKey: prefix + "enabled") }
        set { ud.set(newValue, forKey: prefix + "enabled") }
    }

    static var filePath: String? {
        get { ud.string(forKey: prefix + "filePath") }
        set { ud.set(newValue, forKey: prefix + "filePath") }
    }

    // Stored as "x,y,w,h" CSV string; defaults to centered 400×300
    static var overlayFrame: NSRect {
        get {
            guard let s = ud.string(forKey: prefix + "overlayFrame") else { return defaultFrame() }
            let parts = s.split(separator: ",").compactMap { Double($0) }
            guard parts.count == 4 else { return defaultFrame() }
            return NSRect(x: parts[0], y: parts[1], width: parts[2], height: parts[3])
        }
        set {
            let f = newValue
            ud.set("\(f.origin.x),\(f.origin.y),\(f.size.width),\(f.size.height)", forKey: prefix + "overlayFrame")
        }
    }

    private static func defaultFrame() -> NSRect {
        let screen = NSScreen.main ?? NSScreen.screens[0]
        return NSRect(x: screen.frame.midX - 200, y: screen.frame.midY - 150, width: 400, height: 300)
    }

    static var fontSize: Double {
        get {
            let v = ud.double(forKey: prefix + "fontSize")
            return v > 0 ? v : 28
        }
        set { ud.set(newValue, forKey: prefix + "fontSize") }
    }

    static var fontColor: NSColor {
        get {
            guard let data = ud.data(forKey: prefix + "fontColor"),
                  let color = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: data) else {
                return .white
            }
            return color
        }
        set {
            if let data = try? NSKeyedArchiver.archivedData(withRootObject: newValue, requiringSecureCoding: false) {
                ud.set(data, forKey: prefix + "fontColor")
            }
        }
    }

    static var textOpacity: Double {
        get {
            guard ud.object(forKey: prefix + "textOpacity") != nil else { return 1.0 }
            return ud.double(forKey: prefix + "textOpacity")
        }
        set { ud.set(newValue, forKey: prefix + "textOpacity") }
    }

    static var autoScroll: Bool {
        get { ud.bool(forKey: prefix + "autoScroll") }
        set { ud.set(newValue, forKey: prefix + "autoScroll") }
    }

    static var autoScrollSpeed: Double {
        get {
            let v = ud.double(forKey: prefix + "autoScrollSpeed")
            return v > 0 ? v : 2.5
        }
        set { ud.set(newValue, forKey: prefix + "autoScrollSpeed") }
    }

    static var backgroundColorHex: String {
        get { ud.string(forKey: prefix + "backgroundColorHex") ?? "000000" }
        set { ud.set(newValue, forKey: prefix + "backgroundColorHex") }
    }

    static var backgroundOpacity: Double {
        get {
            guard ud.object(forKey: prefix + "backgroundOpacity") != nil else { return 0.7 }
            return ud.double(forKey: prefix + "backgroundOpacity")
        }
        set { ud.set(newValue, forKey: prefix + "backgroundOpacity") }
    }

    static var scrollPositions: [String: Double] {
        get {
            guard let data = ud.data(forKey: prefix + "scrollPositions"),
                  let dict = try? JSONDecoder().decode([String: Double].self, from: data) else {
                return [:]
            }
            return dict
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                ud.set(data, forKey: prefix + "scrollPositions")
            }
        }
    }

    static func saveScrollPosition(_ position: Double, for path: String) {
        var positions = scrollPositions
        positions[path] = position
        scrollPositions = positions
    }

    static func scrollPosition(for path: String) -> Double {
        return scrollPositions[path] ?? 0
    }
}

// Internal hex helpers shared by TeleprompterOverlay and RecordingControlPanel
extension NSColor {
    convenience init?(teleprompterHex hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard h.count == 6, let value = UInt64(h, radix: 16) else { return nil }
        self.init(
            red: CGFloat((value >> 16) & 0xFF) / 255,
            green: CGFloat((value >> 8) & 0xFF) / 255,
            blue: CGFloat(value & 0xFF) / 255,
            alpha: 1
        )
    }

    var teleprompterHexString: String {
        guard let rgb = usingColorSpace(.sRGB) else { return "000000" }
        return String(format: "%02X%02X%02X",
            Int(rgb.redComponent * 255),
            Int(rgb.greenComponent * 255),
            Int(rgb.blueComponent * 255))
    }
}
