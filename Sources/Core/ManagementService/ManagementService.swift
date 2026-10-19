import Foundation
import Darwin

/// Management and device lock checks: Detects MDM, Apple ID, and Activation Lock issues.
enum ManagementService {

    // MARK: - MDM Enrollment

    struct MDMEnrollmentStatus {
        var enrolledViaDEP: Bool?
        var mdmEnrolled: Bool?
        var rawOutput: String
    }

    static func mdmEnrollmentStatus(rawOutput: String? = nil) -> MDMEnrollmentStatus {
        let output = rawOutput ?? ShellRunner.run("/usr/bin/profiles", ["status", "-type", "enrollment"])
        func flag(after marker: String) -> Bool? {
            guard let line = output.components(separatedBy: .newlines)
                .map({ $0.trimmingCharacters(in: .whitespaces) })
                .first(where: { $0.hasPrefix(marker) }) else { return nil }
            let value = line.dropFirst(marker.count).split(whereSeparator: \.isWhitespace).first
            if value == "Yes" { return true }
            if value == "No" { return false }
            return nil
        }
        return MDMEnrollmentStatus(
            enrolledViaDEP: flag(after: "Enrolled via DEP:"),
            mdmEnrolled: flag(after: "MDM enrollment:"),
            rawOutput: output
        )
    }

    private static func installedConfigurationProfilesSummary() -> (count: Int?, rawOutput: String) {
        let output = ShellRunner.run("/usr/bin/profiles", ["list", "-all"])
        // Without root privileges, this command may return empty or permission error; handle gracefully.
        let profileLines = output.components(separatedBy: "\n").filter { $0.contains("profileIdentifier") }
        if output.isEmpty || output.lowercased().contains("you need to run this tool as root") {
            return (nil, output)
        }
        return (profileLines.count, output)
    }

    // MARK: - Sub-scanner: /etc/hosts Inspection

    struct HostsMDMStatus: Sendable {
        var overriddenDomains: [String]
        var rawMatches: [String]
        var readError: String?

        var hasOverrides: Bool? {
            readError == nil ? !overriddenDomains.isEmpty : nil
        }
    }

    private static let monitoredDomains = [
        "albert.apple.com",
        "iprofiles.apple.com",
        "mdmenrollment.apple.com",
        "deviceenrollment.apple.com"
    ]

    static func hostsMDMStatus(
        content: String? = nil,
        readContent: () throws -> String = { try String(contentsOfFile: "/etc/hosts", encoding: .utf8) }
    ) -> HostsMDMStatus {
        let text: String
        do {
            text = try content ?? readContent()
        } catch {
            return HostsMDMStatus(overriddenDomains: [], rawMatches: [], readError: error.localizedDescription)
        }

        var overridden: [String] = []
        var matches: [String] = []
        for line in text.components(separatedBy: .newlines) {
            let fields = line.prefix(while: { $0 != "#" }).split(whereSeparator: \.isWhitespace)
            guard fields.count >= 2, let address = fields.first, isIPAddress(String(address)) else { continue }
            let hostnames = fields.dropFirst().map {
                let hostname = $0.lowercased()
                return hostname.hasSuffix(".") ? String(hostname.dropLast()) : hostname
            }
            let matchedDomains = monitoredDomains.filter { hostnames.contains($0) }
            if !matchedDomains.isEmpty {
                matches.append(fields.joined(separator: " "))
                for domain in matchedDomains where !overridden.contains(domain) {
                    overridden.append(domain)
                }
            }
        }

        return HostsMDMStatus(
            overriddenDomains: overridden,
            rawMatches: matches,
            readError: nil
        )
    }

    private static func isIPAddress(_ address: String) -> Bool {
        var ipv4 = in_addr()
        var ipv6 = in6_addr()
        return address.withCString {
            inet_pton(AF_INET, $0, &ipv4) == 1 || inet_pton(AF_INET6, $0, &ipv6) == 1
        }
    }

    // MARK: - Sub-scanner: System Integrity Protection (SIP)

    struct SIPStatus: Sendable {
        var isEnabled: Bool?
        var rawOutput: String
    }

    static func sipStatus(rawOutput: String? = nil) -> SIPStatus {
        let output = rawOutput ?? ShellRunner.run("/usr/bin/csrutil", ["status"])
        switch output.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "system integrity protection status: enabled.", "system integrity protection status: enabled":
            return SIPStatus(isEnabled: true, rawOutput: output)
        case "system integrity protection status: disabled.", "system integrity protection status: disabled":
            return SIPStatus(isEnabled: false, rawOutput: output)
        default:
            return SIPStatus(isEnabled: nil, rawOutput: output)
        }
    }

    // MARK: - Apple ID / Find My Mac

    private static func isICloudAccountSignedIn() -> Bool {
        let output = ShellRunner.run("/usr/bin/defaults", ["read", "MobileMeAccounts", "Accounts"])
        return !output.isEmpty && output.contains("AccountID")
    }

    // MARK: - Activation Lock

    private static func activationLockStatus() -> String {
        let sp = HardwareProbe.systemProfilerHardwareJSON()
        return (sp["activation_lock_status"] as? String) ?? ""
    }

    // MARK: - Management Evidence

    static func managementResults(
        mdm: MDMEnrollmentStatus, profileCount: Int?, hosts: HostsMDMStatus, sip: SIPStatus
    ) -> [CheckResult] {
        var results: [CheckResult] = []
        var mdmDetails: [String: String] = [
            "DEP Automatic Enrollment": mdm.enrolledViaDEP.map { $0 ? "Yes" : "No" } ?? "Unknown",
            "MDM Enrolled": mdm.mdmEnrolled.map { $0 ? "Yes" : "No" } ?? "Unknown",
        ]
        if let count = profileCount {
            mdmDetails["Installed Configuration Profiles Count"] = "\(count)"
        } else {
            mdmDetails["Configuration Profiles List"] = "Administrator privileges required; full list could not be read"
        }
        let disclaimer = LocalizationManager.translate(key: "management.mdm.advisory", language: .english)

        // Enrollment and hosts overrides are independent evidence, not duplicate scoring inputs.
        if mdm.mdmEnrolled == true {
            results.append(CheckResult(
                id: "management.mdm",
                title: "MDM Device Supervision",
                status: .redFlag,
                summary: "This Mac is enrolled in MDM (Mobile Device Management)",
                rawDetails: mdmDetails,
                isRedFlagHeadline: LocalizationManager.translate(key: "management.mdm.enrolledHeadline", language: .english),
                disclaimer: disclaimer
            ))
        } else if mdm.enrolledViaDEP == true {
            results.append(CheckResult(
                id: "management.mdm",
                title: "MDM Device Supervision",
                status: .warning,
                summary: "DEP enrollment record found; setup or reinstallation may trigger automatic management",
                rawDetails: mdmDetails,
                isRedFlagHeadline: LocalizationManager.translate(key: "management.mdm.depHeadline", language: .english),
                disclaimer: disclaimer
            ))
        } else if mdm.mdmEnrolled == nil || mdm.enrolledViaDEP == nil {
            results.append(CheckResult(
                id: "management.mdm",
                title: "MDM Device Supervision",
                status: .warning,
                summary: "Unable to fully determine MDM/DEP status; inspect device management settings manually",
                rawDetails: mdmDetails,
                disclaimer: disclaimer
            ))
        } else {
            results.append(CheckResult(
                id: "management.mdm",
                title: "MDM Device Supervision",
                status: .pass,
                summary: LocalizationManager.translate(key: "management.mdm.notDetected", language: .english),
                rawDetails: mdmDetails,
                disclaimer: disclaimer
            ))
        }

        if let error = hosts.readError {
            results.append(CheckResult(
                id: "management.hosts",
                title: "Hosts File Integrity (/etc/hosts)",
                status: .warning,
                summary: LocalizationManager.translate(key: "management.hosts.unknown", language: .english),
                rawDetails: ["Read Error": error]
            ))
        } else if hosts.hasOverrides == true {
            results.append(CheckResult(
                id: "management.hosts",
                title: "Hosts File Integrity (/etc/hosts)",
                status: .redFlag,
                summary: LocalizationManager.translate(key: "management.hosts.overridden", language: .english),
                rawDetails: [
                    "Overridden Domains": hosts.overriddenDomains.joined(separator: ", "),
                    "Matched Lines": hosts.rawMatches.joined(separator: " | ")
                ],
                isRedFlagHeadline: LocalizationManager.translate(key: "management.hosts.headline", language: .english)
            ))
        } else {
            results.append(CheckResult(
                id: "management.hosts",
                title: "Hosts File Integrity (/etc/hosts)",
                status: .pass,
                summary: LocalizationManager.translate(key: "management.hosts.notDetected", language: .english),
                rawDetails: [
                    "Status": "No monitored overrides detected",
                    "Monitored Domains": monitoredDomains.joined(separator: ", ")
                ]
            ))
        }

        if sip.isEnabled == false {
            results.append(CheckResult(
                id: "management.sip",
                title: "System Integrity Protection (SIP)",
                status: .warning,
                summary: "System Integrity Protection (SIP) is disabled",
                rawDetails: ["SIP Enabled": "No", "SIP Status": sip.rawOutput],
                isRedFlagHeadline: LocalizationManager.translate(key: "management.sip.headline", language: .english)
            ))
        } else if sip.isEnabled == true {
            results.append(CheckResult(
                id: "management.sip",
                title: "System Integrity Protection (SIP)",
                status: .pass,
                summary: "System Integrity Protection (SIP) is enabled and active",
                rawDetails: ["SIP Enabled": "Yes", "SIP Status": sip.rawOutput]
            ))
        } else {
            results.append(CheckResult(
                id: "management.sip",
                title: "System Integrity Protection (SIP)",
                status: .warning,
                summary: "Unable to verify SIP status",
                rawDetails: ["SIP Enabled": "Unknown", "SIP Raw Output": sip.rawOutput]
            ))
        }

        return results
    }

    // MARK: - Summary Inspection

    static func runAll() -> [CheckResult] {
        var results = managementResults(
            mdm: mdmEnrollmentStatus(),
            profileCount: installedConfigurationProfilesSummary().count,
            hosts: hostsMDMStatus(),
            sip: sipStatus()
        )

        // Apple ID
        let signedIn = isICloudAccountSignedIn()
        results.append(CheckResult(
            id: "management.appleID",
            title: "Apple ID Sign-in Status",
            status: signedIn ? .warning : .pass,
            summary: signedIn ? "An Apple ID is currently signed in to this Mac; ensure it is signed out before purchasing" : "No signed-in Apple ID detected",
            rawDetails: ["iCloud Account": signedIn ? "Signed In" : "Signed Out"],
            isRedFlagHeadline: signedIn
                ? "⚠️ An Apple ID is still signed in to this Mac. If this is not your account, the previous owner has not signed out. The seller must sign out in \"System Settings > Users\" before transfer, or you will not be able to use iCloud and App Store services normally."
                : nil
        ))

        // Activation Lock
        let lockStatus = activationLockStatus()
        let isLocked = lockStatus.lowercased().contains("enabled")
        if !lockStatus.isEmpty {
            results.append(CheckResult(
                id: "management.activationLock",
                title: "Find My Mac / Activation Lock",
                status: isLocked ? .redFlag : .pass,
                summary: isLocked ? "Activation Lock is enabled" : "Activation Lock is disabled, ready for use",
                rawDetails: ["Activation Lock Raw Status": lockStatus],
                isRedFlagHeadline: isLocked
                    ? "⛔ Activation Lock (Find My Mac) is currently enabled on this machine. If the seller cannot disable it on the spot with their Apple ID password, this machine risks being locked permanently. Do not proceed with payment."
                    : nil
            ))
        }

        return results
    }
}
