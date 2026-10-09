import Foundation

/// User-friendly machine marketing name resolution.
/// Apple Silicon Macs store the full marketing name (including screen size and year) directly
/// in the device tree `product-name` node, e.g. "MacBook Pro (14-inch, 2021)".
/// This is the most reliable offline source, avoiding the need for large mapping tables.
/// Older Intel Macs may lack this node, falling back to a compact table + system_profiler machine_name.
enum DeviceNaming {

    /// Reads raw marketing name from IORegistry `product-name` (e.g., "MacBook Pro (14-inch, 2021)").
    static func rawMarketingName() -> String {
        let output = ShellRunner.run("/usr/sbin/ioreg", ["-ar", "-k", "product-name"])
        guard let data = output.data(using: .utf8),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [[String: Any]],
              let nameData = plist.first?["product-name"] as? Data
        else { return "" }
        // data content is a null-terminated ASCII string
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

    /// Fallback table for Intel Macs that may lack the product-name device tree node.
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
