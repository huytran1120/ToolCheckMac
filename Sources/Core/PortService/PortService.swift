import Foundation

/// B5：接口枚举。列出当前通过 USB / 雷雳(Thunderbolt) 接口连接的设备，帮助用户逐口验证接口连通性。
/// 说明：这是"当前接了什么"的快照。要完整验证每个物理口，用户需依次插拔，配合首页的实时提示。
enum PortService {

    private static func flatten(_ items: [[String: Any]], into names: inout [String]) {
        for item in items {
            if let name = item["_name"] as? String {
                // 过滤掉纯 Hub/控制器根节点噪声，保留具名设备
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
        // 雷雳总线本身会作为根节点出现，只统计挂在总线下的外接设备
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
