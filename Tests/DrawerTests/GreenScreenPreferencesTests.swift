import Testing
import AppKit
@testable import DrawerCore

@Suite("GreenScreenPreferences", .serialized)
@MainActor
struct GreenScreenPreferencesTests {

    private func setUp() {
        GreenScreenPreferences._defaults = makeIsolatedDefaults()
    }

    @Test("default color is green")
    func defaultColorIsGreen() {
        setUp()
        let color = GreenScreenPreferences.color.usingColorSpace(.sRGB)!
        #expect(color.redComponent < 0.01)
        #expect(abs(color.greenComponent - 1.0) < 0.01)
        #expect(color.blueComponent < 0.01)
    }

    @Test("hex round-trip — save red load back equals red")
    func hexRoundTrip() {
        setUp()
        let red = NSColor(red: 1, green: 0, blue: 0, alpha: 1)
        GreenScreenPreferences.color = red
        let loaded = GreenScreenPreferences.color.usingColorSpace(.sRGB)!
        #expect(abs(loaded.redComponent - 1.0) < 0.01)
        #expect(loaded.greenComponent < 0.01)
        #expect(loaded.blueComponent < 0.01)
    }

    @Test("invalid hex string falls back to green")
    func invalidHexFallsBackToGreen() {
        setUp()
        GreenScreenPreferences._defaults.set("ZZZZZZ", forKey: "drawer.greenscreen.color")
        let color = GreenScreenPreferences.color.usingColorSpace(.sRGB)!
        #expect(color.redComponent < 0.01)
        #expect(abs(color.greenComponent - 1.0) < 0.01)
    }

    @Test("hex string format is 6 uppercase hex chars")
    func hexStringFormat() {
        setUp()
        let color = NSColor(red: 0.5, green: 0.25, blue: 0.75, alpha: 1.0)
        GreenScreenPreferences.color = color
        let stored = GreenScreenPreferences._defaults.string(forKey: "drawer.greenscreen.color")!
        #expect(stored.count == 6)
        #expect(stored == stored.uppercased())
        // Verify it's valid hex
        #expect(UInt64(stored, radix: 16) != nil)
    }
}
