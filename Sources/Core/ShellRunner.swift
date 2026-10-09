import Foundation

/// Unified local command execution wrapper. The app is strictly offline; this is the sole external interaction surface.
/// All callers should treat command output as untrusted input (handle parsing failures gracefully without crashing).
enum ShellRunner {
    static func run(_ launchPath: String, _ arguments: [String]) -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = arguments

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        do {
            try process.run()
        } catch {
            return ""
        }
        process.waitUntilExit()

        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }

    static func run(_ command: String, _ arguments: String...) -> String {
        run(command, arguments)
    }
}
