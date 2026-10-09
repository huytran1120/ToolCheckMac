import Foundation

/// Serial number production date decoder.
/// Prior to 2021, Apple used 11/12-character serial numbers, where the 4th and 5th characters encoded production year and week, decodable offline.
/// Starting in 2021, Apple transitioned to randomized serial numbers (typically 10 characters), which cannot be decoded offline.
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
        let half = yi % 2                 // 0 = first half of year, 1 = second half of year
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
