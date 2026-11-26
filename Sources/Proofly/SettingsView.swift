import SwiftUI
import ServiceManagement

private typealias ViewState<Value> = State<Value>

struct SettingsView: View {
    @ViewState private var isAccessibilityGranted = AccessibilityPermission.isGranted
    @ViewState private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @ObservedObject private var hotkeys = HotkeyManager.shared
    @ViewState private var loginError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Proofly").font(.title2).bold()
            Text("by Sayed Farazi")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("Select text, then press a shortcut. Proofly opens Apple's Writing Tools popup when available. Otherwise, on macOS 26 or later, it prepares an on-device preview with Copy and Insert. Switching is automatic; Siri does not need to be open.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            ForEach(WritingToolsAction.allCases, id: \.self) { action in
                shortcutRow(action: action)
            }

            Divider()

            HStack {
                Circle()
                    .fill(isAccessibilityGranted ? Color.green : Color.orange)
                    .frame(width: 8, height: 8)
                Text(isAccessibilityGranted ? "Accessibility access granted" : "Accessibility access needed")
                Spacer()
                if !isAccessibilityGranted {
                    Button("Open Settings…") {
                        AccessibilityPermission.requestPrompt()
                        AccessibilityPermission.openSystemSettings()
                    }
                }
            }

            Toggle("Launch at login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, newValue in
                    guard newValue != (SMAppService.mainApp.status == .enabled) else { return }
                    do {
                        try newValue ? SMAppService.mainApp.register() : SMAppService.mainApp.unregister()
                        loginError = SMAppService.mainApp.status == .requiresApproval
                            ? "Approve Proofly in System Settings > General > Login Items." : nil
                    } catch {
                        loginError = error.localizedDescription
                    }
                    launchAtLogin = SMAppService.mainApp.status == .enabled
                }

            if let loginError {
                Text(loginError).font(.caption).foregroundStyle(.orange)
            }
            Divider()
            Text("Last shortcut result").font(.headline)
            Text(hotkeys.lastResult)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
        .padding(20)
        .frame(width: 460, height: 490)
        .onAppear(perform: refreshAccessibilityStatus)
        .task {
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(1)) } catch { return }
                refreshAccessibilityStatus()
            }
        }
    }

    @ViewBuilder
    private func shortcutRow(action: WritingToolsAction) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("\(action.displayName):").frame(width: 80, alignment: .leading)
                ShortcutRecorder(combo: Binding(
                    get: { hotkeys.combo(for: action) },
                    set: { hotkeys.updateCombo($0, for: action) }
                ))
                    .frame(width: 140, height: 24)
            }
            if let error = hotkeys.registrationErrors[action] {
                Text(error).font(.caption).foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func refreshAccessibilityStatus() {
        isAccessibilityGranted = AccessibilityPermission.isGranted
    }
}
