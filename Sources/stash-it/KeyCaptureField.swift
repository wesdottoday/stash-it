import AppKit
import SwiftUI
import Carbon.HIToolbox

struct KeyCaptureFieldRepresentable: NSViewRepresentable {
    @Binding var keyCode: UInt32
    @Binding var modifiers: UInt32

    func makeNSView(context: Context) -> KeyCaptureField {
        let view = KeyCaptureField()
        view.onChange = { kc, mods in
            keyCode = kc
            modifiers = mods
        }
        view.setHotkey(keyCode: keyCode, modifiers: modifiers)
        return view
    }

    func updateNSView(_ nsView: KeyCaptureField, context: Context) {
        nsView.setHotkey(keyCode: keyCode, modifiers: modifiers)
    }
}

final class KeyCaptureField: NSView {
    var onChange: ((UInt32, UInt32) -> Void)?

    private let label = NSTextField(labelWithString: "")
    private var currentKeyCode: UInt32 = 0
    private var currentModifiers: UInt32 = 0
    private var capturing = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    override var acceptsFirstResponder: Bool { true }
    override var canBecomeKeyView: Bool { true }
    override var isFlipped: Bool { false }

    override var intrinsicContentSize: NSSize {
        return NSSize(width: 180, height: 26)
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        // Any click in our bounds lands on us — never on the label subview —
        // so mouseDown reliably fires and focuses the field.
        let local = convert(point, from: superview)
        return bounds.contains(local) ? self : nil
    }

    private func setup() {
        wantsLayer = true
        layer?.cornerRadius = 5
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.separatorColor.cgColor
        layer?.backgroundColor = NSColor.textBackgroundColor.withAlphaComponent(0.4).cgColor

        label.font = .systemFont(ofSize: 13)
        label.alignment = .center
        label.backgroundColor = .clear
        label.isBezeled = false
        label.isEditable = false
        label.isSelectable = false
        // Letting the label swallow clicks would prevent mouseDown from firing.
        label.refusesFirstResponder = true
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 6),
            label.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -6),
        ])

        updateLabel()
    }

    override func mouseDown(with event: NSEvent) {
        // NSHostingController doesn't deliver gesture-recognizer events for arbitrary
        // SwiftUI-hosted NSViews reliably (the SwiftUI hit-test layer often consumes
        // the click before our recognizer fires). Override mouseDown directly.
        window?.makeFirstResponder(self)
    }

    func setHotkey(keyCode: UInt32, modifiers: UInt32) {
        // Avoid clobbering the in-progress label while the user is capturing.
        if capturing { return }
        currentKeyCode = keyCode
        currentModifiers = modifiers
        updateLabel()
    }

    private func updateLabel() {
        if capturing {
            label.stringValue = "Type a shortcut…"
            label.textColor = .secondaryLabelColor
        } else {
            label.stringValue = KeyCodeMapping.displayString(
                keyCode: currentKeyCode,
                modifiers: currentModifiers
            )
            label.textColor = .labelColor
        }
    }

    override func becomeFirstResponder() -> Bool {
        capturing = true
        layer?.borderColor = NSColor.controlAccentColor.cgColor
        updateLabel()
        return true
    }

    override func resignFirstResponder() -> Bool {
        capturing = false
        layer?.borderColor = NSColor.separatorColor.cgColor
        updateLabel()
        return true
    }

    override func keyDown(with event: NSEvent) {
        let keyCodeInt = Int(event.keyCode)
        if keyCodeInt == kVK_Escape {
            window?.makeFirstResponder(nil)
            return
        }
        // Ignore plain modifier-key presses on their own (Cmd, Shift, etc.).
        if keyCodeInt == kVK_Command || keyCodeInt == kVK_Option
            || keyCodeInt == kVK_Control || keyCodeInt == kVK_Shift
            || keyCodeInt == kVK_RightCommand || keyCodeInt == kVK_RightOption
            || keyCodeInt == kVK_RightControl || keyCodeInt == kVK_RightShift
            || keyCodeInt == kVK_Function {
            return
        }
        let mods = carbonMods(event.modifierFlags)
        // Require at least one non-shift modifier so the hotkey doesn't clash with typing.
        if (mods & ~UInt32(shiftKey)) == 0 {
            NSSound.beep()
            return
        }
        let kc = UInt32(event.keyCode)
        currentKeyCode = kc
        currentModifiers = mods
        onChange?(kc, mods)
        // Resign focus so the user sees the new value reflected (not "Type a shortcut…").
        window?.makeFirstResponder(nil)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        // While capturing, swallow key equivalents like Cmd+Q so they go through
        // keyDown as the chosen hotkey rather than triggering app commands.
        if capturing, window?.firstResponder === self {
            self.keyDown(with: event)
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    private func carbonMods(_ flags: NSEvent.ModifierFlags) -> UInt32 {
        var m: UInt32 = 0
        if flags.contains(.command) { m |= UInt32(cmdKey) }
        if flags.contains(.option) { m |= UInt32(optionKey) }
        if flags.contains(.control) { m |= UInt32(controlKey) }
        if flags.contains(.shift) { m |= UInt32(shiftKey) }
        return m
    }
}
