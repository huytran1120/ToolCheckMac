import Foundation
import IOKit

/// A1：机器身份信息。所有字段走 IOKit/sysctl 底层读取，不依赖「关于本机」这类可被替换的上层展示。
/// 序列号额外用 system_profiler 交叉核对（5.5 防篡改原则）。
enum HardwareProbe {

    // MARK: - IOKit 读取

    static func ioPlatformSerialNumber() -> String {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPlatformExpertDevice"))
        guard service != 0 else { return "" }
        defer { IOObjectRelease(service) }
        guard let cfValue = IORegistryEntryCreateCFProperty(
            service, kIOPlatformSerialNumberKey as CFString, kCFAllocatorDefault, 0
        ) else { return "" }
        return (cfValue.takeRetainedValue() as? String) ?? ""
    }

    static func ioPlatformUUID() -> String {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPlatformExpertDevice"))
        guard service != 0 else { return "" }
        defer { IOObjectRelease(service) }
        guard let cfValue = IORegistryEntryCreateCFProperty(
            service, kIOPlatformUUIDKey as CFString, kCFAllocatorDefault, 0
        ) else { return "" }
        return (cfValue.takeRetainedValue() as? String) ?? ""
    }

    // MARK: - sysctl 读取

    static func sysctlString(_ name: String) -> String {
        var size = 0
        guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else { return "" }
        var buffer = [CChar](repeating: 0, count: size)
        guard sysctlbyname(name, &buffer, &size, nil, 0) == 0 else { return "" }
        return String(cString: buffer)
    }

    static func isAppleSiliconHardware() -> Bool {
        var value: Int32 = 0
        var size = MemoryLayout<Int32>.size
        let result = sysctlbyname("hw.optional.arm64", &value, &size, nil, 0)
        if result == 0 { return value == 1 }
        return sysctlString("machdep.cpu.brand_string").contains("Apple")
    }

    static func physicalMemoryGB() -> Double {
        var memSize: UInt64 = 0
        var size = MemoryLayout<UInt64>.size
        sysctlbyname("hw.memsize", &memSize, &size, nil, 0)
        return Double(memSize) / 1_073_741_824.0
    }

    static func modelIdentifier() -> String {
        sysctlString("hw.model")
    }

    // MARK: - system_profiler 交叉核对

    static func systemProfilerHardwareJSON() -> [String: Any] {
        let output = ShellRunner.run("/usr/sbin/system_profiler", ["SPHardwareDataType", "-json"])
        guard let data = output.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let items = json["SPHardwareDataType"] as? [[String: Any]],
              let first = items.first
        else { return [:] }
        return first
    }

    // MARK: - 芯片 / 系统版本

    static func chipString() -> String {
        let sp = systemProfilerHardwareJSON()
        if let chip = sp["chip_type"] as? String { return chip }
        if let cpu = sp["cpu_type"] as? String { return cpu }
        return sysctlString("machdep.cpu.brand_string")
    }

    static func macOSVersionString() -> String {
        let v = ProcessInfo.processInfo.operatingSystemVersion
        let build = sysctlString("kern.osversion")
        var s = "macOS \(v.majorVersion).\(v.minorVersion)"
        if v.patchVersion > 0 { s += ".\(v.patchVersion)" }
        if !build.isEmpty { s += " (\(build))" }
        return s
    }

    /// 首页头部用的结构化机器档案（打开即展示，无需用户操作）。
    static func buildProfile() -> DeviceProfile {
        let sp = systemProfilerHardwareJSON()
        let identifier = modelIdentifier()
        let machineName = (sp["machine_name"] as? String) ?? ""
        let ioSerial = ioPlatformSerialNumber()
        let serial = ioSerial.isEmpty ? ((sp["serial_number"] as? String) ?? "") : ioSerial
        let marketing = DeviceNaming.friendlyName(fallbackMachineName: machineName, identifier: identifier)
        return DeviceProfile(
            marketingName: marketing,
            modelIdentifier: identifier,
            chip: chipString(),
            memory: String(format: "%.0f GB", physicalMemoryGB().rounded()),
            macOSVersion: macOSVersionString(),
            serialNumber: serial,
            architecture: isAppleSiliconHardware() ? "Apple Silicon (arm64)" : "Intel (x86_64)",
            modelYear: modelYear(from: marketing),
            productionDate: SerialDecoder.productionDescription(serial: serial)
        )
    }

    /// 从营销名里提取 4 位年份，如 "MacBook Pro（14 英寸，2021）" → "2021"。
    private static func modelYear(from marketingName: String) -> String {
        if let range = marketingName.range(of: #"20\d{2}"#, options: .regularExpression) {
            return String(marketingName[range])
        }
        return ""
    }

    // MARK: - 汇总检测

    static func runAll() -> [CheckResult] {
        var results: [CheckResult] = []

        let sp = systemProfilerHardwareJSON()
        let ioSerial = ioPlatformSerialNumber()
        let spSerial = (sp["serial_number"] as? String) ?? ""
        let model = modelIdentifier()
        let spModel = (sp["machine_model"] as? String) ?? ""

        // Serial number cross-check: IOKit vs system_profiler mismatch -> Red Flag (suspected tampering or abnormal environment)
        if ioSerial.isEmpty && spSerial.isEmpty {
            results.append(CheckResult(
                id: "hardware.serial",
                title: "Serial Number Verification",
                status: .warning,
                summary: "Unable to read serial number; could be a virtual machine or restricted environment",
                rawDetails: ["IOKit": ioSerial, "system_profiler": spSerial]
            ))
        } else if !ioSerial.isEmpty && !spSerial.isEmpty && ioSerial != spSerial {
            results.append(CheckResult(
                id: "hardware.serial",
                title: "Serial Number Verification",
                status: .redFlag,
                summary: "Serial numbers from different sources do not match; hardware identity data may have been tampered with",
                rawDetails: ["IOKit Read": ioSerial, "system_profiler Read": spSerial],
                isRedFlagHeadline: "⛔ Serial number cross-check mismatch (IOKit and system profiler reported different values). Key device identity may have been tampered with. Do not rely solely on this report for transactions; verify coverage on Apple's official site."
            ))
        } else {
            results.append(CheckResult(
                id: "hardware.serial",
                title: "Serial Number Verification",
                status: .pass,
                summary: "Serial number \(ioSerial.isEmpty ? spSerial : ioSerial) matches across read methods; verify warranty status on Apple's official site",
                rawDetails: ["Serial Number": ioSerial.isEmpty ? spSerial : ioSerial, "Model Identifier Cross-Check": model == spModel || spModel.isEmpty ? "Match" : "Mismatch (\(model) vs \(spModel))"]
            ))
        }

        return results
    }
}
