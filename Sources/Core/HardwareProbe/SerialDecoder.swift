import Foundation

/// 序列号生产日期解码。
/// 2021 年前 Apple 使用 11/12 位序列号，其中第 4、5 位编码了生产年份与周次，可本地解码。
/// 2021 年起 Apple 改用随机化序列号（通常 10 位），**无法**本地推算日期——诚实告知，不臆造。
enum SerialDecoder {

    struct Manufacture {
        let year: Int
        let week: Int
    }

    private static let yearAlphabet = Array("CDFGHJKLMNPQRSTVWXYZ")
    private static let weekAlphabet = Array("123456789CDFGHJKLMNPQRTVWXY")

    static func manufacture(from serial: String) -> Manufacture? {
        let s = serial.uppercased()
        guard s.count == 11 || s.count == 12 else { return nil }
        let chars = Array(s)
        let yearChar = chars[3]
        let weekChar = chars[4]
        guard let yi = yearAlphabet.firstIndex(of: yearChar),
              let wi = weekAlphabet.firstIndex(of: weekChar) else { return nil }
        let year = 2010 + yi / 2
        let half = yi % 2                 // 0 = 上半年, 1 = 下半年
        let week = (half == 1 ? 26 : 0) + (wi + 1)
        return Manufacture(year: year, week: min(week, 53))
    }

    /// Returns user-friendly manufacture date estimate. Randomized serials explicitly state why they cannot be decoded offline.
    static func productionDescription(serial: String) -> String {
        guard !serial.isEmpty else { return "Serial number unknown" }
        if let m = manufacture(from: serial) {
            return "Approx. \(m.year), Week \(m.week) (estimated from serial)"
        }
        return "Randomized serial number; cannot be estimated offline. Please verify on Apple's official coverage page"
    }
}
