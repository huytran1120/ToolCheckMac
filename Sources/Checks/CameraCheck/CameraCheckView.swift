import SwiftUI
import AVFoundation

/// Camera test: Opens live preview for the user to confirm clarity and check for defects.
@MainActor
final class CameraCheckModel: ObservableObject {
    @Published var permissionDenied = false
    @Published var isRunning = false
    let session = AVCaptureSession()

    func start() {
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            Task { @MainActor in
                guard let self else { return }
                if granted { self.configure() } else { self.permissionDenied = true }
            }
        }
    }

    private func configure() {
        session.beginConfiguration()
        session.sessionPreset = .high
        if let device = AVCaptureDevice.default(for: .video),
           let input = try? AVCaptureDeviceInput(device: device),
           session.canAddInput(input) {
            session.addInput(input)
        } else {
            permissionDenied = true
            session.commitConfiguration()
            return
        }
        session.commitConfiguration()
        nonisolated(unsafe) let session = self.session
        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
            DispatchQueue.main.async { [weak self] in self?.isRunning = true }
        }
    }

    func stop() {
        if session.isRunning { session.stopRunning() }
        isRunning = false
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
            } else {
                CameraPreview(session: model.session)
                    .frame(height: 320)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.card))
                    .overlay(RoundedRectangle(cornerRadius: DS.Radius.card).strokeBorder(DS.Color.hairline))
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
                Button(loc.t("test.camera.fail")) {
                    model.stop()
                    onComplete(CheckResult(id: "camera", title: "Camera", status: .warning,
                        summary: "Camera display anomaly reported, recommend inspecting camera sensor"))
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(DS.Spacing.xl)
        .checkPane(loc.t("test.camera.title"))
        .onAppear { model.start() }
        .onDisappear { model.stop() }
    }
}
