import Testing
import AppKit
@testable import DrawerCore

@Suite("RecordingPreferences", .serialized)
@MainActor
struct RecordingPreferencesTests {

    private func setUp() {
        RecordingPreferences._defaults = makeIsolatedDefaults()
    }

    @Test("audioDeviceUID nil by default")
    func audioDeviceUID_nilByDefault() {
        setUp()
        #expect(RecordingPreferences.audioDeviceUID == nil)
    }

    @Test("audioDeviceUID round-trip")
    func audioDeviceUID_roundTrip() {
        setUp()
        RecordingPreferences.audioDeviceUID = "device-123"
        #expect(RecordingPreferences.audioDeviceUID == "device-123")
    }

    @Test("presentationMode defaults to false")
    func presentationMode_defaultFalse() {
        setUp()
        #expect(RecordingPreferences.presentationMode == false)
    }

    @Test("saveDirectory defaults to Desktop")
    func saveDirectory_defaultsToDesktop() {
        setUp()
        let desktop = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask)[0]
        #expect(RecordingPreferences.saveDirectory == desktop)
    }

    @Test("saveDirectory round-trip")
    func saveDirectory_roundTrip() {
        setUp()
        let url = URL(fileURLWithPath: "/tmp/recordings")
        RecordingPreferences.saveDirectory = url
        #expect(RecordingPreferences.saveDirectory == url)
    }

    @Test("hasPreferences false when no recordingMode key")
    func hasPreferences_falseWhenNone() {
        setUp()
        #expect(RecordingPreferences.hasPreferences == false)
    }

    @Test("hasPreferences true after saving recordingMode")
    func hasPreferences_trueAfterSave() {
        setUp()
        RecordingPreferences.recordingMode = 0
        #expect(RecordingPreferences.hasPreferences == true)
    }

    @Test("recordingMode defaults to 0")
    func recordingMode_default0() {
        setUp()
        // After setting it explicitly to 0
        RecordingPreferences.recordingMode = 0
        #expect(RecordingPreferences.recordingMode == 0)
    }

    @Test("recordingMode round-trip")
    func recordingMode_roundTrip() {
        setUp()
        RecordingPreferences.recordingMode = 1
        #expect(RecordingPreferences.recordingMode == 1)
    }

    @Test("windowBundleID round-trip")
    func windowBundleID_roundTrip() {
        setUp()
        RecordingPreferences.windowBundleID = "com.example.app"
        #expect(RecordingPreferences.windowBundleID == "com.example.app")
    }

    @Test("windowTitle round-trip")
    func windowTitle_roundTrip() {
        setUp()
        RecordingPreferences.windowTitle = "My Window"
        #expect(RecordingPreferences.windowTitle == "My Window")
    }

    @Test("keyCastingEnabled defaults to false")
    func keyCastingEnabled_default() {
        setUp()
        #expect(RecordingPreferences.keyCastingEnabled == false)
    }

    @Test("keyCastingEnabled round-trip")
    func keyCastingEnabled_roundTrip() {
        setUp()
        RecordingPreferences.keyCastingEnabled = true
        #expect(RecordingPreferences.keyCastingEnabled == true)
    }

    @Test("keyCastingPosition nil by default")
    func keyCastingPosition_nilByDefault() {
        setUp()
        #expect(RecordingPreferences.keyCastingPosition == nil)
    }

    @Test("keyCastingPosition round-trip")
    func keyCastingPosition_roundTrip() {
        setUp()
        let point = CGPoint(x: 100, y: 200)
        RecordingPreferences.keyCastingPosition = point
        let loaded = RecordingPreferences.keyCastingPosition
        #expect(loaded != nil)
        #expect(abs(loaded!.x - 100) < 0.01)
        #expect(abs(loaded!.y - 200) < 0.01)
    }

    @Test("keyCastingPosition parsing error returns nil")
    func keyCastingPosition_parsingError() {
        setUp()
        RecordingPreferences._defaults.set("notapoint", forKey: "drawer.recording.keyCastingPosition")
        #expect(RecordingPreferences.keyCastingPosition == nil)
    }

    @Test("keyCastingLifetime defaults to 1.5")
    func keyCastingLifetime_default1_5() {
        setUp()
        #expect(RecordingPreferences.keyCastingLifetime == 1.5)
    }

    @Test("keyCastingLifetime round-trip")
    func keyCastingLifetime_roundTrip() {
        setUp()
        RecordingPreferences.keyCastingLifetime = 3.0
        #expect(RecordingPreferences.keyCastingLifetime == 3.0)
    }

    @Test("keyCastingKeyFontSize defaults to 20")
    func keyCastingKeyFontSize_default20() {
        setUp()
        #expect(RecordingPreferences.keyCastingKeyFontSize == 20)
    }

    @Test("keyCastingKeyFontSize round-trip")
    func keyCastingKeyFontSize_roundTrip() {
        setUp()
        RecordingPreferences.keyCastingKeyFontSize = 36
        #expect(RecordingPreferences.keyCastingKeyFontSize == 36)
    }

    @Test("keyCastingModifierFontSize defaults to 10")
    func keyCastingModifierFontSize_default10() {
        setUp()
        #expect(RecordingPreferences.keyCastingModifierFontSize == 10)
    }

    @Test("keyCastingModifierFontSize round-trip")
    func keyCastingModifierFontSize_roundTrip() {
        setUp()
        RecordingPreferences.keyCastingModifierFontSize = 14
        #expect(RecordingPreferences.keyCastingModifierFontSize == 14)
    }

    @Test("keyCastingBgColor defaults to black")
    func keyCastingBgColor_defaultBlack() {
        setUp()
        let color = RecordingPreferences.keyCastingBgColor
        let srgb = color.usingColorSpace(.sRGB)!
        #expect(srgb.redComponent < 0.01)
        #expect(srgb.greenComponent < 0.01)
        #expect(srgb.blueComponent < 0.01)
    }

    @Test("keyCastingBgColor round-trip")
    func keyCastingBgColor_roundTrip() {
        setUp()
        let color = NSColor(srgbRed: 1, green: 0, blue: 0, alpha: 1)
        RecordingPreferences.keyCastingBgColor = color
        let loaded = RecordingPreferences.keyCastingBgColor.usingColorSpace(.sRGB)!
        #expect(abs(loaded.redComponent - 1.0) < 0.01)
        #expect(loaded.greenComponent < 0.01)
    }

    @Test("keyCastingBgColor malformed string falls back to black")
    func keyCastingBgColor_malformedString() {
        setUp()
        RecordingPreferences._defaults.set("bad,value", forKey: "drawer.recording.keyCastingBgColor")
        let color = RecordingPreferences.keyCastingBgColor
        let srgb = color.usingColorSpace(.sRGB)!
        #expect(srgb.redComponent < 0.01)
    }

    @Test("keyCastingBgOpacity defaults to 0.75")
    func keyCastingBgOpacity_default0_75() {
        setUp()
        #expect(RecordingPreferences.keyCastingBgOpacity == 0.75)
    }

    @Test("keyCastingBgOpacity round-trip")
    func keyCastingBgOpacity_roundTrip() {
        setUp()
        RecordingPreferences.keyCastingBgOpacity = 0.5
        #expect(abs(RecordingPreferences.keyCastingBgOpacity - 0.5) < 0.001)
    }

    @Test("keyCastingDemoText has default")
    func keyCastingDemoText_default() {
        setUp()
        #expect(RecordingPreferences.keyCastingDemoText == "Hello ⎵ World")
    }

    @Test("keyCastingDemoText round-trip")
    func keyCastingDemoText_roundTrip() {
        setUp()
        RecordingPreferences.keyCastingDemoText = "Test ABC"
        #expect(RecordingPreferences.keyCastingDemoText == "Test ABC")
    }

    @Test("virtualChromakeyEnabled round-trip")
    func virtualChromakeyEnabled_roundTrip() {
        setUp()
        RecordingPreferences.virtualChromakeyEnabled = true
        #expect(RecordingPreferences.virtualChromakeyEnabled == true)
        RecordingPreferences.virtualChromakeyEnabled = false
        #expect(RecordingPreferences.virtualChromakeyEnabled == false)
    }

    @Test("alphaChannelEnabled round-trip")
    func alphaChannelEnabled_roundTrip() {
        setUp()
        RecordingPreferences.alphaChannelEnabled = true
        #expect(RecordingPreferences.alphaChannelEnabled == true)
    }
}
