import Foundation

/// Security chip tier identification. Explains clearly to prevent misunderstandings.
enum SecurityChipTier: String, Sendable {
    case appleSilicon = "Apple Silicon (Built-in Secure Enclave)"
    case intelWithT2 = "Intel with T2 Security Chip"
    case intelNoT2 = "Intel (No T2 Security Chip)"
}

enum SecurityChipService {

    private static func bridgeOSJSON() -> [String: Any] {
        let output = ShellRunner.run("/usr/sbin/system_profiler", ["SPiBridgeDataType", "-json"])
        guard let data = output.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let items = json["SPiBridgeDataType"] as? [[String: Any]],
              let first = items.first
        else { return [:] }
        return first
    }

    static func detectTier() -> SecurityChipTier {
        if HardwareProbe.isAppleSiliconHardware() {
            return .appleSilicon
        }
        let bridge = bridgeOSJSON()
        let modelName = (bridge["ibridge_model_name"] as? String) ?? (bridge["Model Name"] as? String) ?? ""
        if modelName.contains("T2") {
            return .intelWithT2
        }
        return .intelNoT2
    }

    static func runAll() -> [CheckResult] {
        let tier = detectTier()
        let explanation: String
        switch tier {
        case .appleSilicon:
            explanation = "This Mac features Apple Silicon (M-series) with security integrated directly into the chip. Ensure Find My Mac / Activation Lock is turned off (see MDM & Lock section), as Activation Lock issues are most common on these models."
        case .intelWithT2:
            explanation = "This Mac is an Intel Mac equipped with a T2 Security Chip. Activation Lock risks apply; please confirm that Find My Mac is disabled."
        case .intelNoT2:
            explanation = "This Mac is an earlier Intel model without a T2 Security Chip. It does not support Activation Lock, so you do not need to worry about Apple ID activation locks."
        }
        return [CheckResult(
            id: "hardware.securityChip",
            title: "Security Chip",
            status: .pass,
            summary: "\(tier.rawValue) — \(explanation)",
            rawDetails: ["Security Chip Tier": tier.rawValue]
        )]
    }
}
