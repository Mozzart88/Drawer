import Testing
import AppKit
@testable import DrawerCore

@Suite("HotkeyManager", .serialized)
@MainActor
struct HotkeyManagerTests {

    private func makeManager(registrar: MockHotkeyRegistrar = MockHotkeyRegistrar(),
                              toggleDrawing: @escaping () -> Void = {},
                              clearScreen: @escaping () -> Void = {},
                              toggleColorWheel: @escaping () -> Void = {},
                              toggleRecording: @escaping () -> Void = {},
                              toggleGreenScreen: @escaping () -> Void = {}) -> HotkeyManager {
        HotkeyManager(
            toggleDrawing: toggleDrawing,
            clearScreen: clearScreen,
            toggleColorWheel: toggleColorWheel,
            toggleRecording: toggleRecording,
            toggleGreenScreen: toggleGreenScreen,
            registrar: registrar
        )
    }

    @Test("init registers exactly 9 hotkeys")
    func initRegisters9Hotkeys() {
        let registrar = MockHotkeyRegistrar()
        let _ = makeManager(registrar: registrar)
        #expect(registrar.registeredCount == 9)
    }

    @Test("init installs event handler")
    func initInstallsEventHandler() {
        let registrar = MockHotkeyRegistrar()
        let _ = makeManager(registrar: registrar)
        #expect(registrar.handlerInstalled == true)
    }

    @Test("deinit unregisters all registered hotkeys")
    func deinitUnregistersAll() {
        let registrar = MockHotkeyRegistrar()
        var manager: HotkeyManager? = makeManager(registrar: registrar)
        let registered = registrar.registeredCount
        manager = nil  // trigger deinit
        #expect(registrar.unregisteredCount == registered)
    }

    @Test("toggleDrawing callback invoked directly")
    func toggleDrawingCallback_invocable() {
        var called = false
        let manager = makeManager(toggleDrawing: { called = true })
        manager.toggleDrawing?()
        #expect(called == true)
    }

    @Test("clearScreen callback invoked directly")
    func clearScreenCallback_invocable() {
        var called = false
        let manager = makeManager(clearScreen: { called = true })
        manager.clearScreen?()
        #expect(called == true)
    }

    @Test("toggleColorWheel callback invoked directly")
    func toggleColorWheelCallback_invocable() {
        var called = false
        let manager = makeManager(toggleColorWheel: { called = true })
        manager.toggleColorWheel?()
        #expect(called == true)
    }

    @Test("toggleRecording callback invoked directly")
    func toggleRecordingCallback_invocable() {
        var called = false
        let manager = makeManager(toggleRecording: { called = true })
        manager.toggleRecording?()
        #expect(called == true)
    }

    @Test("toggleGreenScreen callback invoked directly")
    func toggleGreenScreenCallback_invocable() {
        var called = false
        let manager = makeManager(toggleGreenScreen: { called = true })
        manager.toggleGreenScreen?()
        #expect(called == true)
    }

    @Test("teleprompter scroll up callback is settable and invocable")
    func teleprompterScrollUpCallback() {
        let manager = makeManager()
        var called = false
        manager.onTeleprompterScrollUp = { called = true }
        manager.onTeleprompterScrollUp?()
        #expect(called == true)
    }

    @Test("teleprompter auto-scroll toggle callback is settable and invocable")
    func teleprompterAutoScrollToggleCallback() {
        let manager = makeManager()
        var called = false
        manager.onTeleprompterToggleAutoScroll = { called = true }
        manager.onTeleprompterToggleAutoScroll?()
        #expect(called == true)
    }

    @Test("teleprompter scroll down callback is settable and invocable")
    func teleprompterScrollDownCallback() {
        let manager = makeManager()
        var called = false
        manager.onTeleprompterScrollDown = { called = true }
        manager.onTeleprompterScrollDown?()
        #expect(called == true)
    }

    @Test("teleprompter visibility toggle callback is settable and invocable")
    func teleprompterVisibilityToggleCallback() {
        let manager = makeManager()
        var called = false
        manager.onTeleprompterToggleVisibility = { called = true }
        manager.onTeleprompterToggleVisibility?()
        #expect(called == true)
    }

    @Test("shared reference is set after init")
    func sharedReferenceSet() {
        let manager = makeManager()
        #expect(HotkeyManager.shared === manager)
    }
}
