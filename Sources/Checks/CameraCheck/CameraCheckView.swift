import SwiftUI
import AVFoundation

/// Camera test: Opens live preview for the user to confirm clarity and check for defects.
@MainActor
final class CameraCheckModel: CaptureCheckModel {
    private let reference = CameraSessionReference()
    private let worker = CaptureWorker.camera
    var session: AVCaptureSession { reference.session }

    init() {
        super.init(permission: .camera)
    }

    override func beginCapture(id: UUID) async throws {
        try await worker.start(id: id) { [reference] in CameraInput(reference: reference) }
    }

    override func endCapture(id: UUID) async {
        await worker.stop(id: id)
    }

    func openPrivacySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") {
            NSWorkspace.shared.open(url)
        }
    }
}

// Only CaptureWorker mutates the session; the main actor binds its AVFoundation preview layer.
private final class CameraSessionReference: @unchecked Sendable {
    let session = AVCaptureSession()
}

private final class CameraInput: CaptureDevice {
    private let reference: CameraSessionReference
    private var session: AVCaptureSession { reference.session }

    init(reference: CameraSessionReference) {
        self.reference = reference
    }

    func start() throws {
        try configure()
        try Task.checkCancellation()
        session.startRunning()
        guard session.isRunning else { throw CaptureFailure.notRunning }
    }

    private func configure() throws {
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        session.sessionPreset = .high
        guard let device = AVCaptureDevice.default(for: .video) else { throw CaptureFailure.noDevice }
        let input = try AVCaptureDeviceInput(device: device)
        guard session.canAddInput(input) else { throw CaptureFailure.invalidFormat }
        session.addInput(input)
    }

    func stop() {
        if session.isRunning { session.stopRunning() }
        session.beginConfiguration()
        for input in session.inputs { session.removeInput(input) }
        session.commitConfiguration()
    }
}

/// SwiftUI wrapper around AVCaptureVideoPreviewLayer.
struct CameraPreview: NSViewRepresentable {
    let session: AVCaptureSession

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.wantsLayer = true
        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        preview.frame = view.bounds
        preview.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        view.layer = preview
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

struct CameraCheckView: View {
    @EnvironmentObject private var loc: LocalizationManager
    @StateObject private var model = CameraCheckModel()
    let onComplete: (CheckResult) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            CheckHeader(
                icon: "camera.fill",
                title: loc.t("test.camera.title"),
                subtitle: loc.t("test.camera.sub")
            )

            if model.permissionDenied {
                InlineNotice(icon: "exclamationmark.triangle.fill", tint: .orange,
                    text: loc.t("test.camera.permission"))
                Button(loc.t("test.camera.openSettings")) { model.openPrivacySettings() }
                    .buttonStyle(.borderedProminent)
            } else {
                CameraPreview(session: model.session)
                    .frame(height: 320)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.card))
                    .overlay(RoundedRectangle(cornerRadius: DS.Radius.card).strokeBorder(DS.Color.hairline))
            }

            Text(loc.t("test.capture.\(model.phase.rawValue)"))
                .font(DS.Font.caption).foregroundStyle(.secondary)
            if let failure = model.failure {
                InlineNotice(icon: "exclamationmark.triangle.fill", tint: .orange,
                    text: failure.localized(using: loc))
            }
            if model.canStart {
                Button(loc.t("test.mic.retry")) { model.start() }
                    .buttonStyle(.bordered)
            }

            DS.Divider()

            HStack(spacing: DS.Spacing.md) {
                Text(loc.t("test.result")).font(DS.Font.body).foregroundStyle(.secondary)
                Button(loc.t("test.camera.pass")) {
                    model.stop()
                    onComplete(CheckResult(id: "camera", title: "Camera", status: .pass,
                        summary: "Camera preview is clear with no defects or abnormalities"))
                }
                .buttonStyle(.borderedProminent)
                .disabled(!model.canRecordResult)
                Button(loc.t("test.camera.fail")) {
                    model.stop()
                    onComplete(CheckResult(id: "camera", title: "Camera", status: .warning,
                        summary: "Camera display anomaly reported, recommend inspecting camera sensor"))
                }
                .buttonStyle(.bordered)
                .disabled(!model.canRecordResult)
            }
            Button(loc.t("test.skip")) {
                model.stop()
                onComplete(CheckResult(id: "camera", title: "Camera", status: .skipped,
                    summary: "Camera test skipped"))
            }
            .buttonStyle(.bordered)
        }
        .padding(DS.Spacing.xl)
        .checkPane(loc.t("test.camera.title"))
        .onAppear { model.start() }
        .onDisappear { model.stop() }
    }
}
