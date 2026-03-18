import AppKit
import Carbon

class HotkeyManager {
    private var hotKeyRefs: [EventHotKeyRef?] = []
    private var eventHandlerRef: EventHandlerRef?
    private let registrar: HotkeyRegistrar

    var toggleDrawing: (() -> Void)?
    var clearScreen: (() -> Void)?
    var toggleColorWheel: (() -> Void)?
    var toggleRecording: (() -> Void)?
    var toggleGreenScreen: (() -> Void)?
    var onTeleprompterScrollUp: (() -> Void)?
    var onTeleprompterToggleAutoScroll: (() -> Void)?
    var onTeleprompterScrollDown: (() -> Void)?
    var onTeleprompterToggleVisibility: (() -> Void)?

    init(toggleDrawing: @escaping () -> Void,
         clearScreen: @escaping () -> Void,
         toggleColorWheel: @escaping () -> Void,
         toggleRecording: @escaping () -> Void,
         toggleGreenScreen: @escaping () -> Void,
         registrar: HotkeyRegistrar = CarbonHotkeyRegistrar()) {
        self.toggleDrawing = toggleDrawing
        self.clearScreen = clearScreen
        self.toggleColorWheel = toggleColorWheel
        self.toggleRecording = toggleRecording
        self.toggleGreenScreen = toggleGreenScreen
        self.registrar = registrar

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
                case 4: HotkeyManager.shared?.toggleRecording?()
                case 5: HotkeyManager.shared?.toggleGreenScreen?()
                case 6: HotkeyManager.shared?.onTeleprompterScrollUp?()
                case 7: HotkeyManager.shared?.onTeleprompterToggleAutoScroll?()
                case 8: HotkeyManager.shared?.onTeleprompterScrollDown?()
                case 9: HotkeyManager.shared?.onTeleprompterToggleVisibility?()
                default: break
                }
            }
            return noErr
        }

        registrar.installEventHandler(
            target: registrar.applicationEventTarget(),
            handler: handler,
            numTypes: 1,
            list: &eventType,
            userData: nil,
            outRef: &eventHandlerRef
        )

        // F9 = kVK_F9 = 101, F10 = kVK_F10 = 109, F8 = kVK_F8 = 100, F7 = kVK_F7 = 98, F5 = kVK_F5 = 96
        // controlKey = 0x1000 = 4096
        let controlKey = UInt32(4096)
        let keys: [(UInt32, UInt32, UInt32)] = [
            (UInt32(kVK_F9), 0, 1),
            (UInt32(kVK_F10), 0, 2),
            (UInt32(kVK_F8), 0, 3),
            (UInt32(kVK_F7), 0, 4),
            (UInt32(kVK_F5), 0, 5),
            (UInt32(kVK_F7), controlKey, 6),   // Ctrl+F7 → teleprompter scroll up
            (UInt32(kVK_F8), controlKey, 7),   // Ctrl+F8 → teleprompter toggle auto-scroll
            (UInt32(kVK_F9), controlKey, 8),   // Ctrl+F9 → teleprompter scroll down
            (UInt32(kVK_F10), controlKey, 9),  // Ctrl+F10 → teleprompter toggle visibility
        ]

        for (keyCode, modifiers, id) in keys {
            let ref = registrar.registerHotKey(
                keyCode: keyCode,
                modifiers: modifiers,
                id: id,
                target: registrar.applicationEventTarget()
            )
            hotKeyRefs.append(ref)
        }
    }

    deinit {
        for ref in hotKeyRefs {
            if let ref = ref {
                registrar.unregisterHotKey(ref)
            }
        }
        if let handlerRef = eventHandlerRef {
            registrar.removeEventHandler(handlerRef)
        }
    }
}
