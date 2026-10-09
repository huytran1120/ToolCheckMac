import AppKit
import Combine

/// 键盘测试状态机。用局部事件监听（不是全局 Accessibility 监听）——
/// 全屏测试窗口本身是 key window 时就能收到按键事件，无需辅助功能权限。
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
            // 放行任何带 Command 的组合键（Cmd+Q 退出、Cmd+Tab 切换、Cmd+. 取消等），
            // 保证全屏测试期间用户始终能安全退出，不会被吞键卡住。
            if event.modifierFlags.contains(.command) { return event }
            self?.handle(event)
            return nil // 其余按键吞掉：不发出提示音、不误触其他控件
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
            // 修饰键没有干净的 down/up 配对，用"是否已按下"做翻转判断。
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

    /// 生成本项检测结果：完全测过且无卡键 → pass；有卡键 → warning；未测完就退出 → 按已测覆盖率降级。
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
