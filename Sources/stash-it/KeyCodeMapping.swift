import AppKit
import Carbon.HIToolbox

enum KeyCodeMapping {
    static func displayString(keyCode: UInt32, modifiers: UInt32) -> String {
        if keyCode == 0 && modifiers == 0 { return "Click to set…" }
        var s = ""
        if modifiers & UInt32(controlKey) != 0 { s += "⌃" }
        if modifiers & UInt32(optionKey) != 0 { s += "⌥" }
        if modifiers & UInt32(shiftKey) != 0 { s += "⇧" }
        if modifiers & UInt32(cmdKey) != 0 { s += "⌘" }
        s += keyName(for: keyCode)
        return s
    }

    static func keyName(for keyCode: UInt32) -> String {
        switch Int(keyCode) {
        case kVK_Return: return "↩"
        case kVK_Tab: return "⇥"
        case kVK_Space: return "Space"
        case kVK_Delete: return "⌫"
        case kVK_Escape: return "⎋"
        case kVK_ForwardDelete: return "⌦"
        case kVK_LeftArrow: return "←"
        case kVK_RightArrow: return "→"
        case kVK_UpArrow: return "↑"
        case kVK_DownArrow: return "↓"
        case kVK_F1: return "F1"
        case kVK_F2: return "F2"
        case kVK_F3: return "F3"
        case kVK_F4: return "F4"
        case kVK_F5: return "F5"
        case kVK_F6: return "F6"
        case kVK_F7: return "F7"
        case kVK_F8: return "F8"
        case kVK_F9: return "F9"
        case kVK_F10: return "F10"
        case kVK_F11: return "F11"
        case kVK_F12: return "F12"
        case kVK_ANSI_Slash: return "/"
        case kVK_ANSI_Period: return "."
        case kVK_ANSI_Comma: return ","
        case kVK_ANSI_Semicolon: return ";"
        case kVK_ANSI_Quote: return "'"
        case kVK_ANSI_LeftBracket: return "["
        case kVK_ANSI_RightBracket: return "]"
        case kVK_ANSI_Backslash: return "\\"
        case kVK_ANSI_Grave: return "`"
        case kVK_ANSI_Minus: return "-"
        case kVK_ANSI_Equal: return "="
        default:
            return translate(keyCode: keyCode) ?? "Key \(keyCode)"
        }
    }

    private static func translate(keyCode: UInt32) -> String? {
        guard let source = TISCopyCurrentASCIICapableKeyboardLayoutInputSource()?.takeRetainedValue()
        else { return nil }
        let dataPtr = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData)
        guard let dataPtr = dataPtr else { return nil }
        let cfData = Unmanaged<CFData>.fromOpaque(dataPtr).takeUnretainedValue()
        let bytes = CFDataGetBytePtr(cfData)
        let layout = unsafeBitCast(bytes, to: UnsafePointer<UCKeyboardLayout>.self)

        var deadKeyState: UInt32 = 0
        var length: Int = 0
        var chars = [UniChar](repeating: 0, count: 4)
        let noDeadKeysMask: OptionBits = 1 << kUCKeyTranslateNoDeadKeysBit
        let status = UCKeyTranslate(
            layout,
            UInt16(keyCode),
            UInt16(kUCKeyActionDisplay),
            0,
            UInt32(LMGetKbdType()),
            noDeadKeysMask,
            &deadKeyState,
            chars.count,
            &length,
            &chars
        )
        guard status == noErr, length > 0 else { return nil }
        return String(utf16CodeUnits: chars, count: length).uppercased()
    }
}
