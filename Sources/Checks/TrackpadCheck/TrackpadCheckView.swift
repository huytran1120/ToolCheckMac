import SwiftUI
import AppKit

/// Trackpad test: Tracking trail drawing + multi-finger gestures + Force Touch pressure detection.
@MainActor
final class TrackpadCheckModel: ObservableObject {
    @Published var trail: [CGPoint] = []
    @Published var pressure: Double = 0
    @Published var didForceClick = false
    @Published var gesturesSeen: Set<String> = []      // "magnify" / "rotate" / "swipe"

    func addPoint(_ p: CGPoint) {
        trail.append(p)
        if trail.count > 400 { trail.removeFirst(trail.count - 400) }
    }

    func note(gesture: String) { gesturesSeen.insert(gesture) }

    func reset() {
        trail.removeAll()
        pressure = 0
        didForceClick = false
        gesturesSeen.removeAll()
    }

    var coverageHint: String {
        var parts: [String] = []
        parts.append("Track points: \(trail.count)")
        if !gesturesSeen.isEmpty { parts.append("Gestures: \(gesturesSeen.count)/3") }
        if didForceClick { parts.append("Force Touch ✓") }
        return parts.joined(separator: " · ")
    }
}

/// Uses NSView to capture trackpad pressure and gesture events.
private struct TrackpadCapture: NSViewRepresentable {
    @ObservedObject var model: TrackpadCheckModel

    func makeNSView(context: Context) -> CaptureView {
        let v = CaptureView()
        v.model = model
        return v
    }
    func updateNSView(_ nsView: CaptureView, context: Context) {}

    final class CaptureView: NSView {
        weak var model: TrackpadCheckModel?
        override var acceptsFirstResponder: Bool { true }
        override func viewDidMoveToWindow() { window?.makeFirstResponder(self) }

        override func mouseDragged(with event: NSEvent) { record(event) }
        override func mouseMoved(with event: NSEvent) { record(event) }

        private func record(_ event: NSEvent) {
            let p = convert(event.locationInWindow, from: nil)
            let flipped = CGPoint(x: p.x, y: bounds.height - p.y)
            model?.addPoint(flipped)
        }

        override func pressureChange(with event: NSEvent) {
            model?.pressure = Double(event.pressure)
            if event.stage >= 2 { model?.didForceClick = true }
        }
        override func magnify(with event: NSEvent) { model?.note(gesture: "magnify") }
        override func rotate(with event: NSEvent) { model?.note(gesture: "rotate") }
        override func swipe(with event: NSEvent) { model?.note(gesture: "swipe") }
        override func scrollWheel(with event: NSEvent) {
            // Two-finger scroll also counts as gesture verification
            model?.note(gesture: "swipe")
        }
    }
}

struct TrackpadCheckView: View {
    @StateObject private var model = TrackpadCheckModel()
    let onComplete: (CheckResult) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            CheckHeader(
                icon: "rectangle.and.hand.point.up.left.fill",
                title: "Trackpad Test",
                subtitle: "Move your finger in the area below to test tracking responsiveness, test two-finger zoom/rotate/scroll, and press firmly to test Force Touch pressure."
            )

            canvas

            HStack(spacing: DS.Spacing.lg) {
                metric("Pressure", String(format: "%.2f", model.pressure), model.pressure > 0)
                metric("Force Touch", model.didForceClick ? "Triggered" : "Not Triggered", model.didForceClick)
                metric("Multi-touch Gestures", "\(model.gesturesSeen.count)/3", !model.gesturesSeen.isEmpty)
                Spacer()
                Button("Clear") { model.reset() }.buttonStyle(.bordered)
            }

            DS.Divider()

            HStack(spacing: DS.Spacing.md) {
                Text("Test Result:").font(DS.Font.body).foregroundStyle(.secondary)
                Button("Tracking, Gestures & Force Touch Normal") {
                    onComplete(CheckResult(id: "trackpad", title: "Trackpad", status: .pass,
                        summary: "Tracking responsiveness, multi-touch gestures, and Force Touch all normal",
                        rawDetails: ["Track Points": "\(model.trail.count)",
                                     "Detected Gestures": model.gesturesSeen.sorted().joined(separator: ", "),
                                     "Force Touch": model.didForceClick ? "Triggered" : "Not Triggered"]))
                }
                .buttonStyle(.borderedProminent)
                Button("Anomaly Detected") {
                    onComplete(CheckResult(id: "trackpad", title: "Trackpad", status: .warning,
                        summary: "Trackpad anomaly reported, recommend further inspection"))
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(DS.Spacing.xl)
        .checkPane("Trackpad")
    }

    private var canvas: some View {
        ZStack {
            RoundedRectangle(cornerRadius: DS.Radius.card).fill(Color.secondary.opacity(0.08))
            TrackpadCapture(model: model).allowsHitTesting(true)
            Canvas { ctx, _ in
                guard model.trail.count > 1 else { return }
                var path = Path()
                path.addLines(model.trail)
                ctx.stroke(path, with: .color(.accentColor), style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
            }
            .allowsHitTesting(false)
            if model.trail.isEmpty {
                Text("Move finger in this area").font(DS.Font.body).foregroundStyle(.tertiary)
            }
            // Pressure visualization ring
            if model.pressure > 0 {
                Circle().stroke(Color.orange, lineWidth: 3)
                    .frame(width: 30 + model.pressure * 60, height: 30 + model.pressure * 60)
                    .opacity(0.6)
            }
        }
        .frame(height: 260)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.card))
    }

    private func metric(_ label: String, _ value: String, _ active: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(DS.Font.caption).foregroundStyle(.secondary)
            Text(value).font(DS.Font.bodyEmphasis).foregroundStyle(active ? .green : .primary)
        }
    }
}
