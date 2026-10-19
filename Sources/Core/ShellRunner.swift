import Foundation
import OSLog

enum ShellRunner {
    struct Output: Sendable {
        let stdout: String
        let stderr: String
    }

    enum CommandError: LocalizedError {
        case invalidTimeout
        case timedOut
        case nonZeroExit(Int32, String)

        var errorDescription: String? {
            switch self {
            case .invalidTimeout: return "Command timeout must be a finite positive value."
            case .timedOut: return "The system command exceeded its time limit."
            case .nonZeroExit(let status, let stderr):
                return "The system command exited with status \(status). \(stderr)"
            }
        }
    }

    static func execute(_ launchPath: String, _ arguments: [String], timeout: TimeInterval = 30) throws -> Output {
        guard timeout.isFinite, timeout > 0 else { throw CommandError.invalidTimeout }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = arguments
        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr
        let handles = [stdout.fileHandleForReading, stderr.fileHandleForReading]
        for handle in handles {
            let flags = fcntl(handle.fileDescriptor, F_GETFL)
            guard flags >= 0, fcntl(handle.fileDescriptor, F_SETFL, flags | O_NONBLOCK) == 0 else {
                throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
            }
        }
        try process.run()
        defer {
            terminateIfRunning(process)
            for handle in handles {
                do {
                    try handle.close()
                } catch {
                    Logger(subsystem: "com.toolcheckmacbook", category: "ShellRunner")
                        .error("Pipe cleanup failed: \(error.localizedDescription, privacy: .private)")
                }
            }
        }

        var output = [Data(), Data()]
        var ended = [false, false]
        let deadline = ProcessInfo.processInfo.systemUptime + timeout
        while process.isRunning || !ended.allSatisfy({ $0 }) {
            let remaining = deadline - ProcessInfo.processInfo.systemUptime
            guard remaining > 0 else { throw CommandError.timedOut }
            var descriptors = handles.enumerated().map { index, handle in
                pollfd(fd: ended[index] ? -1 : handle.fileDescriptor, events: Int16(POLLIN), revents: 0)
            }
            let ready = poll(&descriptors, nfds_t(descriptors.count), Int32(min(50, remaining * 1000).rounded(.up)))
            if ready < 0 {
                if errno == EINTR { continue }
                throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
            }
            for index in descriptors.indices where descriptors[index].revents != 0 {
                ended[index] = try drain(handles[index], into: &output[index])
            }
        }
        process.waitUntilExit()
        let result = Output(stdout: String(decoding: output[0], as: UTF8.self),
                            stderr: String(decoding: output[1], as: UTF8.self))
        guard process.terminationStatus == 0 else {
            throw CommandError.nonZeroExit(process.terminationStatus, result.stderr)
        }
        return result
    }

    private static func drain(_ handle: FileHandle, into output: inout Data) throws -> Bool {
        var buffer = [UInt8](repeating: 0, count: 16384)
        // Bound each drain so a continuously writing process cannot starve the timeout or stderr.
        for _ in 0..<16 {
            let count = buffer.withUnsafeMutableBytes {
                Darwin.read(handle.fileDescriptor, $0.baseAddress, $0.count)
            }
            if count > 0 {
                output.append(contentsOf: buffer.prefix(count))
            } else if count == 0 {
                return true
            } else if errno == EAGAIN || errno == EWOULDBLOCK {
                return false
            } else if errno != EINTR {
                throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
            }
        }
        return false
    }

    private static func terminateIfRunning(_ process: Process) {
        guard process.isRunning else { return }
        process.terminate()
        let deadline = ProcessInfo.processInfo.systemUptime + 1
        while process.isRunning, ProcessInfo.processInfo.systemUptime < deadline {
            Thread.sleep(forTimeInterval: 0.01)
        }
        if process.isRunning { kill(process.processIdentifier, SIGKILL) }
        process.waitUntilExit()
    }

    static func run(_ launchPath: String, _ arguments: [String]) -> String {
        do {
            return try execute(launchPath, arguments).stdout
        } catch {
            Logger(subsystem: "com.toolcheckmacbook", category: "ShellRunner")
                .error("Command \(launchPath, privacy: .public) failed: \(error.localizedDescription, privacy: .private)")
            return ""
        }
    }

    static func run(_ command: String, _ arguments: String...) -> String {
        run(command, arguments)
    }
}
