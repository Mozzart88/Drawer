import Testing
import AppKit
@testable import DrawerCore

@Suite("StrokeSettings", .serialized)
@MainActor
struct StrokeSettingsTests {

    @discardableResult
    private func setUp() -> UserDefaults {
        let d = makeIsolatedDefaults()
        StrokeSettings._defaults = d
        return d
    }

    @Test("load defaults when no saved data")
    func loadDefaults() {
        setUp()
        let values = StrokeSettings.load()
        #expect(values.width == 4.0)
        #expect(values.opacity == 1.0)
        #expect(values.color.isEqual(to: NSColor.red))
    }

    @Test("round-trip color save and load")
    func roundTripColor() {
        setUp()
        let color = NSColor(red: 0.3, green: 0.6, blue: 0.9, alpha: 1.0)
        StrokeSettings.save(color: color, opacity: 1.0, width: 4.0)
        let loaded = StrokeSettings.load()
        let loadedSRGB = loaded.color.usingColorSpace(.sRGB)!
        let originalSRGB = color.usingColorSpace(.sRGB)!
        #expect(abs(loadedSRGB.redComponent - originalSRGB.redComponent) < 0.01)
        #expect(abs(loadedSRGB.greenComponent - originalSRGB.greenComponent) < 0.01)
        #expect(abs(loadedSRGB.blueComponent - originalSRGB.blueComponent) < 0.01)
    }

    @Test("round-trip width save and load")
    func roundTripWidth() {
        setUp()
        StrokeSettings.save(color: .red, opacity: 1.0, width: 12.5)
        let loaded = StrokeSettings.load()
        #expect(loaded.width == 12.5)
    }

    @Test("round-trip opacity save and load")
    func roundTripOpacity() {
        setUp()
        StrokeSettings.save(color: .red, opacity: 0.42, width: 4.0)
        let loaded = StrokeSettings.load()
        #expect(abs(loaded.opacity - 0.42) < 0.001)
    }

    @Test("corrupt color data falls back to .red")
    func loadCorruptColorData() {
        let d = setUp()
        d.set(Data([0xDE, 0xAD, 0xBE, 0xEF]), forKey: "strokeColor")
        let values = StrokeSettings.load()
        #expect(values.color.isEqual(to: NSColor.red))
    }
}
