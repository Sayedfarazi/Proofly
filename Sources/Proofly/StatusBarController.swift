import AppKit
import Combine

final class StatusBarController: NSObject, NSMenuDelegate {
    private let statusItem: NSStatusItem
    private let accessibilityStatusMenuItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let lastResultMenuItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let onOpenSettings: () -> Void
    private let onQuit: () -> Void
    private var activitySubscription: AnyCancellable?

    init(onOpenSettings: @escaping () -> Void, onQuit: @escaping () -> Void) {
        self.onOpenSettings = onOpenSettings
        self.onQuit = onQuit
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()

        let idleIcon = Self.makeMenuBarIcon()
        if let button = statusItem.button {
            button.image = idleIcon
            button.toolTip = "Proofly"
            button.setAccessibilityLabel("Proofly")
        }

        let menu = NSMenu()
        menu.delegate = self

        accessibilityStatusMenuItem.isEnabled = false
        menu.addItem(accessibilityStatusMenuItem)
        lastResultMenuItem.isEnabled = false
        menu.addItem(lastResultMenuItem)
        menu.addItem(.separator())

        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit Proofly", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
        activitySubscription = HotkeyManager.shared.$isTriggering.sink { [weak self] isWorking in
            self?.statusItem.button?.image = isWorking
                ? NSImage(systemSymbolName: "hourglass", accessibilityDescription: "Proofly is editing your selection")
                : idleIcon
        }
    }

    private static func makeMenuBarIcon() -> NSImage? {
        guard let url = Bundle.main.url(forResource: "MenuBarIconTemplate", withExtension: "png"),
              let image = NSImage(contentsOf: url) else {
            return NSImage(systemSymbolName: "text.magnifyingglass", accessibilityDescription: "Proofly")
        }
        image.size = NSSize(width: 20, height: 20)
        image.isTemplate = true
        image.accessibilityDescription = "Proofly"
        return image
    }

    func menuWillOpen(_ menu: NSMenu) {
        lastResultMenuItem.title = HotkeyManager.shared.registrationErrors.isEmpty
            ? HotkeyManager.shared.lastResult
            : "Shortcut unavailable — open Settings"
        accessibilityStatusMenuItem.title = AccessibilityPermission.isGranted
            ? "Accessibility access granted"
            : "Accessibility access needed — open Settings"
    }

    @objc private func openSettings() {
        onOpenSettings()
    }

    @objc private func quit() {
        onQuit()
    }
}
