import SwiftUI
import AVFoundation
import AppKit

/// Microphone test: Displays live input level to verify responsiveness when speaking into the mic.
@MainActor
final class MicrophoneCheckModel: CaptureCheckModel {
    @Published private(set) var level: Double = 0
    @Published private(set) var peak: Double = 0
    private let worker = CaptureWorker.microphone

    init() {
        super.init(permission: .microphone)
    }

    func openPrivacySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
            NSWorkspace.shared.open(url)
        }
    }

    override func beginCapture(id: UUID) async throws {
        let onLevel: @Sendable (Double) -> Void = { [weak self] value in
            Task { @MainActor [weak self] in
                guard let self, self.activeID == id, self.isRunning else { return }
                self.level = value
                self.peak = max(self.peak * 0.92, value)
            }
        }
        try await worker.start(id: id) { MicrophoneInput(onLevel: onLevel) }
    }

    override func endCapture(id: UUID) async {
        await worker.stop(id: id)
    }

    override func stop() {
        super.stop()
        level = 0
        peak = 0
    }
}

private final class MicrophoneInput: CaptureDevice {
    private let engine = AVAudioEngine()
    private let onLevel: @Sendable (Double) -> Void
    private var hasTap = false

    init(onLevel: @escaping @Sendable (Double) -> Void) {
        self.onLevel = onLevel
    }

    func start() throws {
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.channelCount > 0 else { throw CaptureFailure.noDevice }
        guard format.sampleRate.isFinite, format.sampleRate > 0,
              format.commonFormat == .pcmFormatFloat32 else { throw CaptureFailure.invalidFormat }
        try Task.checkCancellation()

        let block: @Sendable (AVAudioPCMBuffer, AVAudioTime) -> Void = { [onLevel] buffer, _ in
            onLevel(MicrophoneInput.level(from: buffer))
        }
        input.installTap(onBus: 0, bufferSize: 1024, format: format, block: block)
        hasTap = true
        try Task.checkCancellation()
        engine.prepare()
        try Task.checkCancellation()
        try engine.start()
        guard engine.isRunning else { throw CaptureFailure.notRunning }
    }

    private static func level(from buffer: AVAudioPCMBuffer) -> Double {
        guard let channel = buffer.floatChannelData?[0] else { return 0 }
        let frames = Int(buffer.frameLength)
        var sum: Float = 0
        for i in 0..<frames {
            let sample = channel[i * buffer.stride]
            sum += sample * sample
        }
        let rms = frames > 0 ? sqrt(sum / Float(frames)) : 0
        return rms.isFinite ? min(1.0, Double(rms) * 8) : 0
    }

    func stop() {
        if hasTap {
            engine.inputNode.removeTap(onBus: 0)
            hasTap = false
        }
        engine.stop()
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
                        text: loc.t("test.mic.permission"))
                    HStack(spacing: DS.Spacing.md) {
                        Button {
                            model.openPrivacySettings()
                        } label: {
                            Label(loc.t("test.mic.openSettings"), systemImage: "gearshape")
                        }
                        .buttonStyle(.borderedProminent)

                        Button {
                            model.start()
                        } label: {
                            Label(loc.t("test.mic.retry"), systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(.bordered)
                        .disabled(!model.canStart)
                    }
                }
            } else {
                levelMeter
                if let failure = model.failure {
                    InlineNotice(icon: "exclamationmark.triangle.fill", tint: .orange,
                        text: failure.localized(using: loc))
                }
                if model.canStart {
                    Button(loc.t("test.mic.retry")) { model.start() }
                        .buttonStyle(.bordered)
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
                .disabled(!model.canRecordResult)
                Button(loc.t("test.mic.fail")) {
                    model.stop()
                    onComplete(CheckResult(id: "microphone", title: "Microphone", status: .warning,
                        summary: "Microphone level does not react or is abnormal, recommend further inspection"))
                }
                .buttonStyle(.bordered)
                .disabled(!model.canRecordResult)
            }
            Button(loc.t("test.skip")) {
                model.stop()
                onComplete(CheckResult(id: "microphone", title: "Microphone", status: .skipped,
                    summary: "Microphone test skipped"))
            }
            .buttonStyle(.bordered)
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
            Text(loc.t(model.isRunning ? "test.mic.listening" : "test.capture.\(model.phase.rawValue)"))
                .font(DS.Font.caption).foregroundStyle(.secondary)
        }
    }
}
