import AppKit
import ApplicationServices

enum AccessibilityPermission {
    static var isGranted: Bool {
        AXIsProcessTrusted()
    }

    @discardableResult
    static func requestPrompt() -> Bool {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        return AXIsProcessTrustedWithOptions(options)
    }

    static func openSystemSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
}
