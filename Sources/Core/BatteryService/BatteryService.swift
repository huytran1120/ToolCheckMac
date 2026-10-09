import Foundation
import IOKit

/// A2: Battery health. Cycle count and capacity via IORegistry `AppleSmartBattery`,
/// with `ioreg` CLI output as a secondary cross-check source (anti-tamper principle: two independent paths, flag if mismatch).
enum BatteryService {

    private static func openBatteryService() -> io_service_t {
        IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
    }

    private static func ioKitProperties() -> [String: Any] {
        let service = openBatteryService()
        guard service != 0 else { return [:] }
        defer { IOObjectRelease(service) }

        var propsUnmanaged: Unmanaged<CFMutableDictionary>?
        let result = IORegistryEntryCreateCFProperties(service, &propsUnmanaged, kCFAllocatorDefault, 0)
        guard result == KERN_SUCCESS, let props = propsUnmanaged?.takeRetainedValue() as? [String: Any] else {
            return [:]
        }
        return props
    }

    /// Secondary source: directly parse CycleCount from `ioreg` CLI text output through an independent pipeline.
    private static func ioregCycleCount() -> Int? {
        let output = ShellRunner.run("/usr/sbin/ioreg", ["-rd1", "-c", "AppleSmartBattery"])
        guard let range = output.range(of: "\"CycleCount\" = ") else { return nil }
        let tail = output[range.upperBound...]
        let numberString = tail.prefix { $0.isNumber }
        return Int(numberString)
    }

    static func runAll() -> [CheckResult] {
        let props = ioKitProperties()
        guard !props.isEmpty else {
            return [CheckResult(
                id: "battery.health",
                title: "Battery Health",
                status: .unsupported,
                summary: "No battery detected (likely a desktop Mac: Mac mini / Mac Studio / Mac Pro; this check does not apply)"
            )]
        }

        var results: [CheckResult] = []

        let cycleCount = props["CycleCount"] as? Int ?? 0
        let designCapacity = props["DesignCapacity"] as? Int ?? 0
        let rawMaxCapacity = props["AppleRawMaxCapacity"] as? Int ?? 0
        let maxCapacityPercentRaw = props["MaxCapacity"] as? Int
        let isCharging = props["IsCharging"] as? Bool ?? false
        let externalConnected = props["ExternalConnected"] as? Bool ?? false
        let temperatureRaw = props["Temperature"] as? Int ?? 0
        let temperatureC = Double(temperatureRaw) / 100.0

        var health: Double?
        if designCapacity > 0 && rawMaxCapacity > 0 {
            health = Double(rawMaxCapacity) / Double(designCapacity) * 100.0
        } else if let pct = maxCapacityPercentRaw, pct > 0 && pct <= 100 {
            health = Double(pct)
        }

        var details: [String: String] = [
            "Cycle Count": "\(cycleCount)",
            "Design Capacity (mAh)": designCapacity > 0 ? "\(designCapacity)" : "N/A",
            "Maximum Capacity (mAh)": rawMaxCapacity > 0 ? "\(rawMaxCapacity)" : "N/A",
            "Battery Temperature": String(format: "%.1f °C", temperatureC),
            "Charging": isCharging ? "Yes" : "No",
            "Connected to AC": externalConnected ? "Yes" : "No",
        ]
        if let serial = props["BatterySerialNumber"] as? String {
            details["Battery Serial Number"] = serial
        }
        if let adapterDetails = props["AdapterDetails"] as? [String: Any],
           let watts = adapterDetails["Watts"] as? Int {
            details["Charger Wattage"] = "\(watts)W"
        }

        // Cycle count cross-check
        if let ioregCount = ioregCycleCount(), ioregCount != cycleCount {
            results.append(CheckResult(
                id: "battery.cycleCount.crosscheck",
                title: "Battery Cycle Count Cross-Check",
                status: .redFlag,
                summary: "Cycle count differs between detection methods (\(cycleCount) vs \(ioregCount)); battery data may have been tampered with",
                rawDetails: ["IOKit Read": "\(cycleCount)", "ioreg Read": "\(ioregCount)"],
                isRedFlagHeadline: "⛔ Battery cycle count results differ between detection methods and may have been tampered with. Do not rely solely on software numbers; verify real-world battery life."
            ))
        }

        // Cycle count evaluation (common baseline: iPhone/Mac battery design life ~1000 cycles)
        let cycleStatus: CheckStatus = cycleCount > 1000 ? .warning : .pass
        let usageHint: String
        switch cycleCount {
        case 0...30: usageHint = "Virtually new, very low usage"
        case 31...200: usageHint = "Light usage, approx. a few months to a year"
        case 201...500: usageHint = "Moderate usage, typical used condition"
        case 501...1000: usageHint = "Heavy usage, noticeable battery wear"
        default: usageHint = "High cycle count, battery capacity likely degraded significantly; consider battery replacement or price negotiation"
        }
        results.append(CheckResult(
            id: "battery.cycleCount",
            title: "Battery Cycle Count",
            status: cycleStatus,
            summary: "\(cycleCount) cycles — \(usageHint)",
            rawDetails: details
        ))

        // Battery health
        if let health {
            let healthStatus: CheckStatus = health >= 80 ? .pass : (health >= 60 ? .warning : .redFlag)
            let headline: String? = health < 60
                ? "⛔ Battery health is only \(Int(health))%. Expect significantly reduced battery life or unexpected shutdowns; request a battery replacement or negotiate price before purchase."
                : nil
            results.append(CheckResult(
                id: "battery.health",
                title: "Battery Health",
                status: healthStatus,
                summary: "Health approx. \(Int(health))%" + (health >= 80 ? ", good condition" : health >= 60 ? ", noticeable degradation but usable" : ", severely degraded"),
                rawDetails: details,
                isRedFlagHeadline: headline
            ))
        } else {
            results.append(CheckResult(
                id: "battery.health",
                title: "Battery Health",
                status: .warning,
                summary: "Standard health percentage not reported by this model; refer to raw capacity values",
                rawDetails: details
            ))
        }

        return results
    }
}
