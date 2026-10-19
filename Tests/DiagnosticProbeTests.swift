import XCTest
@testable import ToolCheckMacBook

final class DiagnosticProbeTests: XCTestCase {
    func testMissingOrUnknownSMARTNeverPasses() {
        for value in ["", "Unknown", "Not Supported", "unexpected"] {
            let result = StorageService.result(for: ["device_model": "Synthetic SSD", "smart_status": value])
            XCTAssertEqual(result.status, .warning, value)
            XCTAssertNil(result.isRedFlagHeadline)
        }
        XCTAssertEqual(StorageService.result(for: [:]).status, .warning)
    }

    func testVerifiedSMARTPassesAndPreservesCapacity() {
        let result = StorageService.result(for: [
            "device_model": "Synthetic SSD", "size": "512 GB", "smart_status": " Verified \n",
        ], availableBytes: 100_000_000_000)
        XCTAssertEqual(result.status, .pass)
        XCTAssertEqual(result.rawDetails["Available Space"], "100.0 GB")
        XCTAssertEqual(result.rawDetails["Capacity"], "512 GB")
    }

    func testFailingSMARTIsCritical() {
        for value in ["Failing", "FAILED"] {
            let result = StorageService.result(for: ["smart_status": value])
            XCTAssertEqual(result.status, .redFlag)
            XCTAssertNotNil(result.isRedFlagHeadline)
        }
    }

    func testSerialCrossCheckRequiresBothSources() {
        for pair in [("", ""), ("TEST-SERIAL-A", ""), ("", "TEST-SERIAL-A")] {
            let result = HardwareProbe.serialResult(ioSerial: pair.0, spSerial: pair.1)
            XCTAssertEqual(result.status, .warning)
            XCTAssertFalse(result.summary.contains("matches across"))
        }
    }

    func testMatchingSerialsPass() {
        let result = HardwareProbe.serialResult(ioSerial: "TEST-SERIAL-A", spSerial: "TEST-SERIAL-A")
        XCTAssertEqual(result.status, .pass)
    }

    func testMismatchedSerialsAreCritical() {
        let result = HardwareProbe.serialResult(ioSerial: "TEST-SERIAL-A", spSerial: "TEST-SERIAL-B")
        XCTAssertEqual(result.status, .redFlag)
        XCTAssertNotNil(result.isRedFlagHeadline)
    }
}
