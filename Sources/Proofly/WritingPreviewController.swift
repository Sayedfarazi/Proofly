import AppKit
import SwiftUI

@available(macOS 26.0, *)
@MainActor
final class WritingPreviewController {
    static let shared = WritingPreviewController()
    private var windows: [NSWindowController] = []

    func show(action: WritingToolsAction, original: SelectedTextSnapshot, revised: String) {
        windows.removeAll { $0.window?.isVisible != true }
        let model = WritingPreviewModel(action: action, original: original, revised: revised)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 510),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered, defer: false
        )
        window.title = "Proofly — \(action.displayName)"
        window.contentMinSize = NSSize(width: 580, height: 400)
        window.contentView = NSHostingView(rootView: WritingPreviewView(model: model))
        window.isReleasedWhenClosed = false
        window.center()
        model.close = { [weak window] in window?.close() }
        model.showError = { [weak window] in
            NSApp.activate(ignoringOtherApps: true)
            window?.makeKeyAndOrderFront(nil)
        }
        let controller = NSWindowController(window: window)
        windows.append(controller)
        controller.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}

@available(macOS 26.0, *)
@MainActor
final class WritingPreviewModel: ObservableObject {
    let action: WritingToolsAction
    let original: SelectedTextSnapshot
    @Published var revised: String
    @Published var status: String
    @Published var isInserting = false
    var close: () -> Void = {}
    var showError: () -> Void = {}

    init(action: WritingToolsAction, original: SelectedTextSnapshot, revised: String) {
        self.action = action
        self.original = original
        self.revised = revised
        status = revised == original.text ? "No changes were needed. You can still copy the text." : "Your original text has not been changed."
        if !original.canReplace { status = "Use Copy to paste the revision into your app. Direct insertion is unavailable here." }
    }

    func copy() {
        NSPasteboard.general.clearContents()
        if NSPasteboard.general.setString(revised, forType: .string) {
            status = "Copied. Your original text has not been changed."
        } else {
            status = "Could not copy the revision. Select the revised text and copy it manually."
        }
    }

    func insert() {
        guard !isInserting else { return }
        isInserting = true
        Task { @MainActor in
            let result = await DirectTextReplacement.insert(revised, into: original)
            isInserting = false
            status = result.message(for: action)
            if result.succeeded {
                close()
            } else {
                showError()
            }
        }
    }
}

@available(macOS 26.0, *)
struct WritingPreviewView: View {
    @ObservedObject var model: WritingPreviewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(model.action == .proofread ? "Review your proofread text" : "Review your rewritten text")
                .font(.title2).bold()
            Text("Compare the versions, then copy or insert the revision. You can also edit it here.")
                .foregroundStyle(.secondary)
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Original").font(.headline)
                    ScrollView {
                        Text(model.original.text)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                            .padding(10)
                    }
                    .background(Color(nsColor: .textBackgroundColor))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.3)))
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("Revised").font(.headline)
                    TextEditor(text: $model.revised)
                        .font(.body)
                        .padding(6)
                        .accessibilityLabel("Revised text")
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.3)))
                }
            }
            Text(model.status)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Button("Close", action: model.close).keyboardShortcut(.cancelAction)
                Spacer()
                Button("Copy", action: model.copy)
                Button(model.isInserting ? "Inserting…" : "Insert", action: model.insert)
                    .keyboardShortcut(.return, modifiers: [.command])
                    .disabled(!model.original.canReplace || model.revised.isEmpty || model.isInserting)
            }
            .disabled(model.isInserting)
        }
        .padding(24)
        .frame(minWidth: 532, minHeight: 352)
    }
}
