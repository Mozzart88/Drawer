import Foundation

enum RecordingPreferences {
    private static let defaults = UserDefaults.standard

    /// uniqueID of the selected AVCaptureDevice; nil = "None"
    static var audioDeviceUID: String? {
        get { defaults.string(forKey: "drawer.recording.audioDeviceUID") }
        set { defaults.set(newValue, forKey: "drawer.recording.audioDeviceUID") }
    }

    static var presentationMode: Bool {
        get { defaults.bool(forKey: "drawer.recording.presentationMode") }
        set { defaults.set(newValue, forKey: "drawer.recording.presentationMode") }
    }

    /// Directory in which recordings are saved. Defaults to ~/Desktop.
    static var saveDirectory: URL {
        get {
            guard let path = defaults.string(forKey: "drawer.recording.saveDirectory") else {
                return FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask)[0]
            }
            return URL(fileURLWithPath: path)
        }
        set { defaults.set(newValue.path, forKey: "drawer.recording.saveDirectory") }
    }

    static var hasPreferences: Bool {
        defaults.object(forKey: "recordingMode") != nil
    }

    static var recordingMode: Int {
        get { defaults.integer(forKey: "recordingMode") }  // 0 = full screen, 1 = window
        set { defaults.set(newValue, forKey: "recordingMode") }
    }

    static var windowBundleID: String? {
        get { defaults.string(forKey: "windowBundleID") }
        set { defaults.set(newValue, forKey: "windowBundleID") }
    }

    static var windowTitle: String? {
        get { defaults.string(forKey: "windowTitle") }
        set { defaults.set(newValue, forKey: "windowTitle") }
    }

    static var keyCastingEnabled: Bool {
        get { defaults.bool(forKey: "drawer.recording.keyCasting") }
        set { defaults.set(newValue, forKey: "drawer.recording.keyCasting") }
    }

    /// Stored as "x,y" string; nil = default (bottom-right corner)
    static var keyCastingPosition: CGPoint? {
        get {
            guard let s = defaults.string(forKey: "drawer.recording.keyCastingPosition") else { return nil }
            let parts = s.split(separator: ",").compactMap { Double($0) }
            guard parts.count == 2 else { return nil }
            return CGPoint(x: parts[0], y: parts[1])
        }
        set {
            if let p = newValue {
                defaults.set("\(p.x),\(p.y)", forKey: "drawer.recording.keyCastingPosition")
            } else {
                defaults.removeObject(forKey: "drawer.recording.keyCastingPosition")
            }
        }
    }

    /// Duration in seconds that a regular key press stays visible. Default 1.5.
    static var keyCastingLifetime: TimeInterval {
        get {
            let v = defaults.double(forKey: "drawer.recording.keyCastingLifetime")
            return v > 0 ? v : 1.5
        }
        set { defaults.set(newValue, forKey: "drawer.recording.keyCastingLifetime") }
    }

    /// Font size for the pressed-key label. Default 20.
    static var keyCastingKeyFontSize: CGFloat {
        get {
            let v = defaults.double(forKey: "drawer.recording.keyCastingKeyFontSize")
            return v > 0 ? CGFloat(v) : 20
        }
        set { defaults.set(Double(newValue), forKey: "drawer.recording.keyCastingKeyFontSize") }
    }

    /// Font size for the modifier-key row. Default 10.
    static var keyCastingModifierFontSize: CGFloat {
        get {
            let v = defaults.double(forKey: "drawer.recording.keyCastingModifierFontSize")
            return v > 0 ? CGFloat(v) : 10
        }
        set { defaults.set(Double(newValue), forKey: "drawer.recording.keyCastingModifierFontSize") }
    }
}
