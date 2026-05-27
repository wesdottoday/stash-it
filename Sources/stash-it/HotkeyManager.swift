import AppKit
import Carbon.HIToolbox

final class HotkeyManager {
    var onTrigger: (() -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private let signature: OSType = 0x73746869 // 'sthi'
    private let id: UInt32 = 1

    init() {
        installEventHandler()
    }

    deinit {
        unregister()
        if let h = eventHandler {
            RemoveEventHandler(h)
        }
    }

    func register(keyCode: UInt32, modifiers: UInt32) {
        unregister()
        guard keyCode != 0, modifiers != 0 else { return }

        var ref: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: signature, id: id)
        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &ref
        )
        if status == noErr {
            hotKeyRef = ref
        }
    }

    func unregister() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
    }

    private func installEventHandler() {
        var spec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, event, userData) -> OSStatus in
                guard let userData = userData, let event = event else { return noErr }
                var hkID = EventHotKeyID()
                GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hkID
                )
                let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
                if hkID.signature == manager.signature && hkID.id == manager.id {
                    DispatchQueue.main.async { manager.onTrigger?() }
                }
                return noErr
            },
            1,
            &spec,
            selfPtr,
            &eventHandler
        )
    }
}
