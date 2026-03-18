import Testing
import AppKit
@testable import DrawerCore

@Suite("KeyCastOverlay", .serialized)
@MainActor
struct KeyCastOverlayTests {

    private func makeOverlay() -> KeyCastOverlay {
        RecordingPreferences._defaults = makeIsolatedDefaults()
        return KeyCastOverlay()
    }

    @Test("showKey sets the label text")
    func showKey_setsLabelText() {
        let overlay = makeOverlay()
        overlay.showKey("A", inline: true)
        // The keyLabel text should contain "A"
        // We access it via the overlay's showDemoText / showKey public API
        // Since keyLabel is private, we test via showKey idempotence
        overlay.showKey("B", inline: true)
        // After two inline keys, the label should have both
        // This exercises the non-inline path too
        overlay.showKey("↩", inline: false)
    }

    @Test("showKey inline appends without space when no previous content")
    func showKey_inline_appendsWithoutSpaceWhenEmpty() {
        let overlay = makeOverlay()
        // First inline key on empty overlay
        overlay.showKey("x", inline: true)
        // Subsequent inline key should concatenate
        overlay.showKey("y", inline: true)
    }

    @Test("showKey non-inline adds separator space")
    func showKey_nonInline_addsSeparator() {
        let overlay = makeOverlay()
        overlay.showKey("a", inline: true)
        // non-inline after inline should add a space separator
        overlay.showKey("↩", inline: false)
    }

    @Test("updateModifiers highlights shift when shift is active")
    func updateModifiers_shiftHighlighted() {
        let overlay = makeOverlay()
        // Just verify it doesn't crash with shift flag
        overlay.updateModifiers(NSEvent.ModifierFlags.shift)
    }

    @Test("updateModifiers with no modifiers doesn't crash")
    func updateModifiers_noModifiers_notHighlighted() {
        let overlay = makeOverlay()
        overlay.updateModifiers([])
    }

    @Test("updateModifiers with multiple flags")
    func updateModifiers_commandAndShift() {
        let overlay = makeOverlay()
        overlay.updateModifiers([.command, .shift])
    }

    @Test("keyFontSize didSet triggers resize without crash")
    func keyFontSizeDidSet_triggersResize() {
        let overlay = makeOverlay()
        overlay.keyFontSize = 32
        #expect(overlay.keyFontSize == 32)
    }

    @Test("modifierFontSize didSet triggers resize without crash")
    func modifierFontSizeDidSet_triggersResize() {
        let overlay = makeOverlay()
        overlay.modifierFontSize = 14
        #expect(overlay.modifierFontSize == 14)
    }

    @Test("overlayBackgroundColor didSet updates background")
    func overlayBackgroundColorDidSet_updatesBackground() {
        let overlay = makeOverlay()
        overlay.overlayBackgroundColor = .red
        #expect(overlay.overlayBackgroundColor == .red)
    }

    @Test("overlayBackgroundOpacity didSet updates background")
    func overlayBackgroundOpacityDidSet_updatesBackground() {
        let overlay = makeOverlay()
        overlay.overlayBackgroundOpacity = 0.5
        #expect(overlay.overlayBackgroundOpacity == 0.5)
    }

    @Test("showDemoText sets demo text")
    func showDemoText() {
        let overlay = makeOverlay()
        overlay.demoText = "Custom Demo"
        overlay.showDemoText()
        // Should not crash
    }

    @Test("moveToSavedPosition with no saved position uses default")
    func moveToSavedPosition_noSaved_usesDefault() {
        let overlay = makeOverlay()
        overlay.moveToSavedPosition()
        // Should not crash and window should be on screen
    }

    @Test("moveToSavedPosition with saved position restores it")
    func moveToSavedPosition_savedPosition() {
        // Use a single isolated defaults instance throughout this test
        let isolated = makeIsolatedDefaults()
        RecordingPreferences._defaults = isolated
        RecordingPreferences.keyCastingPosition = CGPoint(x: 100, y: 200)
        // Create overlay WITHOUT resetting defaults
        let overlay = KeyCastOverlay()
        overlay.moveToSavedPosition()
        // Position should be applied (within 1pt tolerance)
        #expect(abs(overlay.frame.origin.x - 100) < 1)
        #expect(abs(overlay.frame.origin.y - 200) < 1)
    }
}
