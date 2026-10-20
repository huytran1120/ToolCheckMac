import XCTest
@testable import ToolCheckMacBook

@MainActor
final class LocalizationTests: XCTestCase {

    func testCaptureStatesAndErrorsAreLocalizedInBothLanguages() {
        let loc = LocalizationManager.shared
        let original = loc.currentLanguage
        defer { loc.currentLanguage = original }
        for language in [AppLanguage.english, .vietnamese] {
            loc.currentLanguage = language
            for phase in [CapturePhase.idle, .permission, .starting, .running, .stopping, .denied, .failed] {
                let key = "test.capture.\(phase.rawValue)"
                XCTAssertNotEqual(loc.t(key), key)
            }
            for error in [CaptureFailure.noDevice, .invalidFormat, .notRunning, .busy, .timedOut, .startFailed("Device error")] {
                XCTAssertFalse(error.localized(using: loc).contains("test.capture."))
            }
            XCTAssertNotEqual(loc.t("test.capture.permission"), loc.t("test.capture.starting"))
            XCTAssertTrue(CaptureFailure.startFailed("Device error").localized(using: loc).contains("Device error"))
        }
    }

    func testDictionarySymmetry() {
        let viKeys = Set(LocalizationManager.vietnameseStrings.keys)
        let enKeys = Set(LocalizationManager.englishStrings.keys)

        let missingInEn = viKeys.subtracting(enKeys)
        let missingInVi = enKeys.subtracting(viKeys)

        XCTAssertTrue(
            missingInEn.isEmpty,
            "The following keys exist in Vietnamese but are missing in English: \(missingInEn.sorted())"
        )
        XCTAssertTrue(
            missingInVi.isEmpty,
            "The following keys exist in English but are missing in Vietnamese: \(missingInVi.sorted())"
        )
    }

    func testNoEmptyTranslations() {
        for (key, val) in LocalizationManager.vietnameseStrings {
            XCTAssertFalse(val.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "Key '\(key)' has empty translation in Vietnamese")
        }
        for (key, val) in LocalizationManager.englishStrings {
            XCTAssertFalse(val.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "Key '\(key)' has empty translation in English")
        }
    }

    func testNoChineseInDictionaries() {
        let chineseRegex = try! NSRegularExpression(pattern: "[\\u4e00-\\u9fa5]")

        for (key, val) in LocalizationManager.vietnameseStrings {
            let range = NSRange(location: 0, length: val.utf16.count)
            let match = chineseRegex.firstMatch(in: val, options: [], range: range)
            XCTAssertNil(match, "Key '\(key)' in Vietnamese dictionary contains Chinese characters: \(val)")
        }

        for (key, val) in LocalizationManager.englishStrings {
            let range = NSRange(location: 0, length: val.utf16.count)
            let match = chineseRegex.firstMatch(in: val, options: [], range: range)
            XCTAssertNil(match, "Key '\(key)' in English dictionary contains Chinese characters: \(val)")
        }
    }

    func testDynamicLanguageSwitching() {
        let loc = LocalizationManager.shared
        
        loc.currentLanguage = .vietnamese
        XCTAssertEqual(loc.t("nav.overview"), "Tổng quan")
        XCTAssertEqual(loc.t("settings.about.title"), "Thông tin & Bản quyền")
        XCTAssertTrue(loc.t("settings.about.copyright").contains("huytran1120"))

        loc.currentLanguage = .english
        XCTAssertEqual(loc.t("nav.overview"), "Overview")
        XCTAssertEqual(loc.t("settings.about.title"), "About & License")
        XCTAssertTrue(loc.t("settings.about.copyright").contains("huytran1120"))
    }

    func testMissingKeyReturnsKeyItself() {
        let loc = LocalizationManager.shared
        let nonexistentKey = "some.random.key.that.does.not.exist"
        XCTAssertEqual(loc.t(nonexistentKey), nonexistentKey)
    }

    func testIntelWithoutT2IsNotTranslatedAsHavingT2() {
        let result = CheckResult(
            id: "hardware.securityChip", title: "Security Chip", status: .pass,
            summary: "Intel (No T2 Security Chip) — Earlier Intel hardware",
            rawDetails: ["Security Chip Tier": SecurityChipTier.intelNoT2.rawValue]
        )
        XCTAssertTrue(result.localizedSummary(in: .vietnamese).contains("Không có chip T2"))
        XCTAssertEqual(result.localizedSummary(in: .english), result.summary)
    }

    func testIntelWithT2AndAppleSiliconKeepTheirTier() {
        for tier in [SecurityChipTier.intelWithT2, .appleSilicon] {
            let result = CheckResult(id: "hardware.securityChip", title: "Security Chip", status: .pass,
                                     summary: tier.rawValue, rawDetails: ["Security Chip Tier": tier.rawValue])
            let translated = result.localizedSummary(in: .vietnamese)
            XCTAssertTrue(translated.contains(tier == .appleSilicon ? "Apple Silicon" : "có chip bảo mật T2"))
        }
    }

    func testMDMProbeFailureIsNotTranslatedAsDEPEnrollment() {
        let result = CheckResult(
            id: "management.mdm", title: "MDM", status: .warning,
            summary: "Unable to determine MDM status (command failed)",
            rawDetails: ["DEP Automatic Enrollment": "Unknown", "MDM Enrolled": "Unknown"]
        )
        XCTAssertFalse(result.localizedSummary(in: .vietnamese).contains("Phát hiện bản ghi Apple DEP"))
        XCTAssertTrue(result.localizedSummary(in: .vietnamese).contains("Chưa xác định"))
        XCTAssertEqual(result.localizedSummary(in: .english), result.summary)
    }

    func testConfirmedDEPWarningRemainsExplicit() {
        let result = CheckResult(id: "management.mdm", title: "MDM", status: .warning,
                                 summary: "DEP enrollment record found",
                                 rawDetails: ["DEP Automatic Enrollment": "Yes", "MDM Enrolled": "No"])
        XCTAssertTrue(result.localizedSummary(in: .vietnamese).contains("Phát hiện bản ghi Apple DEP"))
    }

    func testIncompleteSerialAndSMARTTranslationsDoNotClaimSuccess() {
        let serial = HardwareProbe.serialResult(ioSerial: "TEST-SERIAL", spSerial: "")
        XCTAssertTrue(serial.localizedSummary(in: .vietnamese).contains("Không đủ dữ liệu"))
        let storage = StorageService.result(for: [:])
        XCTAssertTrue(storage.localizedSummary(in: .vietnamese).contains("Chưa xác minh"))
    }

    func testSIPUnknownAndCustomStatesAreNotTranslatedAsDisabled() {
        for details in [
            ["SIP Enabled": "Unknown", "SIP Raw Output": ""],
            ["SIP Raw Output": "System Integrity Protection status: unknown (Custom Configuration)."],
            ["SIP Status": "System Integrity Protection status: enabled (Custom Configuration)."],
        ] {
            let result = CheckResult(id: "management.sip", title: "SIP", status: .warning,
                                     summary: "Unable to verify SIP status", rawDetails: details)
            XCTAssertTrue(result.localizedSummary(in: .vietnamese).contains("Chưa xác minh"))
            XCTAssertFalse(result.localizedSummary(in: .vietnamese).contains("đang tắt"))
            XCTAssertTrue(result.localizedSummary(in: .english).contains("Unable to verify"))
            XCTAssertNil(result.localizedHeadline(in: .vietnamese))
        }
    }

    func testSIPKnownAndLegacyStatesKeepTheirMeaningInBothLanguages() {
        for enabled in [true, false] {
            let output = "System Integrity Protection status: \(enabled ? "enabled" : "disabled")."
            for details in [
                ["SIP Enabled": enabled ? "Yes" : "No", "SIP Status": output],
                ["SIP Status": output],
            ] {
                let result = CheckResult(id: "management.sip", title: "SIP",
                                         status: enabled ? .pass : .warning,
                                         summary: output, rawDetails: details)
                XCTAssertTrue(result.localizedSummary(in: .english).contains(enabled ? "is enabled" : "is disabled"))
                XCTAssertTrue(result.localizedSummary(in: .vietnamese).contains(enabled ? "đang bật" : "đang tắt"))
            }
        }
    }

    func testHostsReadFailureIsNotTranslatedAsClean() {
        let result = CheckResult(id: "management.hosts", title: "Hosts", status: .warning,
                                 summary: "Unable to read", rawDetails: ["Read Error": "Synthetic error"])
        XCTAssertTrue(result.localizedSummary(in: .vietnamese).contains("Không đọc được"))
        XCTAssertTrue(result.localizedSummary(in: .english).contains("Unable to read"))
        XCTAssertNil(result.localizedHeadline(in: .english))
    }

    func testLegacyVietnameseHeadlinesAreTranslatedAndDoNotClaimCertainBypass() throws {
        let hosts = CheckResult(
            id: "management.hosts", title: "Hosts", status: .redFlag, summary: "Legacy summary",
            rawDetails: ["Blocked Domains": "albert.apple.com"],
            isRedFlagHeadline: "Cảnh báo /etc/hosts: 100% bypass"
        )
        let mdm = CheckResult(id: "management.mdm", title: "MDM", status: .redFlag,
                              summary: "Apple servers blocked in /etc/hosts",
                              isRedFlagHeadline: "Cảnh báo /etc/hosts: 100% bypass")
        let sip = CheckResult(id: "management.sip", title: "SIP", status: .warning,
                              summary: "SIP disabled", rawDetails: ["SIP Status": "System Integrity Protection status: disabled."],
                              isRedFlagHeadline: "SIP đã bị TẮT")
        for result in [hosts, mdm, sip] {
            let english = try XCTUnwrap(result.localizedHeadline(in: .english))
            let vietnamese = try XCTUnwrap(result.localizedHeadline(in: .vietnamese))
            XCTAssertNotEqual(english, vietnamese)
            XCTAssertFalse(english.contains("Cảnh báo"))
            XCTAssertFalse(english.contains("TẮT"))
            XCTAssertFalse(english.contains("100%"))
            XCTAssertFalse(vietnamese.contains("100%"))
            XCTAssertTrue(english.contains(result.id == "management.sip" ? "does not by itself prove" : "not proof"))
        }
        for language in AppLanguage.allCases {
            XCTAssertTrue(hosts.localizedSummary(in: language).contains("albert.apple.com"))
        }
    }

    func testAdvisoryExplainsConsentBackupAndIntelWithoutT2() throws {
        let result = CheckResult(id: "management.mdm", title: "MDM", status: .pass,
                                 summary: "No MDM enrollment detected, safe to purchase",
                                 disclaimer: "Legacy claim of absolute certainty")
        let english = try XCTUnwrap(result.localizedDisclaimer(in: .english))
        let vietnamese = try XCTUnwrap(result.localizedDisclaimer(in: .vietnamese))
        for text in [english, vietnamese] {
            XCTAssertTrue(text.contains("Apple Silicon"))
            XCTAssertTrue(text.contains("T2"))
            XCTAssertTrue(text.contains("macOS Recovery"))
            XCTAssertFalse(text.contains("absolute certainty"))
            XCTAssertFalse(text.contains("an toàn tuyệt đối"))
        }
        XCTAssertTrue(english.contains("owner's consent and a backup"))
        XCTAssertTrue(english.contains("Intel without T2"))
        XCTAssertTrue(vietnamese.contains("đồng ý và sao lưu"))
        XCTAssertTrue(vietnamese.contains("Intel không có T2"))
        XCTAssertFalse(result.localizedSummary(in: .english).contains("safe to purchase"))
        XCTAssertFalse(result.localizedSummary(in: .vietnamese).contains("an tâm mua"))
    }
}
