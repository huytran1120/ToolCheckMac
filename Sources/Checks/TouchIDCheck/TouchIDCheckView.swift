import SwiftUI
import LocalAuthentication

/// Touch ID test: Invokes biometric authentication to verify fingerprint sensor functionality.
struct TouchIDCheckView: View {
    @EnvironmentObject private var loc: LocalizationManager
    let onComplete: (CheckResult) -> Void
    @State private var statusOverride: String?
    @State private var available = true
    @State private var reason = ""

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            CheckHeader(
                icon: "touchid",
                title: loc.t("test.touchID.title"),
                subtitle: loc.t("test.touchID.sub")
            )

            if !available {
                InlineNotice(icon: "info.circle.fill", tint: .secondary,
                    text: reason.isEmpty ? loc.t("test.touchID.unsupported") : reason)
            } else {
                Text(statusOverride ?? loc.t("test.touchID.prompt")).font(DS.Font.body).foregroundStyle(.secondary)
                Button {
                    authenticate()
                } label: {
                    Label(loc.t("test.touchID.start"), systemImage: "touchid")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }

            DS.Divider()

            Button(loc.t("test.skip")) {
                onComplete(CheckResult(id: "touchID", title: "Touch ID", status: .skipped,
                    summary: "User skipped the Touch ID test"))
            }
            .buttonStyle(.bordered)
        }
        .padding(DS.Spacing.xl)
        .checkPane(loc.t("test.touchID.title"))
        .onAppear { checkAvailability() }
    }

    private func checkAvailability() {
        let context = LAContext()
        var error: NSError?
        if !context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            available = false
            if context.biometryType == .none {
                reason = loc.t("test.touchID.unsupported")
            }
        }
    }

    private func authenticate() {
        let context = LAContext()
        context.localizedFallbackTitle = ""
        statusOverride = loc.t("test.touchID.placeFinger")
        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics,
                               localizedReason: "Verify Touch ID sensor") { success, authError in
            Task { @MainActor in
                if success {
                    onComplete(CheckResult(id: "touchID", title: "Touch ID", status: .pass,
                        summary: "Fingerprint recognized successfully, Touch ID sensor functions normally"))
                } else {
                    let code = (authError as? LAError)?.code
                    if code == .userCancel || code == .systemCancel {
                        statusOverride = loc.t("test.touchID.cancelled")
                    } else {
                        statusOverride = loc.t("test.touchID.failed")
                    }
                }
            }
        }
    }
}
