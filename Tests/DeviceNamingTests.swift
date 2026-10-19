import XCTest
@testable import ToolCheckMacBook

final class DeviceNamingTests: XCTestCase {

    func testSanitizeChineseAndFullWidthCharacters() {
        let dirty1 = "MacBook Pro（14 英寸，2021）"
        let clean1 = DeviceNaming.sanitize(dirty1)
        XCTAssertEqual(clean1, "MacBook Pro (14-inch, 2021)")

        let dirty2 = "iMac（24 英寸，M1，2021）"
        let clean2 = DeviceNaming.sanitize(dirty2)
        XCTAssertEqual(clean2, "iMac (24-inch, M1, 2021)")

        let dirty3 = "MacBook Air (13‑inch, M2, 2022)" // non-breaking hyphen
        let clean3 = DeviceNaming.sanitize(dirty3)
        XCTAssertEqual(clean3, "MacBook Air (13-inch, M2, 2022)")
    }

    func testIntelFallbackTable() {
        XCTAssertEqual(DeviceNaming.intelFallbackTable["MacBookPro16,1"], "MacBook Pro (16-inch, 2019)")
        XCTAssertEqual(DeviceNaming.intelFallbackTable["Macmini8,1"], "Mac mini (2018)")
        XCTAssertEqual(DeviceNaming.intelFallbackTable["iMacPro1,1"], "iMac Pro (2017)")
    }

    func testFriendlyNameFallback() {
        let fallback = DeviceNaming.friendlyName(fallbackMachineName: "MacBook Pro", identifier: "MacBookPro99,9")
        XCTAssertFalse(fallback.isEmpty)
    }
}
