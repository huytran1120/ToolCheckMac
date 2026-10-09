import Foundation
import CoreWLAN

/// A8/B7-8：无线连接。Wi-Fi 当前连接信息走 CoreWLAN（原生框架），蓝牙控制器状态走 system_profiler。
enum NetworkService {

    // MARK: - Wi-Fi

    private static func wifiResult() -> CheckResult {
        guard let iface = CWWiFiClient.shared().interface() else {
            return CheckResult(
                id: "network.wifi",
                title: "Wi-Fi",
                status: .unsupported,
                summary: "No Wi-Fi interface detected"
            )
        }

        var details: [String: String] = [:]
        let powerOn = iface.powerOn()
        details["Wi-Fi Switch"] = powerOn ? "Enabled" : "Disabled"
        if let hw = iface.hardwareAddress() { details["Network Adapter MAC"] = hw }

        if let ssid = iface.ssid() {
            details["Current Network"] = ssid
            let rssi = iface.rssiValue()
            details["Signal Strength (RSSI)"] = "\(rssi) dBm"
            details["Transmit Rate"] = "\(iface.transmitRate()) Mbps"
            details["PHY Mode"] = phyModeString(iface.activePHYMode())
            let quality = rssi >= -60 ? "Strong signal" : (rssi >= -75 ? "Fair signal" : "Weak signal")
            return CheckResult(
                id: "network.wifi",
                title: "Wi-Fi",
                status: .pass,
                summary: "Connected to \"\(ssid)\" · \(rssi) dBm · \(quality)",
                rawDetails: details
            )
        }

        return CheckResult(
            id: "network.wifi",
            title: "Wi-Fi",
            status: powerOn ? .pass : .warning,
            summary: powerOn ? "Wi-Fi is on but not connected to a network, adapter working normally" : "Wi-Fi is currently turned off",
            rawDetails: details
        )
    }

    private static func phyModeString(_ mode: CWPHYMode) -> String {
        switch mode {
        case .mode11a: return "802.11a"
        case .mode11b: return "802.11b"
        case .mode11g: return "802.11g"
        case .mode11n: return "802.11n (Wi-Fi 4)"
        case .mode11ac: return "802.11ac (Wi-Fi 5)"
        case .mode11ax: return "802.11ax (Wi-Fi 6/6E)"
        case .modeNone: return "Not Connected"
        @unknown default: return "Unknown"
        }
    }

    // MARK: - 蓝牙

    private static func bluetoothResult() -> CheckResult {
        let output = ShellRunner.run("/usr/sbin/system_profiler", ["SPBluetoothDataType", "-json"])
        guard let data = output.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let items = json["SPBluetoothDataType"] as? [[String: Any]],
              let first = items.first,
              let ctrl = first["controller_properties"] as? [String: Any]
        else {
            return CheckResult(
                id: "network.bluetooth",
                title: "Bluetooth",
                status: .warning,
                summary: "Unable to read Bluetooth controller status"
            )
        }

        let state = (ctrl["controller_state"] as? String) ?? ""
        let chipset = (ctrl["controller_chipset"] as? String) ?? ""
        let address = (ctrl["controller_address"] as? String) ?? ""
        let isOn = state.contains("on")

        var details: [String: String] = [
            "Controller State": isOn ? "Enabled" : "Disabled",
            "Bluetooth Chipset": chipset,
            "Bluetooth Address": address,
        ]
        if let connected = first["device_connected"] as? [[String: Any]] {
            details["Connected Devices"] = "\(connected.count)"
        }

        return CheckResult(
            id: "network.bluetooth",
            title: "Bluetooth",
            status: isOn ? .pass : .warning,
            summary: isOn ? "Bluetooth controller operational (\(chipset))" : "Bluetooth is currently turned off, RF cannot be verified",
            rawDetails: details
        )
    }

    static func runAll() -> [CheckResult] {
        [wifiResult(), bluetoothResult()]
    }
}
