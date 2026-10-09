import SwiftUI
import LocalAuthentication

/// Touch ID test: Invokes biometric authentication to verify fingerprint sensor functionality.
struct TouchIDCheckView: View {
    let onComplete: (CheckResult) -> Void
    @State private var statusText = "Click the button below to verify with an enrolled fingerprint."
    @State private var available = true
    @State private var reason = ""

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            CheckHeader(
                icon: "touchid",
                title: "Touch ID Test",
                subtitle: "Verify whether the fingerprint sensor functions properly."
            )

            if !available {
                InlineNotice(icon: "info.circle.fill", tint: .secondary,
                    text: reason.isEmpty ? "This Mac does not support Touch ID, or no fingerprints are enrolled." : reason)
            } else {
                Text(statusText).font(DS.Font.body).foregroundStyle(.secondary)
                Button {
                    authenticate()
                } label: {
                    Label("Start Fingerprint Verification", systemImage: "touchid")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }

            DS.Divider()

            Button("Skip Test") {
                onComplete(CheckResult(id: "touchID", title: "Touch ID", status: .skipped,
                    summary: "User skipped the Touch ID test"))
            }
            .buttonStyle(.bordered)
        }
        .padding(DS.Spacing.xl)
        .checkPane("Touch ID")
        .onAppear { checkAvailability() }
    }

    private func checkAvailability() {
        let context = LAContext()
        var error: NSError?
        if !context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            available = false
            if context.biometryType == .none {
                reason = "This Mac does not support Touch ID, or no fingerprints are enrolled."
            }
        }
    }

    private func authenticate() {
        let context = LAContext()
        context.localizedFallbackTitle = ""
        statusText = "Place your finger on Touch ID…"
        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics,
                               localizedReason: "Verify whether Touch ID sensor functions properly") { success, authError in
            Task { @MainActor in
                if success {
                    onComplete(CheckResult(id: "touchID", title: "Touch ID", status: .pass,
                        summary: "Fingerprint recognized successfully, Touch ID sensor functions normally"))
                } else {
                    let code = (authError as? LAError)?.code
                    if code == .userCancel || code == .systemCancel {
                        statusText = "Cancelled, you may try again."
                    } else {
                        statusText = "Recognition failed, you may retry or skip."
                    }
                }
            }
        }
    }
}
