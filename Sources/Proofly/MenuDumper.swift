import AppKit
import ApplicationServices

enum MenuDumper {
    static func run() {
        guard AccessibilityPermission.isGranted else {
            print("Accessibility permission not granted. Grant it in System Settings > Privacy & Security > Accessibility, then re-run.")
            AccessibilityPermission.requestPrompt()
            return
        }

        guard let frontApp = NSWorkspace.shared.frontmostApplication else {
            print("No frontmost app.")
            return
        }

        print("Frontmost app: \(frontApp.localizedName ?? "?") (pid \(frontApp.processIdentifier))")

        let appElement = AXUIElementCreateApplication(frontApp.processIdentifier)
        guard let menuBar: AXUIElement = axAttribute(appElement, kAXMenuBarAttribute as String) else {
            print("Could not read menu bar.")
            return
        }

        for topItem in axChildren(menuBar) {
            let title = axTitle(topItem) ?? "?"
            print("- \(title)")
            guard let submenu = axSubmenu(topItem) else { continue }
            for item in axChildren(submenu) {
                let itemTitle = axTitle(item) ?? "(separator)"
                let cmd = axCmdChar(item).map { " [cmd+\($0)]" } ?? ""
                let hasSubmenu = axSubmenu(item) != nil ? " >" : ""
                print("    - \(itemTitle)\(cmd)\(hasSubmenu)")
                if let sub = axSubmenu(item) {
                    for subItem in axChildren(sub) {
                        let subTitle = axTitle(subItem) ?? "(separator)"
                        print("        - \(subTitle)")
                    }
                }
            }
        }
    }
}
