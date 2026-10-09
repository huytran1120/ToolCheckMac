import Foundation
import IOKit

/// SMC 读数快照：精确温度（°C）与风扇转速（RPM）。
struct SMCReading: Sendable {
    var cpuTemp: Double?
    var gpuTemp: Double?
    var batteryTemp: Double?
    var fanRPMs: [Double] = []

    var maxTemp: Double? {
        [cpuTemp, gpuTemp].compactMap { $0 }.max()
    }
}

/// 通过 AppleSMC 读取温度与风扇。
/// 结构体用扁平字段 + 显式 padding 逐字节对齐内核 SMCKeyData_t（80 字节），
/// 嵌套结构体会因对齐规则少 4 字节导致调用失败——这是最易踩的坑。
enum SMCService {

    // 80 字节，已在 Apple Silicon(M1 Pro) 上验证读到真实温度/转速
    private struct Param {
        var key: UInt32 = 0
        var versMajor: UInt8 = 0
        var versMinor: UInt8 = 0
        var versBuild: UInt8 = 0
        var versReserved: UInt8 = 0
        var versRelease: UInt16 = 0
        var pad0: UInt16 = 0
        var pLimitVersion: UInt16 = 0
        var pLimitLength: UInt16 = 0
        var cpuPLimit: UInt32 = 0
        var gpuPLimit: UInt32 = 0
        var memPLimit: UInt32 = 0
        var keyInfoDataSize: UInt32 = 0
        var keyInfoDataType: UInt32 = 0
        var keyInfoDataAttributes: UInt8 = 0
        var pad1: UInt8 = 0
        var pad2: UInt16 = 0
        var result: UInt8 = 0
        var status: UInt8 = 0
        var data8: UInt8 = 0
        var pad3: UInt8 = 0
        var data32: UInt32 = 0
        var bytes = (UInt8(0),UInt8(0),UInt8(0),UInt8(0),UInt8(0),UInt8(0),UInt8(0),UInt8(0),
                     UInt8(0),UInt8(0),UInt8(0),UInt8(0),UInt8(0),UInt8(0),UInt8(0),UInt8(0),
                     UInt8(0),UInt8(0),UInt8(0),UInt8(0),UInt8(0),UInt8(0),UInt8(0),UInt8(0),
                     UInt8(0),UInt8(0),UInt8(0),UInt8(0),UInt8(0),UInt8(0),UInt8(0),UInt8(0))
    }

    // P 核心 / GPU / 电池温度候选键（Apple Silicon，读取存在的取最大）
    private static let cpuKeys = ["Tp01","Tp05","Tp09","Tp0D","Tp0T","Tp0X","Tp0b","Tp0f","Tp0j","Tp0n"]
    private static let gpuKeys = ["Tg05","Tg0D","Tg0L","Tg0T"]
    private static let batteryKeys = ["TB1T","TB2T","TB0T"]

    private static func fourCC(_ s: String) -> UInt32 {
        var r: UInt32 = 0
        for c in s.utf8 { r = (r << 8) + UInt32(c) }
        return r
    }

    private static func openConnection() -> io_connect_t? {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"))
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }
        var conn: io_connect_t = 0
        return IOServiceOpen(service, mach_task_self_, 0, &conn) == kIOReturnSuccess ? conn : nil
    }

    private static func call(_ conn: io_connect_t, _ input: inout Param) -> Param? {
        var output = Param()
        let inSize = MemoryLayout<Param>.stride
        var outSize = MemoryLayout<Param>.stride
        return IOConnectCallStructMethod(conn, 2, &input, inSize, &output, &outSize) == kIOReturnSuccess ? output : nil
    }

    private static func read(_ conn: io_connect_t, _ key: String) -> (type: String, bytes: [UInt8])? {
        var info = Param(); info.key = fourCC(key); info.data8 = 9
        guard let ki = call(conn, &info), ki.result == 0, ki.keyInfoDataSize > 0 else { return nil }
        let size = ki.keyInfoDataSize
        let typeCode = ki.keyInfoDataType
        var typeStr = ""
        for shift in stride(from: 24, through: 0, by: -8) {
            let c = UInt8((typeCode >> shift) & 0xff)
            if c > 0 { typeStr.append(Character(UnicodeScalar(c))) }
        }
        var rd = Param(); rd.key = fourCC(key); rd.keyInfoDataSize = size; rd.data8 = 5
        guard var out = call(conn, &rd), out.result == 0 else { return nil }
        let arr = withUnsafeBytes(of: &out.bytes) { Array($0.prefix(Int(size))) }
        return (typeStr, arr)
    }

    private static func number(_ conn: io_connect_t, _ key: String) -> Double? {
        guard let v = read(conn, key) else { return nil }
        let b = v.bytes
        switch v.type {
        case "flt ": return b.count >= 4 ? Double(b.withUnsafeBytes { $0.load(as: Float.self) }) : nil
        case "fpe2": return b.count >= 2 ? Double((UInt16(b[0]) << 8 | UInt16(b[1])) >> 2) : nil
        case "sp78": return b.count >= 2 ? Double(Int8(bitPattern: b[0])) + Double(b[1]) / 256 : nil
        default:
            var n = 0.0; for x in b { n = n * 256 + Double(x) }; return n
        }
    }

    private static func maxTemp(_ conn: io_connect_t, _ keys: [String]) -> Double? {
        keys.compactMap { number(conn, $0) }.filter { $0 > 5 && $0 < 130 }.max()
    }

    /// 读一次完整快照（打开→读→关闭）。nonisolated，可在任意线程调用；耗时亚毫秒级。
    static func snapshot() -> SMCReading? {
        guard let conn = openConnection() else { return nil }
        defer { IOServiceClose(conn) }
        var reading = SMCReading()
        reading.cpuTemp = maxTemp(conn, cpuKeys)
        reading.gpuTemp = maxTemp(conn, gpuKeys)
        reading.batteryTemp = maxTemp(conn, batteryKeys)
        if let n = number(conn, "FNum"), n > 0 {
            for i in 0..<Int(n) {
                if let rpm = number(conn, "F\(i)Ac"), rpm >= 0 { reading.fanRPMs.append(rpm) }
            }
        }
        // 台式机/无风扇机型也能返回温度，fanRPMs 为空即可
        if reading.cpuTemp == nil && reading.gpuTemp == nil && reading.fanRPMs.isEmpty {
            return nil
        }
        return reading
    }
}
