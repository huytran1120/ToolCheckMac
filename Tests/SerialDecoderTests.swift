import XCTest
@testable import ToolCheckMacBook

final class SerialDecoderTests: XCTestCase {

    func testLegacySerialDecoding() {
        // Legacy 12-char serial example where 4th char is year and 5th char is week
        // yearAlphabet: C(2010 first), D(2010 second), F(2011 first), G(2011 second)...
        // weekAlphabet: 1(1), 2(2)...
        let testSerial = "C02F1000ABCD" // F = 2011 (first half, yi=2), 1 = week 1
        let result = SerialDecoder.manufacture(from: testSerial)

        XCTAssertNotNil(result)
        if let m = result {
            XCTAssertEqual(m.year, 2011)
            XCTAssertEqual(m.week, 1)
        }
    }

    func testRandomizedSerialReturnsNil() {
        // Modern Apple 10-char randomized serial
        let randomizedSerial = "W9X7KQ29LP"
        let result = SerialDecoder.manufacture(from: randomizedSerial)
        XCTAssertNil(result)

        let desc = SerialDecoder.productionDescription(serial: randomizedSerial)
        XCTAssertTrue(desc.contains("Randomized"))
    }

    func testEmptySerial() {
        let desc = SerialDecoder.productionDescription(serial: "")
        XCTAssertEqual(desc, "Serial number unknown")
    }
}
