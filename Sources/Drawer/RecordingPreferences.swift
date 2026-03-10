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
}
