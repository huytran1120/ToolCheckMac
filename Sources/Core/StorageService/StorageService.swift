import Foundation

/// A3：存储/固态硬盘检测。读取 SSD 型号、容量、SMART 健康状态、TRIM，以及剩余可用空间。
enum StorageService {

    private static func nvmeDrives() -> [[String: Any]] {
        let output = ShellRunner.run("/usr/sbin/system_profiler", ["SPNVMeDataType", "-json"])
        guard let data = output.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let controllers = json["SPNVMeDataType"] as? [[String: Any]]
        else { return [] }
        return controllers.flatMap { ($0["_items"] as? [[String: Any]]) ?? [] }
    }

    private static func freeSpaceBytes() -> Int64? {
        let url = URL(fileURLWithPath: "/")
        guard let values = try? url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]),
              let bytes = values.volumeAvailableCapacityForImportantUsage
        else { return nil }
        return bytes
    }

    private static func gb(_ bytes: Int64) -> String {
        String(format: "%.1f GB", Double(bytes) / 1_000_000_000)
    }

    static func runAll() -> [CheckResult] {
        let drives = nvmeDrives()
        guard let disk = drives.first else {
            return [CheckResult(
                id: "storage",
                title: "Storage",
                status: .unsupported,
                summary: "No built-in NVMe solid-state drive information detected"
            )]
        }

        let model = (disk["device_model"] as? String) ?? (disk["_name"] as? String) ?? "Unknown"
        let size = (disk["size"] as? String) ?? ""
        let smart = (disk["smart_status"] as? String) ?? ""
        let trim = (disk["spnvme_trim_support"] as? String) ?? ""
        let revision = (disk["device_revision"] as? String) ?? ""

        var details: [String: String] = [
            "Model": model,
            "Capacity": size,
            "SMART Status": smart.isEmpty ? "Unknown" : smart,
            "TRIM Support": trim.isEmpty ? "Unknown" : trim,
            "Firmware Revision": revision,
        ]
        if let free = freeSpaceBytes() {
            details["Available Space"] = gb(free)
        }

        // SMART "Verified" = 正常；其它值（如 Failing）→ 红旗
        let smartOK = smart.lowercased() == "verified"
        if !smart.isEmpty && !smartOK {
            return [CheckResult(
                id: "storage",
                title: "Storage / SSD",
                status: .redFlag,
                summary: "SSD SMART health status abnormal (\(smart)); risk of data loss",
                rawDetails: details,
                isRedFlagHeadline: "⛔ Solid-state drive SMART health check failed (status: \(smart)). The drive may be failing with imminent risk of data loss. Purchase is not recommended, or backup and replacement is required immediately."
            )]
        }

        return [CheckResult(
            id: "storage",
            title: "Storage / SSD",
            status: .pass,
            summary: "\(model) · \(size) · SMART health status normal",
            rawDetails: details
        )]
    }
}
