import SwiftUI
import AVFoundation

/// Speaker / Headphones test: Plays sweep tones on left and right channels separately.
@MainActor
final class AudioCheckModel: ObservableObject {
    @Published var playingChannel: Int? = nil   // 0 = Left, 1 = Right, nil = Stopped

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private var started = false

    private func makeBuffer(channel: Int) -> AVAudioPCMBuffer? {
        let sampleRate = 44_100.0
        let duration = 1.0
        let frames = AVAudioFrameCount(sampleRate * duration)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)
        else { return nil }
        buffer.frameLength = frames
        let freq = 440.0
        for frame in 0..<Int(frames) {
            let value = Float(sin(2.0 * Double.pi * freq * Double(frame) / sampleRate)) * 0.25
            buffer.floatChannelData?[0][frame] = channel == 0 ? value : 0
            buffer.floatChannelData?[1][frame] = channel == 1 ? value : 0
        }
        return buffer
    }

    func play(channel: Int) {
        guard let buffer = makeBuffer(channel: channel) else { return }
        if !started {
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: buffer.format)
            do { try engine.start(); started = true } catch { return }
        }
        player.stop()
        player.scheduleBuffer(buffer, at: nil, options: .loops)
        player.play()
        playingChannel = channel
    }

    func stop() {
        player.stop()
        playingChannel = nil
    }

    func teardown() {
        stop()
        if started { engine.stop() }
    }
}

struct AudioCheckView: View {
    @StateObject private var model = AudioCheckModel()
    let onComplete: (CheckResult) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            CheckHeader(
                icon: "speaker.wave.3.fill",
                title: "Speaker / Headphone Test",
                subtitle: "Play left and right channels separately to confirm clear sound from both sides. Plug in headphones to verify headphone jack."
            )

            HStack(spacing: DS.Spacing.md) {
                channelButton(title: "Play Left Channel", channel: 0, icon: "l.circle.fill")
                channelButton(title: "Play Right Channel", channel: 1, icon: "r.circle.fill")
                Button {
                    model.stop()
                } label: {
                    Label("Stop", systemImage: "stop.fill")
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }

            DS.Divider()

            HStack(spacing: DS.Spacing.md) {
                Text("Test Result:").font(DS.Font.body).foregroundStyle(.secondary)
                Button("Both Channels Normal") {
                    model.teardown()
                    onComplete(CheckResult(id: "audio", title: "Speaker / Headphones", status: .pass,
                        summary: "Both left and right channels play normally", rawDetails: ["Left Channel": "Normal", "Right Channel": "Normal"]))
                }
                .buttonStyle(.borderedProminent)
                Button("Channel Issue Detected") {
                    model.teardown()
                    onComplete(CheckResult(id: "audio", title: "Speaker / Headphones", status: .warning,
                        summary: "Audio channel anomaly reported, recommend inspecting speakers or headphone port",
                        rawDetails: ["User Assessment": "Issue Detected"]))
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(DS.Spacing.xl)
        .checkPane("Speaker / Headphones")
        .onDisappear { model.teardown() }
    }

    private func channelButton(title: String, channel: Int, icon: String) -> some View {
        Button {
            model.play(channel: channel)
        } label: {
            Label(title, systemImage: icon)
                .frame(minWidth: 130)
        }
        .buttonStyle(.borderedProminent)
        .tint(model.playingChannel == channel ? .accentColor : .gray)
        .controlSize(.large)
    }
}
