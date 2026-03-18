import Carbon

protocol HotkeyRegistrar: AnyObject {
    func registerHotKey(keyCode: UInt32, modifiers: UInt32, id: UInt32,
                        target: EventTargetRef?) -> EventHotKeyRef?
    func unregisterHotKey(_ ref: EventHotKeyRef)
    func installEventHandler(target: EventTargetRef?,
                             handler: EventHandlerUPP?,
                             numTypes: UInt32,
                             list: UnsafePointer<EventTypeSpec>?,
                             userData: UnsafeMutableRawPointer?,
                             outRef: UnsafeMutablePointer<EventHandlerRef?>?) -> OSStatus
    func removeEventHandler(_ ref: EventHandlerRef)
    func applicationEventTarget() -> EventTargetRef?
}

final class CarbonHotkeyRegistrar: HotkeyRegistrar {
    func registerHotKey(keyCode: UInt32, modifiers: UInt32, id: UInt32,
                        target: EventTargetRef?) -> EventHotKeyRef? {
        let hotKeyID = EventHotKeyID(signature: OSType(0x4452_5752), id: id)  // 'DRWR'
        var hotKeyRef: EventHotKeyRef?
        RegisterEventHotKey(keyCode, modifiers, hotKeyID,
                            target ?? GetApplicationEventTarget(), 0, &hotKeyRef)
        return hotKeyRef
    }

    func unregisterHotKey(_ ref: EventHotKeyRef) {
        UnregisterEventHotKey(ref)
    }

    func installEventHandler(target: EventTargetRef?,
                             handler: EventHandlerUPP?,
                             numTypes: UInt32,
                             list: UnsafePointer<EventTypeSpec>?,
                             userData: UnsafeMutableRawPointer?,
                             outRef: UnsafeMutablePointer<EventHandlerRef?>?) -> OSStatus {
        return InstallEventHandler(target, handler, Int(numTypes), list, userData, outRef)
    }

    func removeEventHandler(_ ref: EventHandlerRef) {
        RemoveEventHandler(ref)
    }

    func applicationEventTarget() -> EventTargetRef? {
        return GetApplicationEventTarget()
    }
}
