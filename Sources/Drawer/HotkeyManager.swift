import AppKit
import Carbon

class HotkeyManager {
    private var hotKeyRefs: [EventHotKeyRef?] = []
    private var eventHandlerRef: EventHandlerRef?

    var toggleDrawing: (() -> Void)?
    var clearScreen: (() -> Void)?
    var toggleColorWheel: (() -> Void)?

    init(toggleDrawing: @escaping () -> Void,
         clearScreen: @escaping () -> Void,
         toggleColorWheel: @escaping () -> Void) {
        self.toggleDrawing = toggleDrawing
        self.clearScreen = clearScreen
        self.toggleColorWheel = toggleColorWheel

        HotkeyManager.shared = self
        registerHotkeys()
    }

    static weak var shared: HotkeyManager?

    private func registerHotkeys() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))

        let handler: EventHandlerUPP = { _, event, _ -> OSStatus in
            var hotKeyID = EventHotKeyID()
            GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID
            )
            DispatchQueue.main.async {
                switch hotKeyID.id {
                case 1: HotkeyManager.shared?.toggleDrawing?()
                case 2: HotkeyManager.shared?.clearScreen?()
                case 3: HotkeyManager.shared?.toggleColorWheel?()
                default: break
                }
            }
            return noErr
        }

        InstallEventHandler(
            GetApplicationEventTarget(),
            handler,
            1,
            &eventType,
            nil,
            &eventHandlerRef
        )

        // F9 = kVK_F9 = 101, F10 = kVK_F10 = 109, F8 = kVK_F8 = 100
        let keys: [(UInt32, UInt32, UInt32)] = [
            (UInt32(kVK_F9), 0, 1),
            (UInt32(kVK_F10), 0, 2),
            (UInt32(kVK_F8), 0, 3)
        ]

        for (keyCode, modifiers, id) in keys {
            let hotKeyID = EventHotKeyID(signature: OSType(0x4452_5752), id: id)  // 'DRWR'
            var hotKeyRef: EventHotKeyRef?
            RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
            hotKeyRefs.append(hotKeyRef)
        }
    }

    deinit {
        for ref in hotKeyRefs {
            if let ref = ref {
                UnregisterEventHotKey(ref)
            }
        }
        if let handlerRef = eventHandlerRef {
            RemoveEventHandler(handlerRef)
        }
    }
}
