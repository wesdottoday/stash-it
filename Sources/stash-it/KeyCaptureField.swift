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
    override var isFlipped: Bool { false }

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
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])

        let click = NSClickGestureRecognizer(target: self, action: #selector(focusSelf))
        addGestureRecognizer(click)
        updateLabel()
    }

    @objc private func focusSelf() {
        window?.makeFirstResponder(self)
    }

    func setHotkey(keyCode: UInt32, modifiers: UInt32) {
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
        if Int(event.keyCode) == kVK_Escape {
            window?.makeFirstResponder(nil)
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
        updateLabel()
        window?.makeFirstResponder(nil)
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
