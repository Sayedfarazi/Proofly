import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?
    private var settingsWindowController: NSWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusBarController = StatusBarController(
            onOpenSettings: { [weak self] in self?.showSettings() },
            onQuit: { NSApp.terminate(nil) }
        )

        HotkeyManager.shared.start()

        if !AccessibilityPermission.isGranted {
            showSettings()
        }
    }

    func showSettings() {
        if settingsWindowController == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 460, height: 490),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.title = "Proofly Settings"
            window.contentView = NSHostingView(rootView: SettingsView())
            window.center()
            window.isReleasedWhenClosed = false
            settingsWindowController = NSWindowController(window: window)
        }
        settingsWindowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
