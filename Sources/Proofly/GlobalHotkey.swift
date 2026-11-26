import Carbon.HIToolbox
import AppKit

struct KeyCombo: Codable, Equatable {
    var keyCode: UInt32
    var carbonModifiers: UInt32

    var displayString: String {
        var symbols = ""
        if carbonModifiers & UInt32(controlKey) != 0 { symbols += "\u{2303}" }
        if carbonModifiers & UInt32(optionKey) != 0 { symbols += "\u{2325}" }
        if carbonModifiers & UInt32(shiftKey) != 0 { symbols += "\u{21E7}" }
        if carbonModifiers & UInt32(cmdKey) != 0 { symbols += "\u{2318}" }
        return symbols + KeyCodeNames.name(for: keyCode)
    }
}

struct HotkeyRegistrationError: LocalizedError {
    let status: OSStatus

    var errorDescription: String? {
        "Shortcut could not be registered (\(status)). Choose another shortcut or quit another copy of Proofly."
    }
}

final class HotkeyCenter {
    static let shared = HotkeyCenter()

    private var eventHandlerRef: EventHandlerRef?
    private var registrations: [UInt32: (ref: EventHotKeyRef, handler: () -> Void)] = [:]
    private let signature: FourCharCode = 0x50524F54
    private var nextID: UInt32 = 1

    private init() {}

    @discardableResult
    func register(_ combo: KeyCombo, handler: @escaping () -> Void) throws -> UInt32 {
        try installEventHandlerIfNeeded()

        let id = nextID
        nextID += 1

        let hotKeyID = EventHotKeyID(signature: signature, id: id)
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            combo.keyCode,
            combo.carbonModifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &ref
        )
        if status == noErr, let ref {
            registrations[id] = (ref, handler)
        } else {
            throw HotkeyRegistrationError(status: status)
        }
        return id
    }

    func unregister(_ id: UInt32) {
        if let entry = registrations[id] {
            UnregisterEventHotKey(entry.ref)
            registrations[id] = nil
        }
    }

    private func installEventHandlerIfNeeded() throws {
        guard eventHandlerRef == nil else { return }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, eventRef, userData in
                guard let eventRef, let userData else { return noErr }

                var hotKeyID = EventHotKeyID()
                let status = GetEventParameter(
                    eventRef,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )
                guard status == noErr else { return status }

                let center = Unmanaged<HotkeyCenter>.fromOpaque(userData).takeUnretainedValue()
                guard hotKeyID.signature == center.signature else { return OSStatus(eventNotHandledErr) }
                center.registrations[hotKeyID.id]?.handler()
                return noErr
            },
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandlerRef
        )
        guard status == noErr else { throw HotkeyRegistrationError(status: status) }
    }
}

enum KeyCodeNames {
    private static let names: [UInt32: String] = [
        UInt32(kVK_ANSI_A): "A", UInt32(kVK_ANSI_B): "B", UInt32(kVK_ANSI_C): "C",
        UInt32(kVK_ANSI_D): "D", UInt32(kVK_ANSI_E): "E", UInt32(kVK_ANSI_F): "F",
        UInt32(kVK_ANSI_G): "G", UInt32(kVK_ANSI_H): "H", UInt32(kVK_ANSI_I): "I",
        UInt32(kVK_ANSI_J): "J", UInt32(kVK_ANSI_K): "K", UInt32(kVK_ANSI_L): "L",
        UInt32(kVK_ANSI_M): "M", UInt32(kVK_ANSI_N): "N", UInt32(kVK_ANSI_O): "O",
        UInt32(kVK_ANSI_P): "P", UInt32(kVK_ANSI_Q): "Q", UInt32(kVK_ANSI_R): "R",
        UInt32(kVK_ANSI_S): "S", UInt32(kVK_ANSI_T): "T", UInt32(kVK_ANSI_U): "U",
        UInt32(kVK_ANSI_V): "V", UInt32(kVK_ANSI_W): "W", UInt32(kVK_ANSI_X): "X",
        UInt32(kVK_ANSI_Y): "Y", UInt32(kVK_ANSI_Z): "Z",
        UInt32(kVK_ANSI_0): "0", UInt32(kVK_ANSI_1): "1", UInt32(kVK_ANSI_2): "2",
        UInt32(kVK_ANSI_3): "3", UInt32(kVK_ANSI_4): "4", UInt32(kVK_ANSI_5): "5",
        UInt32(kVK_ANSI_6): "6", UInt32(kVK_ANSI_7): "7", UInt32(kVK_ANSI_8): "8",
        UInt32(kVK_ANSI_9): "9",
        UInt32(kVK_Space): "Space", UInt32(kVK_Return): "\u{21A9}",
        UInt32(kVK_Tab): "\u{21E5}", UInt32(kVK_Escape): "\u{238B}"
    ]

    static func name(for keyCode: UInt32) -> String {
        names[keyCode] ?? "Key \(keyCode)"
    }
}
