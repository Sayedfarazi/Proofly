import AppKit
import SwiftUI
import Carbon.HIToolbox

final class ShortcutRecorderNSView: NSView {
    var combo: KeyCombo
    private let onChange: (KeyCombo) -> Void
    private var isRecording = false
    private let label = NSTextField(labelWithString: "")

    init(combo: KeyCombo, onChange: @escaping (KeyCombo) -> Void) {
        self.combo = combo
        self.onChange = onChange
        super.init(frame: .zero)

        wantsLayer = true
        layer?.cornerRadius = 6
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.separatorColor.cgColor

        label.alignment = .center
        label.font = .systemFont(ofSize: 13)
        addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])

        updateLabel()
    }

    required init?(coder: NSCoder) { fatalError("unsupported") }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        NotificationCenter.default.removeObserver(self, name: NSWindow.didResignKeyNotification, object: window)
        finishRecording()
        if let newWindow {
            NotificationCenter.default.addObserver(self, selector: #selector(finishRecording), name: NSWindow.didResignKeyNotification, object: newWindow)
        }
        super.viewWillMove(toWindow: newWindow)
    }

    @objc private func finishRecording() {
        guard isRecording else { return }
        isRecording = false
        HotkeyManager.shared.setRecording(false)
        window?.makeFirstResponder(nil)
        updateLabel()
    }

    override var intrinsicContentSize: NSSize { NSSize(width: 140, height: 24) }
    override var acceptsFirstResponder: Bool { true }

    override func becomeFirstResponder() -> Bool {
        isRecording = true
        HotkeyManager.shared.setRecording(true)
        updateLabel()
        return super.becomeFirstResponder()
    }

    override func resignFirstResponder() -> Bool {
        isRecording = false
        HotkeyManager.shared.setRecording(false)
        updateLabel()
        return super.resignFirstResponder()
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard isRecording else { return super.performKeyEquivalent(with: event) }
        keyDown(with: event)
        return true
    }

    override func keyDown(with event: NSEvent) {
        guard isRecording else { return }

        if event.keyCode == UInt16(kVK_Escape) {
            window?.makeFirstResponder(nil)
            return
        }

        var carbonMods: UInt32 = 0
        let flags = event.modifierFlags
        if flags.contains(.control) { carbonMods |= UInt32(controlKey) }
        if flags.contains(.option) { carbonMods |= UInt32(optionKey) }
        if flags.contains(.shift) { carbonMods |= UInt32(shiftKey) }
        if flags.contains(.command) { carbonMods |= UInt32(cmdKey) }

        guard carbonMods & UInt32(cmdKey | controlKey | optionKey) != 0 else { return }

        let newCombo = KeyCombo(keyCode: UInt32(event.keyCode), carbonModifiers: carbonMods)
        combo = newCombo
        onChange(newCombo)
        window?.makeFirstResponder(nil)
    }

    func updateLabel() {
        label.stringValue = isRecording ? "Recording\u{2026}" : combo.displayString
        layer?.borderColor = (isRecording ? NSColor.controlAccentColor : NSColor.separatorColor).cgColor
    }
}

struct ShortcutRecorder: NSViewRepresentable {
    @Binding var combo: KeyCombo

    func makeNSView(context: Context) -> ShortcutRecorderNSView {
        ShortcutRecorderNSView(combo: combo) { newCombo in
            combo = newCombo
        }
    }

    func updateNSView(_ nsView: ShortcutRecorderNSView, context: Context) {
        nsView.combo = combo
        nsView.updateLabel()
    }
}
