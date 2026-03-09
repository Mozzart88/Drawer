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
}
