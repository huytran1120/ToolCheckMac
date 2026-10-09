import Foundation

/// 机型友好名解析。
/// Apple Silicon 机器在设备树 `product-name` 节点里直接存了完整营销名（含屏幕尺寸与年份），
/// 例如 "MacBook Pro (14-inch, 2021)"——这是最可靠的离线来源，无需维护庞大的型号对照表。
/// Intel 老机型可能没有该节点，用一张小对照表 + system_profiler 的 machine_name 兜底。
enum DeviceNaming {

    /// 从 IORegistry `product-name` 读原始营销名（英文，如 "MacBook Pro (14-inch, 2021)"）。
    static func rawMarketingName() -> String {
        let output = ShellRunner.run("/usr/sbin/ioreg", ["-ar", "-k", "product-name"])
        guard let data = output.data(using: .utf8),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [[String: Any]],
              let nameData = plist.first?["product-name"] as? Data
        else { return "" }
        // data 内容是以 NUL 结尾的 ASCII 字符串
        return String(decoding: nameData, as: UTF8.self)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\0").union(.whitespaces))
    }

    /// Returns a clean English marketing name.
    /// "MacBook Pro (14-inch, 2021)"
    static func friendlyName(fallbackMachineName: String, identifier: String) -> String {
        var name = rawMarketingName()
        if name.isEmpty { name = intelFallbackTable[identifier] ?? "" }
        if name.isEmpty { name = fallbackMachineName.isEmpty ? identifier : fallbackMachineName }
        return sanitize(name)
    }

    private static func sanitize(_ input: String) -> String {
        var s = input
        s = s.replacingOccurrences(of: "‑inch", with: "-inch") // non-breaking hyphen
        s = s.replacingOccurrences(of: " 英寸", with: "-inch")
        s = s.replacingOccurrences(of: "英寸", with: "-inch")
        s = s.replacingOccurrences(of: "（", with: " (")
        s = s.replacingOccurrences(of: "）", with: ")")
        s = s.replacingOccurrences(of: "，", with: ", ")
        while s.contains("  ") {
            s = s.replacingOccurrences(of: "  ", with: " ")
        }
        return s.trimmingCharacters(in: .whitespaces)
    }

    /// 少量 Intel 机型兜底（这些机器多半没有 product-name 设备树节点）。
    private static let intelFallbackTable: [String: String] = [
        "MacBookPro16,1": "MacBook Pro (16-inch, 2019)",
        "MacBookPro16,2": "MacBook Pro (13-inch, 2020)",
        "MacBookPro15,1": "MacBook Pro (15-inch, 2018)",
        "MacBookPro15,2": "MacBook Pro (13-inch, 2019)",
        "MacBookAir9,1": "MacBook Air (2020)",
        "MacBookAir8,2": "MacBook Air (2019)",
        "Macmini8,1": "Mac mini (2018)",
        "iMac20,1": "iMac (27-inch, 2020)",
        "iMac19,1": "iMac (27-inch, 2019)",
        "iMacPro1,1": "iMac Pro (2017)",
    ]
}
