import AppKit
import ApplicationServices

enum WritingToolsTriggerResult {
    case success
    case notTrusted
    case noFrontmostApp
    case menuItemNotFound(String)
    case menuItemDisabled
    case actionFailed(Int32)
    case noSelection
    case targetChanged
    case textReplaced
    case unchanged
    case selectionChanged
    case replacementUnverified
    case editingFailed(String)
    case previewReady

    var succeeded: Bool {
        switch self {
        case .success, .textReplaced, .unchanged, .previewReady: return true
        default: return false
        }
    }

    func message(for action: WritingToolsAction) -> String {
        switch self {
        case .success: return "\(action.displayName) requested. Review the result in your app."
        case .notTrusted: return "Accessibility access is needed. Enable Proofly in System Settings; after a rebuild you may need to remove and re-add it."
        case .noFrontmostApp: return "Switch to the app containing your text, select it, and try again."
        case .menuItemNotFound(let detail): return "Writing Tools is unavailable here (\(detail)). Select editable text in a supported app and check Apple Intelligence settings."
        case .menuItemDisabled: return "This command is disabled. Select editable text and check Apple Intelligence availability."
        case .actionFailed(let code): return "macOS could not perform the action (\(code)). Reselect your text and try again."
        case .noSelection: return "Select the text you want to \(action.rawValue), then press the shortcut again."
        case .targetChanged: return "The active app changed. Select your text and try again."
        case .textReplaced: return "\(action.displayName) finished. Your selected text was updated."
        case .unchanged: return "Finished. No changes were needed."
        case .selectionChanged: return "The original text or selection changed. Nothing was replaced. Use Copy, or select the passage and generate a new preview."
        case .replacementUnverified: return "The app accepted the edit, but Proofly could not verify it. Check your text before trying again."
        case .editingFailed(let message): return message
        case .previewReady: return "Your revision is ready. Choose Copy or Insert in the preview."
        }
    }
}

enum WritingToolsAutomator {
    @MainActor
    static func trigger(_ action: WritingToolsAction) async -> WritingToolsTriggerResult {
        guard AccessibilityPermission.isGranted else { return .notTrusted }

        guard let frontApp = NSWorkspace.shared.frontmostApplication,
              frontApp.processIdentifier != ProcessInfo.processInfo.processIdentifier else {
            return .noFrontmostApp
        }

        let appElement = AXUIElementCreateApplication(frontApp.processIdentifier)
        AXUIElementSetMessagingTimeout(appElement, 1)

        guard let menuBar: AXUIElement = axAttribute(appElement, kAXMenuBarAttribute as String) else {
            return await previewFallback(action, app: appElement, pid: frontApp.processIdentifier, missing: "menu bar")
        }

        let topLevelItems = axChildren(menuBar)

        guard let editItems = findEditMenuItems(in: topLevelItems) else {
            return await previewFallback(action, app: appElement, pid: frontApp.processIdentifier, missing: "Edit menu")
        }

        guard let writingToolsItem = findWritingToolsItem(in: editItems) else {
            return await previewFallback(action, app: appElement, pid: frontApp.processIdentifier, missing: "Writing Tools submenu")
        }

        guard let writingToolsSubmenu = axSubmenu(writingToolsItem) else {
            return await previewFallback(action, app: appElement, pid: frontApp.processIdentifier, missing: "Writing Tools submenu contents")
        }

        let writingToolsChildren = namedChildren(of: writingToolsSubmenu)

        guard let targetItem = findItem(for: action, in: writingToolsChildren) else {
            return await previewFallback(action, app: appElement, pid: frontApp.processIdentifier, missing: "\(action.displayName) item")
        }

        guard axEnabled(targetItem) else {
            return .menuItemDisabled
        }

        guard NSWorkspace.shared.frontmostApplication?.processIdentifier == frontApp.processIdentifier else {
            return .targetChanged
        }

        let result = AXUIElementPerformAction(targetItem, kAXPressAction as CFString)
        return result == .success ? .success : .actionFailed(result.rawValue)
    }

    @MainActor
    private static func previewFallback(_ action: WritingToolsAction, app: AXUIElement, pid: pid_t, missing: String) async -> WritingToolsTriggerResult {
        guard NSWorkspace.shared.frontmostApplication?.processIdentifier == pid else { return .targetChanged }
        if #available(macOS 26.0, *) {
            return await DirectTextReplacement.trigger(action, app: app, pid: pid)
        }
        return .menuItemNotFound(missing)
    }

    private static func findEditMenuItems(in topLevelItems: [AXUIElement]) -> [AXUIElement]? {
        for item in topLevelItems {
            guard let submenu = axSubmenu(item) else { continue }
            let children = axChildren(submenu)
            let hasUndo = children.contains { axCmdChar($0)?.lowercased() == "z" }
            if hasUndo || axTitle(item) == "Edit" {
                return children
            }
        }
        return nil
    }

    private static func findWritingToolsItem(in editItems: [AXUIElement]) -> AXUIElement? {
        let named = namedChildren(of: editItems)

        if let exact = named.first(where: { MenuLocaleTable.writingToolsTitles.contains($0.title) }) {
            return exact.element
        }

        for (element, _) in named {
            guard let submenu = axSubmenu(element) else { continue }
            let subChildren = namedChildren(of: submenu)
            let titles = Set(subChildren.map(\.title))
            if !titles.isDisjoint(with: MenuLocaleTable.proofreadTitles),
               !titles.isDisjoint(with: MenuLocaleTable.rewriteTitles) {
                return element
            }
        }
        return nil
    }

    private static func findItem(
        for action: WritingToolsAction,
        in children: [(element: AXUIElement, title: String)]
    ) -> AXUIElement? {
        children.first(where: { action.titles.contains($0.title) })?.element
    }

    private static func namedChildren(of element: AXUIElement) -> [(element: AXUIElement, title: String)] {
        axChildren(element).compactMap { child in
            guard let title = axTitle(child), !title.isEmpty else { return nil }
            return (child, title)
        }
    }

    private static func namedChildren(of elements: [AXUIElement]) -> [(element: AXUIElement, title: String)] {
        elements.compactMap { child in
            guard let title = axTitle(child), !title.isEmpty else { return nil }
            return (child, title)
        }
    }

}
