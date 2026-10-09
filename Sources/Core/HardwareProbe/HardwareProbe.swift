import Foundation
import IOKit

/// A1: Machine identity information. All fields read via low-level IOKit/sysctl,
/// independent of surface-level displays like "About This Mac" which can be spoofed.
/// Serial numbers are cross-checked with system_profiler (anti-tamper principle).
enum HardwareProbe {

    // MARK: - IOKit Read

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

    // MARK: - sysctl Read

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

    // MARK: - system_profiler Cross-Check

    static func systemProfilerHardwareJSON() -> [String: Any] {
        let output = ShellRunner.run("/usr/sbin/system_profiler", ["SPHardwareDataType", "-json"])
        guard let data = output.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let items = json["SPHardwareDataType"] as? [[String: Any]],
              let first = items.first
        else { return [:] }
        return first
    }

    // MARK: - Chipset / OS Version

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

    /// Structured machine profile displayed in the header (loaded immediately on launch without user action).
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

    /// Extracts 4-digit model year from marketing name, e.g. "MacBook Pro (14-inch, 2021)" -> "2021".
    private static func modelYear(from marketingName: String) -> String {
        if let range = marketingName.range(of: #"20\d{2}"#, options: .regularExpression) {
            return String(marketingName[range])
        }
        return ""
    }

    // MARK: - Aggregate Checks

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
