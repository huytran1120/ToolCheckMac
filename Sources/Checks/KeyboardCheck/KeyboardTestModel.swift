import AppKit
import Combine

/// Keyboard test state machine. Uses local event monitoring rather than global accessibility hooks.
/// The fullscreen test window receives key events directly as the key window without requiring Accessibility permissions.
@MainActor
final class KeyboardTestModel: ObservableObject {
    @Published private(set) var testedKeyCodes: Set<UInt16> = []
    @Published private(set) var pressedKeyCodes: Set<UInt16> = []
    @Published private(set) var stuckKeyCodes: Set<UInt16> = []

    private var pressStartTimes: [UInt16: Date] = [:]
    private var monitor: Any?
    private var stuckCheckTimer: Timer?

    let totalKeyCount: Int
    var onRequestFinish: (() -> Void)?

    private static let escKeyCode: UInt16 = 53
    private static let escHoldToExitSeconds: TimeInterval = 1.2
    private static let stuckThresholdSeconds: TimeInterval = 5.0

    init(totalKeyCount: Int = KeyboardLayout.totalKeyCount) {
        self.totalKeyCount = totalKeyCount
    }

    var progress: Double {
        totalKeyCount == 0 ? 0 : Double(testedKeyCodes.count) / Double(totalKeyCount)
    }

    var isComplete: Bool { testedKeyCodes.count >= totalKeyCount }

    func start() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp, .flagsChanged]) { [weak self] event in
            // Allow Command shortcuts through (Cmd+Q to quit, Cmd+Tab to switch, Cmd+. to cancel)
            // Ensuring the user can safely exit fullscreen at any time.
            if event.modifierFlags.contains(.command) { return event }
            self?.handle(event)
            return nil // Consume other keys: prevent beep sounds and accidental control clicks
        }
        stuckCheckTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.checkForStuckKeys() }
        }
    }

    func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        stuckCheckTimer?.invalidate()
        stuckCheckTimer = nil
    }

    private func handle(_ event: NSEvent) {
        let code = event.keyCode
        switch event.type {
        case .keyDown:
            pressedKeyCodes.insert(code)
            testedKeyCodes.insert(code)
            if pressStartTimes[code] == nil {
                pressStartTimes[code] = Date()
            }
            stuckKeyCodes.remove(code)

        case .keyUp:
            if code == Self.escKeyCode, let start = pressStartTimes[code] {
                let held = Date().timeIntervalSince(start)
                if held >= Self.escHoldToExitSeconds {
                    onRequestFinish?()
                }
            }
            pressedKeyCodes.remove(code)
            pressStartTimes[code] = nil
            stuckKeyCodes.remove(code)

        case .flagsChanged:
            // Modifier keys do not have clean down/up pairs; toggle based on whether already recorded as pressed.
            testedKeyCodes.insert(code)
            if pressedKeyCodes.contains(code) {
                pressedKeyCodes.remove(code)
                pressStartTimes[code] = nil
            } else {
                pressedKeyCodes.insert(code)
                pressStartTimes[code] = Date()
            }
            stuckKeyCodes.remove(code)

        default:
            break
        }
    }

    private func checkForStuckKeys() {
        let now = Date()
        for (code, start) in pressStartTimes where now.timeIntervalSince(start) > Self.stuckThresholdSeconds {
            stuckKeyCodes.insert(code)
        }
    }

    /// Evaluates test result: all tested and no stuck keys -> pass; stuck keys -> warning; exited early -> evaluate coverage.
    func buildResult() -> CheckResult {
        var details: [String: String] = [
            "Keys Tested": "\(testedKeyCodes.count) / \(totalKeyCount)",
        ]
        if !stuckKeyCodes.isEmpty {
            let names = stuckKeyCodes.compactMap { code in
                KeyboardLayout.allKeys.first { $0.keyCode == code }?.label
            }.joined(separator: ", ")
            details["Suspected Stuck Keys"] = names
            return CheckResult(
                id: "keyboard",
                title: "Keyboard Test",
                status: .warning,
                summary: "Suspected stuck keys detected: \(names), recommend re-testing these keys",
                rawDetails: details
            )
        }
        if isComplete {
            return CheckResult(
                id: "keyboard",
                title: "Keyboard Test",
                status: .pass,
                summary: "All \(totalKeyCount) keys tested individually and responsive",
                rawDetails: details
            )
        }
        return CheckResult(
            id: "keyboard",
            title: "Keyboard Test",
            status: .warning,
            summary: "Exited after testing only \(testedKeyCodes.count)/\(totalKeyCount) keys; full test recommended",
            rawDetails: details
        )
    }
}
