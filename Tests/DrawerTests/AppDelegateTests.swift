import Testing
import AppKit
@testable import DrawerCore

/// Tests for AppDelegate.keyDisplay(for:) — the pure key-code-to-symbol mapping.
/// We construct synthetic NSEvents using NSEvent.keyEvent(with:location:modifierFlags:timestamp:windowNumber:context:characters:charactersIgnoringModifiers:isARepeat:keyCode:).
@Suite("AppDelegate keyDisplay", .serialized)
@MainActor
struct AppDelegateTests {

    private func makeKeyEvent(keyCode: UInt16, chars: String = "") -> NSEvent {
        NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: chars,
            charactersIgnoringModifiers: chars,
            isARepeat: false,
            keyCode: keyCode
        )!
    }

    @Test("space key")
    func keyDisplay_space() {
        let e = makeKeyEvent(keyCode: 49, chars: " ")
        let (text, inline) = AppDelegate.keyDisplay(for: e)
        #expect(text == "⎵")
        #expect(inline == false)
    }

    @Test("return key")
    func keyDisplay_returnKey() {
        let e = makeKeyEvent(keyCode: 36)
        let (text, inline) = AppDelegate.keyDisplay(for: e)
        #expect(text == "↩")
        #expect(inline == false)
    }

    @Test("delete key")
    func keyDisplay_deleteKey() {
        let e = makeKeyEvent(keyCode: 51)
        let (text, inline) = AppDelegate.keyDisplay(for: e)
        #expect(text == "⌫")
        #expect(inline == false)
    }

    @Test("forward delete key")
    func keyDisplay_forwardDeleteKey() {
        let e = makeKeyEvent(keyCode: 117)
        let (text, inline) = AppDelegate.keyDisplay(for: e)
        #expect(text == "⌦")
        #expect(inline == false)
    }

    @Test("escape key")
    func keyDisplay_escapeKey() {
        let e = makeKeyEvent(keyCode: 53)
        let (text, inline) = AppDelegate.keyDisplay(for: e)
        #expect(text == "<Esc>")
        #expect(inline == false)
    }

    @Test("tab key")
    func keyDisplay_tabKey() {
        let e = makeKeyEvent(keyCode: 48)
        let (text, inline) = AppDelegate.keyDisplay(for: e)
        #expect(text == "⇥")
        #expect(inline == false)
    }

    @Test("up arrow key")
    func keyDisplay_upArrow() {
        let e = makeKeyEvent(keyCode: 126)
        let (text, inline) = AppDelegate.keyDisplay(for: e)
        #expect(text == "↑")
        #expect(inline == false)
    }

    @Test("down arrow key")
    func keyDisplay_downArrow() {
        let e = makeKeyEvent(keyCode: 125)
        let (text, inline) = AppDelegate.keyDisplay(for: e)
        #expect(text == "↓")
        #expect(inline == false)
    }

    @Test("left arrow key")
    func keyDisplay_leftArrow() {
        let e = makeKeyEvent(keyCode: 123)
        let (text, inline) = AppDelegate.keyDisplay(for: e)
        #expect(text == "←")
        #expect(inline == false)
    }

    @Test("right arrow key")
    func keyDisplay_rightArrow() {
        let e = makeKeyEvent(keyCode: 124)
        let (text, inline) = AppDelegate.keyDisplay(for: e)
        #expect(text == "→")
        #expect(inline == false)
    }

    @Test("F1 key")
    func keyDisplay_F1() {
        let e = makeKeyEvent(keyCode: 122)
        let (text, inline) = AppDelegate.keyDisplay(for: e)
        #expect(text == "<F1>")
        #expect(inline == false)
    }

    @Test("F5 key")
    func keyDisplay_F5() {
        let e = makeKeyEvent(keyCode: 96)
        let (text, inline) = AppDelegate.keyDisplay(for: e)
        #expect(text == "<F5>")
        #expect(inline == false)
    }

    @Test("F12 key")
    func keyDisplay_F12() {
        let e = makeKeyEvent(keyCode: 111)
        let (text, inline) = AppDelegate.keyDisplay(for: e)
        #expect(text == "<F12>")
        #expect(inline == false)
    }

    @Test("letter A is inline printable")
    func keyDisplay_letterA() {
        let e = makeKeyEvent(keyCode: 0, chars: "a")
        let (text, inline) = AppDelegate.keyDisplay(for: e)
        #expect(text == "a")
        #expect(inline == true)
    }

    @Test("unknown key code returns non-empty fallback")
    func keyDisplay_unknownKeyCode() {
        let e = makeKeyEvent(keyCode: 200, chars: "?")
        let (text, _) = AppDelegate.keyDisplay(for: e)
        #expect(!text.isEmpty)
    }
}
