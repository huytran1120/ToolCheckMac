import SwiftUI
import AVFoundation
import AppKit

/// Microphone test: Displays live input level to verify responsiveness when speaking into the mic.
@MainActor
final class MicrophoneCheckModel: ObservableObject {
    @Published var level: Double = 0        // 0...1
    @Published var peak: Double = 0
    @Published var isRunning = false
    @Published var permissionDenied = false
    @Published var statusText = "Preparing…"
    @Published var errorText: String?

    private let engine = AVAudioEngine()

    func start() {
        guard !isRunning else { return }
        permissionDenied = false
        errorText = nil

        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            beginTap()
        case .notDetermined:
            statusText = "Waiting for microphone permission…"
            Task {
                let granted = await AVCaptureDevice.requestAccess(for: .audio)
                if granted {
                    self.beginTap()
                } else {
                    self.showPermissionDenied()
                }
            }
        case .denied, .restricted:
            showPermissionDenied()
        @unknown default:
            showPermissionDenied()
        }
    }

    private func showPermissionDenied() {
        permissionDenied = true
        isRunning = false
        statusText = "Microphone permission not granted"
        errorText = "Please allow ToolCheckMacBook to access the microphone in System Settings, then reopen this test."
    }

    func openPrivacySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
            NSWorkspace.shared.open(url)
        }
    }

    func retry() {
        stop()
        start()
    }

    private func beginTap() {
        let input = engine.inputNode
        let format = input.inputFormat(forBus: 0)
        guard format.channelCount > 0 else {
            errorText = "No available microphone input device detected."
            statusText = "Unable to start listening"
            return
        }

        input.removeTap(onBus: 0)
        let block: @Sendable (AVAudioPCMBuffer, AVAudioTime) -> Void = { [weak self] buffer, _ in
            let normalized = MicrophoneCheckModel.level(from: buffer)
            DispatchQueue.main.async {
                self?.updateLevel(normalized)
            }
        }
        input.installTap(onBus: 0, bufferSize: 1024, format: format, block: block)
        do {
            engine.prepare()
            try engine.start()
            isRunning = true
            statusText = "Listening…"
        } catch {
            input.removeTap(onBus: 0)
            isRunning = false
            statusText = "Unable to start listening"
            errorText = "Failed to start microphone listening: \(error.localizedDescription)"
        }
    }

    /// Pure function without isolation: Safely calculates RMS level on the audio thread.
    nonisolated private static func level(from buffer: AVAudioPCMBuffer) -> Double {
        guard let channel = buffer.floatChannelData?[0] else { return 0 }
        let frames = Int(buffer.frameLength)
        var sum: Float = 0
        for i in 0..<frames { sum += channel[i] * channel[i] }
        let rms = frames > 0 ? sqrt(sum / Float(frames)) : 0
        return min(1.0, Double(rms) * 8)
    }

    private func updateLevel(_ value: Double) {
        level = value
        peak = max(peak * 0.92, value)
    }

    func stop() {
        if isRunning {
            engine.inputNode.removeTap(onBus: 0)
            engine.stop()
            isRunning = false
        }
    }
}

struct MicrophoneCheckView: View {
    @EnvironmentObject private var loc: LocalizationManager
    @StateObject private var model = MicrophoneCheckModel()
    let onComplete: (CheckResult) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            CheckHeader(
                icon: "mic.fill",
                title: loc.t("test.mic.title"),
                subtitle: loc.t("test.mic.sub")
            )

            if model.permissionDenied {
                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    InlineNotice(icon: "exclamationmark.triangle.fill", tint: .orange,
                        text: model.errorText ?? loc.t("test.mic.permission"))
                    HStack(spacing: DS.Spacing.md) {
                        Button {
                            model.openPrivacySettings()
                        } label: {
                            Label(loc.t("test.mic.openSettings"), systemImage: "gearshape")
                        }
                        .buttonStyle(.borderedProminent)

                        Button {
                            model.retry()
                        } label: {
                            Label(loc.t("test.mic.retry"), systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(.bordered)
                    }
                }
            } else {
                levelMeter
                if let error = model.errorText {
                    InlineNotice(icon: "exclamationmark.triangle.fill", tint: .orange, text: error)
                }
            }

            DS.Divider()

            HStack(spacing: DS.Spacing.md) {
                Text(loc.t("test.result")).font(DS.Font.body).foregroundStyle(.secondary)
                Button(loc.t("test.mic.pass")) {
                    model.stop()
                    onComplete(CheckResult(id: "microphone", title: "Microphone", status: .pass,
                        summary: "Microphone picks up audio normally, level meter reacts to sound"))
                }
                .buttonStyle(.borderedProminent)
                Button(loc.t("test.mic.fail")) {
                    model.stop()
                    onComplete(CheckResult(id: "microphone", title: "Microphone", status: .warning,
                        summary: "Microphone level does not react or is abnormal, recommend further inspection"))
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(DS.Spacing.xl)
        .checkPane(loc.t("test.mic.title"))
        .onAppear { model.start() }
        .onDisappear { model.stop() }
    }

    private var levelMeter: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.12))
                    RoundedRectangle(cornerRadius: 8)
                        .fill(LinearGradient(colors: [.green, .yellow, .red], startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * model.level)
                        .animation(.easeOut(duration: 0.08), value: model.level)
                }
            }
            .frame(height: 28)
            Text(model.statusText)
                .font(DS.Font.caption).foregroundStyle(.secondary)
        }
    }
}
