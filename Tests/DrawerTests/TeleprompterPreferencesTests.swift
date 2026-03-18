import Testing
import AppKit
@testable import DrawerCore

@Suite("TeleprompterPreferences", .serialized)
@MainActor
struct TeleprompterPreferencesTests {

    private func setUp() {
        TeleprompterPreferences._defaults = makeIsolatedDefaults()
    }

    @Test("enabled defaults to false")
    func enabledDefault() {
        setUp()
        #expect(TeleprompterPreferences.enabled == false)
    }

    @Test("enabled round-trip")
    func enabledRoundTrip() {
        setUp()
        TeleprompterPreferences.enabled = true
        #expect(TeleprompterPreferences.enabled == true)
    }

    @Test("filePath round-trip")
    func filePathRoundTrip() {
        setUp()
        TeleprompterPreferences.filePath = "/Users/test/script.md"
        #expect(TeleprompterPreferences.filePath == "/Users/test/script.md")
    }

    @Test("fontSize defaults to 28")
    func fontSizeDefault28() {
        setUp()
        #expect(TeleprompterPreferences.fontSize == 28)
    }

    @Test("fontSize round-trip")
    func fontSizeRoundTrip() {
        setUp()
        TeleprompterPreferences.fontSize = 36
        #expect(TeleprompterPreferences.fontSize == 36)
    }

    @Test("textOpacity defaults to 1.0")
    func textOpacityDefault() {
        setUp()
        #expect(TeleprompterPreferences.textOpacity == 1.0)
    }

    @Test("textOpacity round-trip")
    func textOpacityRoundTrip() {
        setUp()
        TeleprompterPreferences.textOpacity = 0.8
        #expect(abs(TeleprompterPreferences.textOpacity - 0.8) < 0.001)
    }

    @Test("autoScroll defaults to false")
    func autoScrollDefault() {
        setUp()
        #expect(TeleprompterPreferences.autoScroll == false)
    }

    @Test("autoScroll round-trip")
    func autoScrollRoundTrip() {
        setUp()
        TeleprompterPreferences.autoScroll = true
        #expect(TeleprompterPreferences.autoScroll == true)
    }

    @Test("autoScrollSpeed defaults to 2.5")
    func autoScrollSpeedDefault() {
        setUp()
        #expect(TeleprompterPreferences.autoScrollSpeed == 2.5)
    }

    @Test("autoScrollSpeed round-trip")
    func autoScrollSpeedRoundTrip() {
        setUp()
        TeleprompterPreferences.autoScrollSpeed = 5.0
        #expect(TeleprompterPreferences.autoScrollSpeed == 5.0)
    }

    @Test("backgroundColorHex defaults to 000000")
    func backgroundColorHexDefault() {
        setUp()
        #expect(TeleprompterPreferences.backgroundColorHex == "000000")
    }

    @Test("backgroundColorHex round-trip")
    func backgroundColorHexRoundTrip() {
        setUp()
        TeleprompterPreferences.backgroundColorHex = "FF0000"
        #expect(TeleprompterPreferences.backgroundColorHex == "FF0000")
    }

    @Test("backgroundOpacity defaults to 0.7")
    func backgroundOpacityDefault() {
        setUp()
        #expect(TeleprompterPreferences.backgroundOpacity == 0.7)
    }

    @Test("backgroundOpacity round-trip")
    func backgroundOpacityRoundTrip() {
        setUp()
        TeleprompterPreferences.backgroundOpacity = 0.5
        #expect(abs(TeleprompterPreferences.backgroundOpacity - 0.5) < 0.001)
    }

    @Test("save and restore scroll position for a path")
    func saveScrollPosition_andRestore() {
        setUp()
        TeleprompterPreferences.saveScrollPosition(0.75, for: "/path/to/file.md")
        let loaded = TeleprompterPreferences.scrollPosition(for: "/path/to/file.md")
        #expect(abs(loaded - 0.75) < 0.001)
    }

    @Test("scrollPosition for missing file returns 0")
    func scrollPositionMissingFileReturns0() {
        setUp()
        let pos = TeleprompterPreferences.scrollPosition(for: "/nonexistent/path.md")
        #expect(pos == 0)
    }

    @Test("overlayFrame round-trip as CSV string")
    func overlayFrameRoundTrip() {
        setUp()
        let rect = NSRect(x: 10, y: 20, width: 400, height: 300)
        TeleprompterPreferences.overlayFrame = rect
        let loaded = TeleprompterPreferences.overlayFrame
        #expect(abs(loaded.origin.x - 10) < 0.01)
        #expect(abs(loaded.origin.y - 20) < 0.01)
        #expect(abs(loaded.size.width - 400) < 0.01)
        #expect(abs(loaded.size.height - 300) < 0.01)
    }
}
