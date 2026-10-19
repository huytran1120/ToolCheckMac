import AppKit
import PDFKit
import XCTest
@testable import ToolCheckMacBook

@MainActor
final class ReportExporterTests: XCTestCase {
    private func report() -> ToolCheckMacBookReport {
        var report = ToolCheckMacBookReport(generatedAt: Date(), appVersion: "1.3.0")
        report.add(CheckResult(id: "battery.cycleCount.crosscheck", title: "Battery Cross-Check",
                               status: .redFlag, summary: "Synthetic mismatch", isRedFlagHeadline: "Synthetic warning"))
        return report
    }

    func testPNGRenderProducesValidImage() throws {
        let data = try ReportExporter.render(profile: nil, report: report(), format: .png, language: .english)
        let image = try XCTUnwrap(NSBitmapImageRep(data: data))
        XCTAssertGreaterThan(image.pixelsWide, 0)
        XCTAssertGreaterThan(image.pixelsHigh, 0)
    }

    func testPDFRenderProducesValidDocumentInBothLanguages() throws {
        for language in AppLanguage.allCases {
            let data = try ReportExporter.render(profile: nil, report: report(), format: .pdf, language: language)
            let provider = try XCTUnwrap(CGDataProvider(data: data as CFData))
            let pdf = try XCTUnwrap(CGPDFDocument(provider))
            XCTAssertEqual(pdf.numberOfPages, 1)
        }
    }

    func testWriteIsAtomicAndRejectsEmptyData() throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("toolcheck-export-test-\(UUID().uuidString).pdf")
        defer { try? FileManager.default.removeItem(at: file) }
        let data = try ReportExporter.render(profile: nil, report: report(), format: .pdf)
        try ReportExporter.write(data, to: file)
        XCTAssertEqual(try Data(contentsOf: file), data)
        XCTAssertThrowsError(try ReportExporter.write(Data(), to: file))
        XCTAssertEqual(try Data(contentsOf: file), data)
    }

    func testWriteFailureIsPropagated() {
        let missingParent = FileManager.default.temporaryDirectory
            .appendingPathComponent("toolcheck-missing-\(UUID().uuidString)")
            .appendingPathComponent("report.pdf")
        XCTAssertThrowsError(try ReportExporter.write(Data("report".utf8), to: missingParent))
    }

    func testMDMAdvisoryIsIncludedInPDFInBothLanguages() throws {
        let checks = ManagementService.managementResults(
            mdm: ManagementService.mdmEnrollmentStatus(rawOutput: "Enrolled via DEP: No\nMDM enrollment: No"),
            profileCount: 0,
            hosts: ManagementService.hostsMDMStatus(content: ""),
            sip: ManagementService.sipStatus(rawOutput: "System Integrity Protection status: enabled.")
        )
        let report = MacCheckReport(generatedAt: Date(), appVersion: "test", results: checks)
        let mdm = try XCTUnwrap(checks.first)
        for language in AppLanguage.allCases {
            let data = try ReportExporter.render(profile: nil, report: report, format: .pdf, language: language)
            let document = try XCTUnwrap(PDFDocument(data: data))
            let text = try XCTUnwrap(document.string)
            let advisory = try XCTUnwrap(mdm.localizedDisclaimer(in: language))
            let normalize: (String) -> String = {
                // PDFKit may extract the font's Vietnamese D-with-stroke as Latin Eth.
                $0.precomposedStringWithCanonicalMapping
                    .replacingOccurrences(of: "\u{00D0}", with: "\u{0110}")
                    .filter { !$0.isWhitespace }
            }
            if !normalize(text).contains(normalize(advisory)) {
                let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "com.adobe.pdf")
                attachment.name = "MDM advisory - \(language)"
                attachment.lifetime = .keepAlways
                add(attachment)
                XCTFail("Missing or clipped \(language) advisory.\nExtracted PDF text:\n\(text)")
            }
            XCTAssertFalse(text.contains("safe to purchase"))
            XCTAssertEqual(document.pageCount, 1)
        }
    }

    func testPNGLayoutExpandsToIncludeAdvisory() throws {
        let result = CheckResult(id: "management.mdm", title: "MDM", status: .pass, summary: "No enrollment")
        let original = MacCheckReport(generatedAt: Date(), appVersion: "test", results: [result])
        var withAdvisory = original
        withAdvisory.results[0].disclaimer = "Advisory"
        for language in AppLanguage.allCases {
            let before = try XCTUnwrap(NSBitmapImageRep(data: ReportExporter.render(
                profile: nil, report: original, format: .png, language: language
            )))
            let after = try XCTUnwrap(NSBitmapImageRep(data: ReportExporter.render(
                profile: nil, report: withAdvisory, format: .png, language: language
            )))
            XCTAssertEqual(after.pixelsWide, before.pixelsWide)
            XCTAssertGreaterThan(after.pixelsHigh, before.pixelsHigh)
        }
    }
}
