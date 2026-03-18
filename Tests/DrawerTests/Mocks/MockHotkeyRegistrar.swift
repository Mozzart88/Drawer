import Carbon
@testable import DrawerCore

final class MockHotkeyRegistrar: HotkeyRegistrar {
    var registeredCount = 0
    var unregisteredCount = 0
    var handlerInstalled = false
    var handlerRemoved = false

    // Stable heap pointer used as a fake EventHotKeyRef (OpaquePointer)
    private let fakePtr: UnsafeMutablePointer<UInt8> = .allocate(capacity: 1)

    deinit { fakePtr.deallocate() }

    func registerHotKey(keyCode: UInt32, modifiers: UInt32, id: UInt32,
                        target: EventTargetRef?) -> EventHotKeyRef? {
        registeredCount += 1
        return OpaquePointer(fakePtr)
    }

    func unregisterHotKey(_ ref: EventHotKeyRef) {
        unregisteredCount += 1
    }

    func installEventHandler(target: EventTargetRef?,
                             handler: EventHandlerUPP?,
                             numTypes: UInt32,
                             list: UnsafePointer<EventTypeSpec>?,
                             userData: UnsafeMutableRawPointer?,
                             outRef: UnsafeMutablePointer<EventHandlerRef?>?) -> OSStatus {
        handlerInstalled = true
        return OSStatus(noErr)
    }

    func removeEventHandler(_ ref: EventHandlerRef) {
        handlerRemoved = true
    }

    func applicationEventTarget() -> EventTargetRef? {
        return nil
    }
}
