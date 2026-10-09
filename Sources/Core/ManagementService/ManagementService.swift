import Foundation

/// Management and device lock checks: Detects MDM, Apple ID, and Activation Lock issues.
/// Any critical finding triggers a red flag, as system reinstall will not bypass these restrictions.
enum ManagementService {

    // MARK: - MDM Enrollment

    private struct MDMEnrollmentStatus {
        var enrolledViaDEP: Bool?
        var mdmEnrolled: Bool?
        var rawOutput: String
    }

    private static func mdmEnrollmentStatus() -> MDMEnrollmentStatus {
        let output = ShellRunner.run("/usr/bin/profiles", ["status", "-type", "enrollment"])
        func flag(after marker: String) -> Bool? {
            guard let range = output.range(of: marker) else { return nil }
            let tail = output[range.upperBound...].trimmingCharacters(in: .whitespaces)
            if tail.hasPrefix("Yes") { return true }
            if tail.hasPrefix("No") { return false }
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

    // MARK: - Summary Inspection

    static func runAll() -> [CheckResult] {
        var results: [CheckResult] = []

        // MDM
        let mdm = mdmEnrollmentStatus()
        let profiles = installedConfigurationProfilesSummary()
        var mdmDetails: [String: String] = [
            "DEP Automatic Enrollment": mdm.enrolledViaDEP.map { $0 ? "Yes" : "No" } ?? "Unknown",
            "MDM Enrolled": mdm.mdmEnrolled.map { $0 ? "Yes" : "No" } ?? "Unknown",
        ]
        if let count = profiles.count {
            mdmDetails["Installed Configuration Profiles Count"] = "\(count)"
        } else {
            mdmDetails["Configuration Profiles List"] = "Administrator privileges required; full list could not be read"
        }

        if mdm.mdmEnrolled == true {
            results.append(CheckResult(
                id: "management.mdm",
                title: "MDM Device Supervision",
                status: .redFlag,
                summary: "This Mac is enrolled in MDM (Mobile Device Management)",
                rawDetails: mdmDetails,
                isRedFlagHeadline: "⛔ This machine is enrolled in an enterprise or educational MDM system. The organization can remotely enforce restrictions or erase data, and reinstalling macOS will not remove it (especially with DEP automatic enrollment). Strongly discouraged from purchasing unless the seller provides proof of release from the organization."
            ))
        } else if mdm.enrolledViaDEP == true {
            results.append(CheckResult(
                id: "management.mdm",
                title: "MDM Device Supervision",
                status: .warning,
                summary: "DEP enrollment record found; not currently managed, but reinstallation may trigger automatic re-enrollment",
                rawDetails: mdmDetails,
                isRedFlagHeadline: "⚠️ This device is registered in Apple DEP. Reinstalling macOS over the network may automatically re-enroll it under the original organization. Ask the seller to have the device removed from DEP before transaction."
            ))
        } else if mdm.mdmEnrolled == nil {
            results.append(CheckResult(
                id: "management.mdm",
                title: "MDM Device Supervision",
                status: .warning,
                summary: "Unable to determine MDM status (command failed); manual check in \"System Settings > Privacy & Security > Profiles\" recommended",
                rawDetails: mdmDetails
            ))
        } else {
            results.append(CheckResult(
                id: "management.mdm",
                title: "MDM Device Supervision",
                status: .pass,
                summary: "No MDM enrollment detected, safe to purchase",
                rawDetails: mdmDetails
            ))
        }

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
