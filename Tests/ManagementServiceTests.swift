import XCTest
@testable import ToolCheckMacBook

final class ManagementServiceTests: XCTestCase {

    func testCleanHostsFile() {
        let cleanContent = """
        ##
        # Host Database
        #
        # localhost is used to configure the loopback interface
        # when the system is booting.  Do not change this entry.
        ##
        127.0.0.1\tlocalhost
        255.255.255.255\tbroadcasthost
        ::1             localhost
        """
        let status = ManagementService.hostsMDMStatus(content: cleanContent)
        XCTAssertEqual(status.hasOverrides, false)
        XCTAssertTrue(status.overriddenDomains.isEmpty)
    }

    func testHostsFileCommentedBypassIgnored() {
        let commentedContent = """
        # 127.0.0.1 albert.apple.com
        # 0.0.0.0 mdmenrollment.apple.com
        127.0.0.1 localhost
        """
        let status = ManagementService.hostsMDMStatus(content: commentedContent)
        XCTAssertEqual(status.hasOverrides, false)
        XCTAssertTrue(status.overriddenDomains.isEmpty)
    }

    func testHostsFileActiveOverridesDetected() {
        let bypassContent = """
        127.0.0.1 localhost
        0.0.0.0 albert.apple.com
        127.0.0.1 iprofiles.apple.com
        127.0.0.1 mdmenrollment.apple.com
        0.0.0.0 deviceenrollment.apple.com
        """
        let status = ManagementService.hostsMDMStatus(content: bypassContent)
        XCTAssertEqual(status.hasOverrides, true)
        XCTAssertEqual(status.overriddenDomains.count, 4)
        XCTAssertTrue(status.overriddenDomains.contains("albert.apple.com"))
        XCTAssertTrue(status.overriddenDomains.contains("iprofiles.apple.com"))
        XCTAssertTrue(status.overriddenDomains.contains("mdmenrollment.apple.com"))
        XCTAssertTrue(status.overriddenDomains.contains("deviceenrollment.apple.com"))
    }

    func testHostsIgnoresInlineCommentsAndDifferentHostnames() {
        for content in [
            "127.0.0.1 localhost # albert.apple.com is not blocked",
            "127.0.0.1 notalbert.apple.com",
            "127.0.0.1 albert.apple.com.example.test",
            "127.0.0.1 example.test # 0.0.0.0 mdmenrollment.apple.com",
        ] {
            let status = ManagementService.hostsMDMStatus(content: content)
            XCTAssertEqual(status.hasOverrides, false, content)
            XCTAssertTrue(status.rawMatches.isEmpty)
        }
    }

    func testHostsParsesIPv6AliasesCaseAndTrailingDot() {
        let status = ManagementService.hostsMDMStatus(content: """
        ::1 localhost ALBERT.APPLE.COM. iprofiles.apple.com # mdmenrollment.apple.com
        127.0.0.1 albert.apple.com
        """)
        XCTAssertEqual(status.hasOverrides, true)
        XCTAssertEqual(status.overriddenDomains, ["albert.apple.com", "iprofiles.apple.com"])
        XCTAssertEqual(status.rawMatches.count, 2)
        XCTAssertFalse(status.rawMatches.joined().contains("#"))
    }

    func testHostsRequiresValidIPAddress() {
        for address in ["invalid", "999.999.0.1", "albert.apple.com"] {
            XCTAssertEqual(
                ManagementService.hostsMDMStatus(content: "\(address) albert.apple.com").hasOverrides,
                false
            )
        }
        for address in ["0.0.0.0", "127.0.0.1", "::1", "::", "192.0.2.1", "::ffff:127.0.0.1"] {
            XCTAssertEqual(
                ManagementService.hostsMDMStatus(content: "\(address) albert.apple.com").hasOverrides,
                true
            )
        }
    }

    func testHostsReadErrorsRemainUnknownAndWarn() throws {
        for code in [CocoaError.Code.fileReadNoPermission, .fileReadNoSuchFile, .fileReadInapplicableStringEncoding] {
            let hosts = ManagementService.hostsMDMStatus(readContent: { throw CocoaError(code) })
            XCTAssertNil(hosts.hasOverrides)
            XCTAssertNotNil(hosts.readError)
            let result = try XCTUnwrap(results(hosts: hosts).first { $0.id == "management.hosts" })
            XCTAssertEqual(result.status, .warning)
            XCTAssertNotNil(result.rawDetails["Read Error"])
            XCTAssertNil(result.isRedFlagHeadline)
        }
    }

    func testSuccessfullyReadEmptyHostsIsNotAReadFailure() {
        let hosts = ManagementService.hostsMDMStatus(readContent: { "" })
        XCTAssertEqual(hosts.hasOverrides, false)
        XCTAssertNil(hosts.readError)
    }

    func testSIPStatusParsing() {
        let enabledOutput = "System Integrity Protection status: enabled."
        let disabledOutput = "System Integrity Protection status: disabled."
        let customOutput = "System Integrity Protection status: unknown / custom configuration."

        let enabledStatus = ManagementService.sipStatus(rawOutput: enabledOutput)
        XCTAssertEqual(enabledStatus.isEnabled, true)

        let disabledStatus = ManagementService.sipStatus(rawOutput: disabledOutput)
        XCTAssertEqual(disabledStatus.isEnabled, false)

        let customStatus = ManagementService.sipStatus(rawOutput: customOutput)
        XCTAssertNil(customStatus.isEnabled)
    }

    func testCustomAndFailedSIPChecksRemainUnknown() {
        for output in [
            "",
            "csrutil: failed to read status",
            "System Integrity Protection status: enabled (Custom Configuration).\nFilesystem Protections: disabled",
            "Unrelated status: enabled.",
        ] {
            XCTAssertNil(ManagementService.sipStatus(rawOutput: output).isEnabled, output)
        }
    }

    func testSIPResultsPreserveAllThreeEvidenceStates() throws {
        for (output, expectedValue) in [
            ("System Integrity Protection status: enabled.", "Yes"),
            ("System Integrity Protection status: disabled.", "No"),
            ("", "Unknown"),
            ("System Integrity Protection status: unknown (Custom Configuration).", "Unknown"),
        ] {
            let checks = ManagementService.managementResults(
                mdm: ManagementService.mdmEnrollmentStatus(rawOutput: "Enrolled via DEP: No\nMDM enrollment: No"),
                profileCount: 0,
                hosts: ManagementService.hostsMDMStatus(content: ""),
                sip: ManagementService.sipStatus(rawOutput: output)
            )
            let sip = try XCTUnwrap(checks.last)
            XCTAssertEqual(sip.id, "management.sip")
            XCTAssertEqual(sip.rawDetails["SIP Enabled"], expectedValue)
            XCTAssertEqual(sip.status, expectedValue == "Yes" ? .pass : .warning)
            XCTAssertEqual(sip.isRedFlagHeadline != nil, expectedValue == "No")
        }
    }

    func testManagementResultsIncludeSeparateChecksAndAdvisory() throws {
        let checks = results()
        XCTAssertEqual(checks.map(\.id), ["management.mdm", "management.hosts", "management.sip"])
        XCTAssertTrue(checks.allSatisfy { $0.status == .pass })
        let mdm = try XCTUnwrap(checks.first)
        XCTAssertTrue(try XCTUnwrap(mdm.disclaimer).contains("Erase All Content and Settings"))
        XCTAssertFalse(mdm.summary.contains("safe to purchase"))
    }

    func testHostsOverrideDoesNotInventMDMEnrollmentOrDoubleDeduct() {
        let checks = results(hosts: ManagementService.hostsMDMStatus(content: "0.0.0.0 albert.apple.com"))
        let report = MacCheckReport(generatedAt: Date(), appVersion: "test", results: checks)
        XCTAssertEqual(checks.first?.status, .pass)
        XCTAssertEqual(checks.first?.rawDetails["MDM Enrolled"], "No")
        XCTAssertEqual(report.redFlags.map(\.id), ["management.hosts"])
        XCTAssertEqual(report.score, 75)
    }

    func testConfirmedEnrollmentRemainsIndependentOfHostsOverrides() {
        let checks = results(
            hosts: ManagementService.hostsMDMStatus(content: "0.0.0.0 albert.apple.com"),
            mdmOutput: "Enrolled via DEP: Yes\nMDM enrollment: Yes (User Approved)"
        )
        let report = MacCheckReport(generatedAt: Date(), appVersion: "test", results: checks)
        XCTAssertEqual(report.redFlags.map(\.id), ["management.mdm", "management.hosts"])
        XCTAssertEqual(report.score, 50)
        XCTAssertFalse(checks[0].summary.contains("/etc/hosts"))
    }

    func testIncompleteEnrollmentOutputRemainsUnknown() {
        for output in ["", "MDM enrollment: No", "Enrolled via DEP: No\nMDM enrollment: NotAvailable"] {
            let checks = results(mdmOutput: output)
            XCTAssertEqual(checks[0].status, .warning, output)
            XCTAssertNil(checks[0].isRedFlagHeadline)
        }
    }

    func testDEPRecordRemainsAWarningWhenEnrollmentIsNotConfirmed() {
        for output in ["Enrolled via DEP: Yes\nMDM enrollment: No", "Enrolled via DEP: Yes"] {
            let checks = results(mdmOutput: output)
            XCTAssertEqual(checks[0].status, .warning)
            XCTAssertNotNil(checks[0].isRedFlagHeadline)
            XCTAssertFalse(checks[0].summary.contains("not currently managed"))
        }
    }

    private func results(
        hosts: ManagementService.HostsMDMStatus = ManagementService.hostsMDMStatus(content: ""),
        mdmOutput: String = "Enrolled via DEP: No\nMDM enrollment: No"
    ) -> [CheckResult] {
        ManagementService.managementResults(
            mdm: ManagementService.mdmEnrollmentStatus(rawOutput: mdmOutput),
            profileCount: 0,
            hosts: hosts,
            sip: ManagementService.sipStatus(rawOutput: "System Integrity Protection status: enabled.")
        )
    }
}
