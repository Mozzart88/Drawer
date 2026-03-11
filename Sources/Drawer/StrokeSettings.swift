import AppKit

enum StrokeSettings {
    private static let colorKey   = "strokeColor"
    private static let widthKey   = "strokeWidth"
    private static let opacityKey = "strokeOpacity"

    struct Values {
        let color: NSColor
        let width: CGFloat
        let opacity: CGFloat
    }

    static func load() -> Values {
        let defaults = UserDefaults.standard
        let color: NSColor
        if let data = defaults.data(forKey: colorKey),
           let c = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: data) {
            color = c
        } else {
            color = .red
        }
        let width   = defaults.object(forKey: widthKey)   .map { CGFloat($0 as! Double) } ?? 4.0
        let opacity = defaults.object(forKey: opacityKey) .map { CGFloat($0 as! Double) } ?? 1.0
        return Values(color: color, width: width, opacity: opacity)
    }

    static func save(color: NSColor, opacity: CGFloat, width: CGFloat) {
        let defaults = UserDefaults.standard
        if let data = try? NSKeyedArchiver.archivedData(withRootObject: color, requiringSecureCoding: false) {
            defaults.set(data, forKey: colorKey)
        }
        defaults.set(Double(width),   forKey: widthKey)
        defaults.set(Double(opacity), forKey: opacityKey)
    }
}
