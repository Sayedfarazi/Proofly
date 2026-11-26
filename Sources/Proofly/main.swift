import AppKit

if let processIndex = CommandLine.arguments.firstIndex(of: "--process-text") {
    guard CommandLine.arguments.count > processIndex + 1,
          let action = WritingToolsAction(rawValue: CommandLine.arguments[processIndex + 1]) else {
        print("Usage: Proofly --process-text proofread|rewrite < input.txt")
        exit(2)
    }
    let input = String(data: FileHandle.standardInput.readDataToEndOfFile(), encoding: .utf8) ?? ""
    Task {
        do {
            guard #available(macOS 26.0, *) else {
                throw TextEditingError(message: "On-device editing requires macOS 26 or later.")
            }
            let result = try await OnDeviceTextEditor.revise(input, action: action)
            FileHandle.standardOutput.write(Data(result.utf8))
            exit(0)
        } catch {
            FileHandle.standardError.write(Data("\(error.localizedDescription)\n".utf8))
            exit(1)
        }
    }
    RunLoop.main.run()
    exit(1)
}

if CommandLine.arguments.contains("--dump-menu") {
    MenuDumper.run()
    exit(0)
}

if let triggerIndex = CommandLine.arguments.firstIndex(of: "--trigger") {
    guard CommandLine.arguments.count > triggerIndex + 1,
          let action = WritingToolsAction(rawValue: CommandLine.arguments[triggerIndex + 1]) else {
        print("Usage: Proofly --trigger proofread|rewrite")
        exit(2)
    }
    Task { @MainActor in
        let result = await WritingToolsAutomator.trigger(action)
        print(result.message(for: action))
        exit(result.succeeded ? 0 : 1)
    }
    RunLoop.main.run()
    exit(1)
}

let delegate = AppDelegate()
let app = NSApplication.shared
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
