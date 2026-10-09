import Foundation

/// A single test snapshot. Stores key comparison metrics alongside the full report for quick historical diffing.
struct SavedReport: Codable, Identifiable, Sendable {
    var id: UUID
    var savedAt: Date
    var deviceName: String
    var serial: String
    var score: Int
    var batteryCycles: Int?
    var batteryHealth: String?
    var report: MacCheckReport
}

/// History persistence (stateless). Stored in Application Support/ToolCheckMacBook/history.json.
enum HistoryStore {
    private static var fileURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let newDir = appSupport.appendingPathComponent("ToolCheckMacBook", isDirectory: true)
        let oldDir = appSupport.appendingPathComponent("MacCheck", isDirectory: true)
        let oldFile = oldDir.appendingPathComponent("history.json")
        let newFile = newDir.appendingPathComponent("history.json")

        try? FileManager.default.createDirectory(at: newDir, withIntermediateDirectories: true)
        if FileManager.default.fileExists(atPath: oldFile.path) && !FileManager.default.fileExists(atPath: newFile.path) {
            try? FileManager.default.copyItem(at: oldFile, to: newFile)
        }
        return newFile
    }

    static func load() -> [SavedReport] {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([SavedReport].self, from: data) else { return [] }
        return decoded.map(normalize).sorted { $0.savedAt > $1.savedAt }
    }

    static func save(_ reports: [SavedReport]) {
        guard let data = try? JSONEncoder().encode(reports) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    private static func normalize(_ item: SavedReport) -> SavedReport {
        var copy = item
        copy.deviceName = normalizeDeviceName(copy.deviceName)
        if let health = copy.batteryHealth {
            copy.batteryHealth = normalizeHealth(health)
        }
        copy.report.results = copy.report.results.map(normalizeResult)
        return copy
    }

    private static func normalizeDeviceName(_ name: String) -> String {
        var s = name
        s = s.replacingOccurrences(of: "‑inch", with: "-inch")
        s = s.replacingOccurrences(of: " 英寸", with: "-inch")
        s = s.replacingOccurrences(of: "英寸", with: "-inch")
        s = s.replacingOccurrences(of: "（", with: " (")
        s = s.replacingOccurrences(of: "）", with: ")")
        s = s.replacingOccurrences(of: "，", with: ", ")
        return s
    }

    private static func normalizeHealth(_ health: String) -> String {
        switch health {
        case "正常": return "Normal"
        case "建议维修": return "Service Recommended"
        case "尽快更换": return "Replace Soon"
        default: return health
        }
    }

    private static let titleMap: [String: String] = [
        "电池循环": "Battery Cycles",
        "电池健康": "Battery Health",
        "充电器与功率": "Charger & Power",
        "Wi-Fi 状态": "Wi-Fi Status",
        "蓝牙状态": "Bluetooth Status",
        "硬盘健康 (SMART)": "Disk Health (SMART)",
        "硬盘健康": "Disk Health (SMART)",
        "系统盘用量": "System Disk Usage",
        "扩展接口": "External Ports",
        "雷雳 / USB4": "Thunderbolt / USB4",
        "MDM / 企业管理": "Enterprise Management (MDM)",
        "查找我的 Mac / 激活锁": "Find My Mac / Activation Lock",
        "Apple ID 登录": "Apple ID Sign-in",
        "序列号核验": "Serial Number Verification",
        "安全芯片": "Security Chip",
        "屏幕坏点与背光": "Screen Pixels & Backlight",
        "键盘按键": "Keyboard Keys",
        "扬声器 / 耳机": "Speaker / Headphones",
        "麦克风": "Microphone",
        "摄像头": "Camera",
        "触控板": "Trackpad",
        "Touch ID": "Touch ID",
        "性能压力测试": "Performance Stress Test",
        "硬盘读写测速": "Disk Speed Test",
        "接口实时插拔": "Port Live Plug/Unplug",
    ]

    private static let rawKeyMap: [String: String] = [
        "循环次数": "Cycle Count",
        "健康度": "Battery Health",
        "设计容量": "Design Capacity",
        "当前最大容量": "Current Max Capacity",
        "健康度百分比": "Health Percentage",
        "制造日期": "Manufacture Date",
        "电池温度": "Battery Temperature",
        "网卡 MAC": "Network Adapter MAC",
        "协商速率": "Tx Rate",
        "协议": "PHY Mode",
        "蓝牙芯片": "Bluetooth Chipset",
        "蓝牙版本": "Bluetooth Version",
        "SMART 状态": "SMART Status",
        "总写入量 (TBW)": "Total Bytes Written (TBW)",
        "总读取量": "Total Read",
        "备用空间": "Available Spare",
        "通电时间": "Power-on Hours",
        "异常断电次数": "Unsafe Shutdowns",
        "安全芯片档位": "Security Chip Tier",
        "序列号": "Serial Number",
        "IOKit 读取": "IOKit Read",
        "system_profiler 读取": "system_profiler Read",
        "机型标识交叉核对": "Model Identifier Cross-Check",
    ]

    private static func normalizeResult(_ r: CheckResult) -> CheckResult {
        let newTitle = titleMap[r.title] ?? r.title
        var newDetails: [String: String] = [:]
        for (k, v) in r.rawDetails {
            let mappedK = rawKeyMap[k] ?? k
            var mappedV = v
            if mappedV == "正常" { mappedV = "Normal" }
            else if mappedV == "未连接" { mappedV = "Not Connected" }
            else if mappedV == "已开启" { mappedV = "Enabled" }
            else if mappedV == "已关闭" { mappedV = "Disabled" }
            else if mappedV == "一致" { mappedV = "Match" }
            else if mappedV == "未知" { mappedV = "Unknown" }
            newDetails[mappedK] = mappedV
        }
        return CheckResult(
            id: r.id,
            title: newTitle,
            status: r.status,
            summary: r.summary,
            rawDetails: newDetails,
            isRedFlagHeadline: r.isRedFlagHeadline
        )
    }
}
