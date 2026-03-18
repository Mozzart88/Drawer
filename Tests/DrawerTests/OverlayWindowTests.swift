import Testing
import AppKit
@testable import DrawerCore

@Suite("OverlayWindow", .serialized)
@MainActor
struct OverlayWindowTests {

    @Test("initially not in green screen mode")
    func initiallyNotGreenScreen() {
        let window = OverlayWindow()
        #expect(window.isGreenScreenOn == false)
    }

    @Test("toggleGreenScreen turns it on")
    func toggleGreenScreenOn() {
        GreenScreenPreferences._defaults = makeIsolatedDefaults()
        let window = OverlayWindow()
        window.toggleGreenScreen()
        #expect(window.isGreenScreenOn == true)
        #expect(window.backgroundColor != .clear)
    }

    @Test("double toggle returns to off")
    func toggleGreenScreenOff() {
        GreenScreenPreferences._defaults = makeIsolatedDefaults()
        let window = OverlayWindow()
        window.toggleGreenScreen()
        window.toggleGreenScreen()
        #expect(window.isGreenScreenOn == false)
    }

    @Test("updateGreenScreenColor persists the color preference")
    func updateGreenScreenColor_persists() {
        GreenScreenPreferences._defaults = makeIsolatedDefaults()
        let window = OverlayWindow()
        let red = NSColor(red: 1, green: 0, blue: 0, alpha: 1)
        window.updateGreenScreenColor(red)
        let stored = GreenScreenPreferences.color.usingColorSpace(.sRGB)!
        #expect(abs(stored.redComponent - 1.0) < 0.01)
    }

    @Test("updateGreenScreenColor updates backgroundColor when green screen is on")
    func updateGreenScreenColor_updatesWhenOn() {
        GreenScreenPreferences._defaults = makeIsolatedDefaults()
        let window = OverlayWindow()
        window.toggleGreenScreen()
        let blue = NSColor(red: 0, green: 0, blue: 1, alpha: 1)
        window.updateGreenScreenColor(blue)
        // backgroundColor should now be blue
        let bg = window.backgroundColor.usingColorSpace(.sRGB)!
        #expect(bg.blueComponent > 0.9)
    }

    @Test("canBecomeKey returns false")
    func canBecomeKey_false() {
        let window = OverlayWindow()
        #expect(window.canBecomeKey == false)
    }
}
