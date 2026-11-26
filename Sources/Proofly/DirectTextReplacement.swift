import AppKit
import ApplicationServices

struct SelectedTextSnapshot {
    let app: AXUIElement
    let element: AXUIElement
    let pid: pid_t
    let range: CFRange
    let text: String
    let document: String?
    let canReplace: Bool
}

@available(macOS 26.0, *)
enum DirectTextReplacement {
    @MainActor
    static func trigger(_ action: WritingToolsAction, app: AXUIElement, pid: pid_t) async -> WritingToolsTriggerResult {
        guard let focused: AXUIElement = axAttribute(app, kAXFocusedUIElementAttribute as String),
              let selectedText: String = axAttribute(focused, kAXSelectedTextAttribute as String),
              !selectedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let range = selectedRange(in: focused) else { return .noSelection }
        var canReplace = DarwinBoolean(false)
        AXUIElementIsAttributeSettable(focused, kAXSelectedTextAttribute as CFString, &canReplace)
        let originalDocument: String? = axAttribute(focused, kAXValueAttribute as String)
        let snapshot = SelectedTextSnapshot(app: app, element: focused, pid: pid, range: range,
                                            text: selectedText, document: originalDocument, canReplace: canReplace.boolValue)

        let revised: String
        do {
            revised = try await OnDeviceTextEditor.revise(selectedText, action: action)
        } catch let error as TextEditingError {
            return .editingFailed(error.message)
        } catch {
            return .editingFailed("The on-device model could not finish. Your text was not changed. Try a shorter passage or try again later.")
        }

        WritingPreviewController.shared.show(action: action, original: snapshot, revised: revised)
        return .previewReady
    }

    @MainActor
    static func insert(_ revised: String, into snapshot: SelectedTextSnapshot) async -> WritingToolsTriggerResult {
        guard AccessibilityPermission.isGranted else { return .notTrusted }
        guard snapshot.canReplace else { return .editingFailed("This app does not support direct insertion. Use Copy and paste the revision into your app.") }
        guard !revised.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .editingFailed("The revision is empty. Enter some text before inserting.")
        }
        guard let target = NSRunningApplication(processIdentifier: snapshot.pid), !target.isTerminated else {
            return .editingFailed("The original app is no longer running. Use Copy to keep your revision.")
        }
        target.activate(options: [])
        for _ in 0..<20 {
            if NSWorkspace.shared.frontmostApplication?.processIdentifier == snapshot.pid { break }
            try? await Task.sleep(for: .milliseconds(50))
        }
        guard NSWorkspace.shared.frontmostApplication?.processIdentifier == snapshot.pid else { return .targetChanged }
        guard let currentFocus: AXUIElement = axAttribute(snapshot.app, kAXFocusedUIElementAttribute as String),
              CFEqual(currentFocus, snapshot.element),
              let currentRange = selectedRange(in: snapshot.element),
              currentRange.location == snapshot.range.location, currentRange.length == snapshot.range.length,
              let currentText: String = axAttribute(snapshot.element, kAXSelectedTextAttribute as String),
              currentText == snapshot.text else { return .selectionChanged }
        let currentDocument: String? = axAttribute(snapshot.element, kAXValueAttribute as String)
        guard currentDocument == snapshot.document else { return .selectionChanged }
        guard revised != snapshot.text else { return .unchanged }

        let result = AXUIElementSetAttributeValue(snapshot.element, kAXSelectedTextAttribute as CFString, revised as CFString)
        guard result == .success else { return .actionFailed(result.rawValue) }

        if let originalDocument = snapshot.document {
            let document = originalDocument as NSString
            let range = snapshot.range
            guard range.location >= 0, range.location <= document.length,
                  range.length <= document.length - range.location else { return .replacementUnverified }
            let expected = document.replacingCharacters(in: NSRange(location: range.location, length: range.length), with: revised)
            for _ in 0..<10 {
                let updated: String? = axAttribute(snapshot.element, kAXValueAttribute as String)
                if updated == expected { return .textReplaced }
                try? await Task.sleep(for: .milliseconds(50))
            }
        } else {
            let updatedSelection: String? = axAttribute(snapshot.element, kAXSelectedTextAttribute as String)
            if updatedSelection == revised { return .textReplaced }
        }
        return .replacementUnverified
    }

    private static func selectedRange(in element: AXUIElement) -> CFRange? {
        guard let value: AXValue = axAttribute(element, kAXSelectedTextRangeAttribute as String),
              AXValueGetType(value) == .cfRange else { return nil }
        var range = CFRange()
        guard AXValueGetValue(value, .cfRange, &range), range.location >= 0, range.length > 0 else { return nil }
        return range
    }
}
