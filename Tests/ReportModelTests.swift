import XCTest
@testable import ToolCheckMacBook

final class ReportModelTests: XCTestCase {

    func testScoreCalculation() {
        var report = ToolCheckMacBookReport(generatedAt: Date(), appVersion: "1.3.0")
        
        // Empty report defaults to 100
        XCTAssertEqual(report.score, 100)

        // All passing results
        report.add(CheckResult(id: "battery", title: "Battery", status: .pass, summary: "Normal"))
        report.add(CheckResult(id: "display", title: "Display", status: .pass, summary: "Normal"))
        XCTAssertEqual(report.score, 100)

        // 1 warning deduction: -8 points
        report.add(CheckResult(id: "disk", title: "Disk", status: .warning, summary: "Moderate wear"))
        XCTAssertEqual(report.score, 92)

        // 1 red flag deduction: -25 points (100 - 8 - 25 = 67)
        report.add(CheckResult(id: "mdm", title: "MDM", status: .redFlag, summary: "MDM detected"))
        XCTAssertEqual(report.score, 67)

        // Skipped and unsupported do not deduce score
        report.add(CheckResult(id: "touchid", title: "Touch ID", status: .skipped, summary: "Skipped"))
        report.add(CheckResult(id: "cellular", title: "Cellular", status: .unsupported, summary: "N/A"))
        XCTAssertEqual(report.score, 67)
    }

    func testScoreFloorAtZero() {
        var report = ToolCheckMacBookReport(generatedAt: Date(), appVersion: "1.3.0")
        for i in 0..<5 {
            report.add(CheckResult(id: "redflag_\(i)", title: "Flag", status: .redFlag, summary: "Critical"))
        }
        // 5 * 25 = 125 deductions, score must clamp to 0
        XCTAssertEqual(report.score, 0)
    }

    func testRedFlagsIsolation() {
        var report = ToolCheckMacBookReport(generatedAt: Date(), appVersion: "1.3.0")
        report.add(CheckResult(id: "pass1", title: "Pass", status: .pass, summary: "OK"))
        report.add(CheckResult(id: "warn1", title: "Warn", status: .warning, summary: "Warn"))
        report.add(CheckResult(id: "red1", title: "Red 1", status: .redFlag, summary: "Critical 1"))
        report.add(CheckResult(id: "red2", title: "Red 2", status: .redFlag, summary: "Critical 2"))

        XCTAssertEqual(report.redFlags.count, 2)
        XCTAssertEqual(report.redFlags.map(\.id), ["red1", "red2"])
    }

    @MainActor
    func testBatteryCycleCountMismatchReachesCategoryAndReport() throws {
        let model = AppModel(historyURL: FileManager.default.temporaryDirectory
            .appendingPathComponent("toolcheck-report-test-\(UUID().uuidString)/history.json"))
        model.recordTest(CheckResult(
            id: "battery.cycleCount", title: "Battery Cycle Count",
            status: .pass, summary: "100 cycles"
        ))
        model.recordTest(CheckResult(
            id: "battery.health", title: "Battery Health",
            status: .pass, summary: "Health approx. 95%"
        ))
        XCTAssertEqual(model.status(for: .battery), .pass)
        XCTAssertEqual(model.report.score, 100)
        XCTAssertTrue(model.report.redFlags.isEmpty)

        let mismatch = CheckResult(
            id: "battery.cycleCount.crosscheck",
            title: "Battery Cycle Count Cross-Check",
            status: .redFlag,
            summary: "Cycle count differs between detection methods (100 vs 200)",
            rawDetails: ["IOKit Read": "100", "ioreg Read": "200"],
            isRedFlagHeadline: "Battery cycle count results differ between detection methods"
        )
        model.recordTest(mismatch)

        XCTAssertEqual(model.results(for: .battery).map(\.id), [
            "battery.cycleCount", "battery.health", mismatch.id,
        ])
        XCTAssertEqual(model.status(for: .battery), .redFlag)
        XCTAssertEqual(model.report.redFlags.map(\.id), [mismatch.id])
        XCTAssertEqual(model.report.redFlags.first?.isRedFlagHeadline, mismatch.isRedFlagHeadline)
        XCTAssertEqual(model.report.score, 75)

        let data = try JSONEncoder().encode(model.report)
        let decoded = try JSONDecoder().decode(ToolCheckMacBookReport.self, from: data)
        XCTAssertEqual(decoded.redFlags.map(\.id), [mismatch.id])
        XCTAssertEqual(decoded.redFlags.first?.rawDetails, mismatch.rawDetails)
        XCTAssertEqual(decoded.score, 75)
    }

    func testCodableRoundTrip() throws {
        var report = ToolCheckMacBookReport(generatedAt: Date(), appVersion: "1.3.0")
        report.add(CheckResult(
            id: "battery.health",
            title: "Battery Health",
            status: .pass,
            summary: "Normal (98%)",
            rawDetails: ["CycleCount": "42", "Health": "98%"],
            isRedFlagHeadline: nil
        ))

        let encoder = JSONEncoder()
        let data = try encoder.encode(report)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(ToolCheckMacBookReport.self, from: data)

        XCTAssertEqual(decoded.appVersion, "1.3.0")
        XCTAssertEqual(decoded.results.count, 1)
        XCTAssertEqual(decoded.results.first?.id, "battery.health")
        XCTAssertEqual(decoded.results.first?.rawDetails["CycleCount"], "42")
    }

    func testStatusEmojis() {
        XCTAssertEqual(CheckStatus.pass.emoji, "✅")
        XCTAssertEqual(CheckStatus.warning.emoji, "⚠️")
        XCTAssertEqual(CheckStatus.redFlag.emoji, "⛔")
        XCTAssertEqual(CheckStatus.skipped.emoji, "⏭️")
        XCTAssertEqual(CheckStatus.unsupported.emoji, "➖")
    }

    @MainActor
    func testManagementEvidenceReachesSecurityAndRoundTripsWithoutDuplicatePenalty() throws {
        let results = ManagementService.managementResults(
            mdm: ManagementService.mdmEnrollmentStatus(rawOutput: "Enrolled via DEP: No\nMDM enrollment: No"),
            profileCount: 0,
            hosts: ManagementService.hostsMDMStatus(content: "0.0.0.0 albert.apple.com"),
            sip: ManagementService.sipStatus(rawOutput: "System Integrity Protection status: enabled.")
        )
        let model = AppModel(historyURL: FileManager.default.temporaryDirectory
            .appendingPathComponent("toolcheck-report-test-\(UUID().uuidString)/history.json"))
        results.forEach { model.recordTest($0) }
        XCTAssertEqual(model.results(for: .security).map(\.id), ["management.mdm", "management.hosts", "management.sip"])
        XCTAssertEqual(model.status(for: .security), .redFlag)
        XCTAssertEqual(model.report.score, 75)
        XCTAssertEqual(model.report.redFlags.map(\.id), ["management.hosts"])

        let decoded = try JSONDecoder().decode(MacCheckReport.self, from: JSONEncoder().encode(model.report))
        XCTAssertEqual(decoded.score, 75)
        XCTAssertEqual(decoded.results.first?.disclaimer, results.first?.disclaimer)
        XCTAssertEqual(decoded.redFlags.first?.rawDetails["Overridden Domains"], "albert.apple.com")
    }

    func testLegacyResultWithoutAdvisoryStillDecodes() throws {
        let data = Data("""
        {"id":"management.mdm","title":"MDM","status":"pass","summary":"No enrollment","rawDetails":{}}
        """.utf8)
        let result = try JSONDecoder().decode(CheckResult.self, from: data)
        XCTAssertNil(result.disclaimer)
        XCTAssertEqual(result.status, .pass)
    }
}
