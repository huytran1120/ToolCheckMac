import Foundation

/// 侧边栏导航项。概览 + 系统自动检测分类 + 硬件交互测试。
enum SidebarItem: String, CaseIterable, Identifiable, Hashable {
    case overview
    // 系统自动检测
    case specs, battery, security, storage, network, ports
    // 硬件交互测试
    case keyboard, screen, audio, microphone, camera, touchID, trackpad, performance, diskSpeed, portsLive
    case aiModels
    case history
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview: return "Overview"
        case .specs: return "Hardware Specifications"
        case .battery: return "Battery"
        case .security: return "Security & Lock"
        case .storage: return "Storage"
        case .network: return "Network"
        case .ports: return "Ports"
        case .keyboard: return "Keyboard"
        case .screen: return "Display"
        case .audio: return "Speaker / Headphones"
        case .microphone: return "Microphone"
        case .camera: return "Camera"
        case .touchID: return "Touch ID"
        case .trackpad: return "Trackpad"
        case .performance: return "Performance Test"
        case .diskSpeed: return "Disk Speed Test"
        case .portsLive: return "Port Live Test"
        case .aiModels: return "AI Models"
        case .history: return "History"
        case .settings: return "Settings"
        }
    }

    var icon: String {
        switch self {
        case .overview: return "square.grid.2x2.fill"
        case .specs: return "cpu.fill"
        case .battery: return "battery.100.bolt"
        case .security: return "lock.shield.fill"
        case .storage: return "internaldrive.fill"
        case .network: return "wifi"
        case .ports: return "cable.connector"
        case .keyboard: return "keyboard.fill"
        case .screen: return "display"
        case .audio: return "speaker.wave.3.fill"
        case .microphone: return "mic.fill"
        case .camera: return "camera.fill"
        case .touchID: return "touchid"
        case .trackpad: return "rectangle.and.hand.point.up.left.fill"
        case .performance: return "gauge.with.dots.needle.67percent"
        case .diskSpeed: return "speedometer"
        case .portsLive: return "cable.connector.horizontal"
        case .aiModels: return "sparkles"
        case .history: return "clock.arrow.circlepath"
        case .settings: return "gearshape.fill"
        }
    }

    var isInteractive: Bool {
        switch self {
        case .keyboard, .screen, .audio, .microphone, .camera, .touchID, .trackpad, .performance, .diskSpeed, .portsLive: return true
        default: return false
        }
    }

    /// 需要全屏接管的测试（其余交互测试在详情面板内进行）。
    var needsFullscreen: Bool { self == .keyboard || self == .screen }

    /// 该分类对应的结果 id（用于聚合状态与详情展示）。
    var resultIDs: [String] {
        switch self {
        case .overview, .specs: return []
        case .battery: return ["battery.cycleCount", "battery.health"]
        case .security: return ["hardware.serial", "hardware.securityChip", "management.mdm", "management.appleID", "management.activationLock"]
        case .storage: return ["storage"]
        case .network: return ["network.wifi", "network.bluetooth"]
        case .ports: return ["ports"]
        case .keyboard: return ["keyboard"]
        case .screen: return ["screen"]
        case .audio: return ["audio"]
        case .microphone: return ["microphone"]
        case .camera: return ["camera"]
        case .touchID: return ["touchID"]
        case .trackpad: return ["trackpad"]
        case .performance: return ["performance"]
        case .diskSpeed: return ["diskSpeed"]
        case .portsLive: return ["portsLive"]
        case .aiModels: return []
        case .history: return []
        case .settings: return []
        }
    }

    static let autoCategories: [SidebarItem] = [.specs, .battery, .security, .storage, .network, .ports]
    static let interactiveTests: [SidebarItem] = [.keyboard, .screen, .audio, .microphone, .camera, .touchID, .trackpad, .performance, .diskSpeed, .portsLive]
}

enum FullscreenTest: Identifiable {
    case keyboard, screen
    var id: String { self == .keyboard ? "keyboard" : "screen" }
}

@MainActor
final class AppModel: ObservableObject {
    @Published var selection: SidebarItem? = .overview
    @Published var fullscreenTest: FullscreenTest?
    @Published var isScanning = true
    @Published var profile: DeviceProfile?
    @Published private(set) var autoResults: [String: CheckResult] = [:]
    @Published private(set) var testResults: [String: CheckResult] = [:]
    @Published var generatedAt = Date()
    @Published private(set) var history: [SavedReport] = HistoryStore.load()

    private var hasScanned = false

    private static var appVersion: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "0.1.0"
    }

    func scanIfNeeded() async {
        guard !hasScanned else { return }
        await rescan()
    }

    func rescan() async {
        isScanning = true
        let (profile, results) = await Task.detached(priority: .userInitiated) { () -> (DeviceProfile, [CheckResult]) in
            let p = HardwareProbe.buildProfile()
            var all: [CheckResult] = []
            all.append(contentsOf: HardwareProbe.runAll())
            all.append(contentsOf: SecurityChipService.runAll())
            all.append(contentsOf: BatteryService.runAll())
            all.append(contentsOf: ManagementService.runAll())
            all.append(contentsOf: StorageService.runAll())
            all.append(contentsOf: NetworkService.runAll())
            all.append(contentsOf: PortService.runAll())
            return (p, all)
        }.value
        self.profile = profile
        self.autoResults = Dictionary(uniqueKeysWithValues: results.map { ($0.id, $0) })
        self.generatedAt = Date()
        self.isScanning = false
        self.hasScanned = true
    }

    func recordTest(_ result: CheckResult) {
        testResults[result.id] = result
        generatedAt = Date()
    }

    func result(id: String) -> CheckResult? {
        autoResults[id] ?? testResults[id]
    }

    func results(for item: SidebarItem) -> [CheckResult] {
        item.resultIDs.compactMap { result(id: $0) }
    }

    /// 分类聚合状态：取该分类下最严重的一项；无结果返回 nil（交互测试尚未进行）。
    func status(for item: SidebarItem) -> CheckStatus? {
        let statuses = results(for: item).map(\.status)
        guard !statuses.isEmpty else { return nil }
        if statuses.contains(.redFlag) { return .redFlag }
        if statuses.contains(.warning) { return .warning }
        if statuses.allSatisfy({ $0 == .skipped || $0 == .unsupported }) { return statuses.first }
        return .pass
    }

    var allResults: [CheckResult] {
        var ordered: [CheckResult] = []
        for item in SidebarItem.autoCategories + SidebarItem.interactiveTests {
            ordered.append(contentsOf: results(for: item))
        }
        return ordered
    }

    // MARK: - 历史记录

    func currentBatteryCycles() -> Int? {
        (autoResults["battery.cycleCount"]?.rawDetails["Cycle Count"]
            ?? autoResults["battery.cycleCount"]?.rawDetails["循环次数"]).flatMap { Int($0) }
    }

    func currentBatteryHealth() -> String? {
        guard let summary = autoResults["battery.health"]?.summary,
              let r = summary.range(of: #"\d+%"#, options: .regularExpression) else { return nil }
        return String(summary[r])
    }

    func saveCurrentToHistory() {
        guard let profile else { return }
        let snapshot = SavedReport(
            id: UUID(),
            savedAt: Date(),
            deviceName: profile.marketingName,
            serial: profile.serialNumber,
            score: report.score,
            batteryCycles: currentBatteryCycles(),
            batteryHealth: currentBatteryHealth(),
            report: report
        )
        history.insert(snapshot, at: 0)
        HistoryStore.save(history)
    }

    func deleteHistory(_ id: UUID) {
        history.removeAll { $0.id == id }
        HistoryStore.save(history)
    }

    var report: MacCheckReport {
        var rep = MacCheckReport(generatedAt: generatedAt, appVersion: Self.appVersion)
        rep.results = allResults
        return rep
    }

    var completedTestCount: Int { SidebarItem.interactiveTests.filter { status(for: $0) != nil }.count }
}
