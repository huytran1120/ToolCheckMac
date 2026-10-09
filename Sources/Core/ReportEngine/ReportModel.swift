import Foundation

/// Check status of an individual item. Red flag items are elevated to the top of the report.
enum CheckStatus: String, Codable, Sendable {
    case pass          // Green, normal
    case warning       // Yellow, caution needed but not fatal
    case redFlag       // Red, critical blocker (MDM, lock, suspected tampering)
    case skipped       // Skipped by user
    case unsupported   // Unsupported on this machine / runtime environment

    var emoji: String {
        switch self {
        case .pass: return "✅"
        case .warning: return "⚠️"
        case .redFlag: return "⛔"
        case .skipped: return "⏭️"
        case .unsupported: return "➖"
        }
    }
}

/// Full check result: human-readable conclusion + expandable technical raw details.
struct CheckResult: Identifiable, Codable, Sendable {
    let id: String                  // Stable ID, e.g. "battery.cycleCount"
    let title: String               // User-facing title, e.g. "Battery Health"
    let status: CheckStatus
    let summary: String              // User-facing summary
    var rawDetails: [String: String] = [:]   // Expandable raw key-values
    var isRedFlagHeadline: String? = nil      // If present, elevated to red flag banner at top of report

    init(
        id: String,
        title: String,
        status: CheckStatus,
        summary: String,
        rawDetails: [String: String] = [:],
        isRedFlagHeadline: String? = nil
    ) {
        self.id = id
        self.title = title
        self.status = status
        self.summary = summary
        self.rawDetails = rawDetails
        self.isRedFlagHeadline = isRedFlagHeadline
    }
}

/// Structured hardware profile displayed at the top of Overview.
struct DeviceProfile: Codable, Sendable {
    var marketingName: String    // "MacBook Pro (14-inch, 2021)"
    var modelIdentifier: String  // "MacBookPro18,3"
    var chip: String             // "Apple M1 Pro"
    var memory: String           // "32 GB"
    var macOSVersion: String     // "macOS 15.3.2 (24D...)"
    var serialNumber: String
    var architecture: String
    var modelYear: String        // "2021"
    var productionDate: String   // Manufacture date estimate or randomized note
}

/// 完整验机报告。
struct MacCheckReport: Codable, Sendable {
    var generatedAt: Date
    var appVersion: String
    var results: [CheckResult] = []

    var redFlags: [CheckResult] {
        results.filter { $0.status == .redFlag }
    }

    var score: Int {
        guard !results.isEmpty else { return 100 }
        let scored = results.filter { $0.status != .skipped && $0.status != .unsupported }
        guard !scored.isEmpty else { return 100 }
        let deductions = scored.reduce(0.0) { acc, r in
            switch r.status {
            case .redFlag: return acc + 25
            case .warning: return acc + 8
            default: return acc
            }
        }
        return max(0, Int(100 - deductions))
    }

    mutating func add(_ result: CheckResult) {
        results.append(result)
    }
}
