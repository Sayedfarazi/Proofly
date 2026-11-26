import AppKit
import Combine

final class HotkeyManager: ObservableObject {
    static let shared = HotkeyManager()

    @Published private var combos: [WritingToolsAction: KeyCombo] = [:]
    @Published private(set) var registrationErrors: [WritingToolsAction: String] = [:]
    @Published private(set) var lastResult = "Select text in another app, then press a shortcut."
    private var registeredIDs: [WritingToolsAction: UInt32] = [:]
    @Published private(set) var isTriggering = false
    private var isRecording = false

    private init() {
        for action in WritingToolsAction.allCases {
            combos[action] = Self.loadCombo(for: action) ?? action.defaultCombo
        }
    }

    func start() {
        for action in WritingToolsAction.allCases where registeredIDs[action] == nil {
            registerHotkey(for: action)
        }
    }

    func combo(for action: WritingToolsAction) -> KeyCombo {
        combos[action] ?? action.defaultCombo
    }

    func updateCombo(_ combo: KeyCombo, for action: WritingToolsAction) {
        guard !WritingToolsAction.allCases.contains(where: { $0 != action && self.combo(for: $0) == combo }) else {
            lastResult = "That shortcut is already assigned to another Proofly action."
            return
        }
        if self.combo(for: action) == combo, registeredIDs[action] != nil { return }
        do {
            let newID = try HotkeyCenter.shared.register(combo) { [weak self] in self?.handleTrigger(action) }
            if let oldID = registeredIDs[action] { HotkeyCenter.shared.unregister(oldID) }
            registeredIDs[action] = newID
            combos[action] = combo
            registrationErrors[action] = nil
            Self.saveCombo(combo, for: action)
            lastResult = "\(action.displayName) shortcut saved."
        } catch {
            lastResult = error.localizedDescription
        }
    }

    func setRecording(_ recording: Bool) {
        guard isRecording != recording else { return }
        isRecording = recording
        if recording {
            for identifier in registeredIDs.values { HotkeyCenter.shared.unregister(identifier) }
            registeredIDs.removeAll()
        } else {
            start()
        }
    }

    private func registerHotkey(for action: WritingToolsAction) {
        do {
            registeredIDs[action] = try HotkeyCenter.shared.register(combo(for: action)) { [weak self] in
                self?.handleTrigger(action)
            }
            registrationErrors[action] = nil
        } catch {
            registrationErrors[action] = error.localizedDescription
        }
    }

    private func handleTrigger(_ action: WritingToolsAction) {
        guard !isTriggering, !isRecording else { return }
        isTriggering = true
        lastResult = "\(action.displayName) is processing your selected text…"
        Task { @MainActor in
            defer { isTriggering = false }
            let result = await WritingToolsAutomator.trigger(action)
            lastResult = result.message(for: action)
            if case .notTrusted = result { AccessibilityPermission.requestPrompt() }
            if !result.succeeded { NSSound.beep() }
        }
    }

    private static func defaultsKey(for action: WritingToolsAction) -> String {
        "hotkeyCombo.\(action.rawValue)"
    }

    private static func loadCombo(for action: WritingToolsAction) -> KeyCombo? {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey(for: action)) else { return nil }
        return try? JSONDecoder().decode(KeyCombo.self, from: data)
    }

    private static func saveCombo(_ combo: KeyCombo, for action: WritingToolsAction) {
        if let data = try? JSONEncoder().encode(combo) {
            UserDefaults.standard.set(data, forKey: defaultsKey(for: action))
        }
    }
}
