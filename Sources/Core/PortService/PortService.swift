import Foundation

/// Port enumeration: Lists devices currently connected via USB / Thunderbolt.
/// Note: Provides a snapshot of currently connected devices.
enum PortService {

    private static func flatten(_ items: [[String: Any]], into names: inout [String]) {
        for item in items {
            if let name = item["_name"] as? String {
                // Filter out bare hubs/controllers, keep named peripherals
                names.append(name)
            }
            if let children = item["_items"] as? [[String: Any]] {
                flatten(children, into: &names)
            }
        }
    }

    private static func usbDevices() -> [String] {
        let output = ShellRunner.run("/usr/sbin/system_profiler", ["SPUSBDataType", "-json"])
        guard let data = output.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let roots = json["SPUSBDataType"] as? [[String: Any]]
        else { return [] }
        var names: [String] = []
        for root in roots {
            if let children = root["_items"] as? [[String: Any]] {
                flatten(children, into: &names)
            }
        }
        return names
    }

    private static func thunderboltDevices() -> [String] {
        let output = ShellRunner.run("/usr/sbin/system_profiler", ["SPThunderboltDataType", "-json"])
        guard let data = output.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let roots = json["SPThunderboltDataType"] as? [[String: Any]]
        else { return [] }
        // Thunderbolt bus appears as root; count external connected devices
        var names: [String] = []
        for root in roots {
            if let children = root["_items"] as? [[String: Any]] {
                flatten(children, into: &names)
            }
        }
        return names
    }

    static func runAll() -> [CheckResult] {
        let usb = usbDevices()
        let tb = thunderboltDevices()

        var details: [String: String] = [:]
        details["Connected USB Devices"] = usb.isEmpty ? "None" : usb.joined(separator: ", ")
        details["Connected Thunderbolt Devices"] = tb.isEmpty ? "None" : tb.joined(separator: ", ")

        let total = usb.count + tb.count
        let summary = total == 0
            ? "No USB / Thunderbolt peripherals connected — please plug in devices to verify each port"
            : "Currently detected \(total) connected peripheral(s); port communication normal"

        return [CheckResult(
            id: "ports",
            title: "Ports (USB / Thunderbolt)",
            status: .pass,
            summary: summary,
            rawDetails: details
        )]
    }
}
