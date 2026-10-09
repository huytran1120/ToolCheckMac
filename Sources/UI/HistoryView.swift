import SwiftUI

/// History: list of saved test snapshots + comparison with current device status (focusing on battery degradation).
struct HistoryView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                if model.history.isEmpty {
                    emptyState
                } else {
                    ForEach(model.history) { snapshot in
                        snapshotCard(snapshot)
                    }
                }
            }
            .padding(DS.Spacing.xl)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .navigationTitle("History")
    }

    private var emptyState: some View {
        VStack(spacing: DS.Spacing.md) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 40)).foregroundStyle(.secondary)
            Text("No Saved Snapshots Yet").font(DS.Font.title)
            Text("Click \"Save to History\" on the Overview page to save this test. Future tests can be compared against it to track battery cycles, health, and score changes.")
                .font(DS.Font.body).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: 420)
        .padding(.top, 60)
    }

    private func snapshotCard(_ s: SavedReport) -> some View {
        Card {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text(s.deviceName).font(DS.Font.bodyEmphasis)
                    Text(s.savedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(DS.Font.caption).foregroundStyle(.secondary)
                    Text("Serial \(s.serial)").font(DS.Font.mono).foregroundStyle(.secondary)
                }
                Spacer()
                VStack(spacing: 2) {
                    Text("\(s.score)").font(.system(size: 26, weight: .heavy))
                        .foregroundStyle(scoreColor(s.score))
                    Text("Score").font(DS.Font.caption).foregroundStyle(.secondary)
                }
                Button(role: .destructive) {
                    model.deleteHistory(s.id)
                } label: { Image(systemName: "trash") }
                    .buttonStyle(.borderless)
                    .help("Delete this snapshot")
            }

            DS.Divider()

            // Key metrics of the snapshot itself
            HStack(spacing: DS.Spacing.xl) {
                metric("Battery Cycles", s.batteryCycles.map { "\($0) cycles" } ?? "—")
                metric("Battery Health", s.batteryHealth ?? "—")
                Spacer()
            }

            // Comparison with current state
            if let comparison = comparisonRows(s), !comparison.isEmpty {
                DS.Divider()
                Text("Comparison with Current State").font(DS.Font.section).tracking(0.6).foregroundStyle(.secondary)
                ForEach(comparison, id: \.label) { row in
                    HStack {
                        Text(row.label).font(DS.Font.body).foregroundStyle(.secondary)
                        Spacer()
                        Text(row.then).font(DS.Font.body).foregroundStyle(.secondary)
                        Image(systemName: "arrow.right").font(.system(size: 10)).foregroundStyle(.tertiary)
                        Text(row.now).font(DS.Font.bodyEmphasis)
                        if let delta = row.delta {
                            Text(delta).font(DS.Font.caption)
                                .foregroundStyle(row.deltaTint)
                                .padding(.horizontal, 6).padding(.vertical, 1)
                                .background(Capsule().fill(row.deltaTint.opacity(0.15)))
                        }
                    }
                }
            }
        }
    }

    private struct Row {
        let label: String
        let then: String
        let now: String
        let delta: String?
        let deltaTint: Color
    }

    /// Compare only if current machine matches the snapshot (matching serial numbers).
    private func comparisonRows(_ s: SavedReport) -> [Row]? {
        guard let profile = model.profile, profile.serialNumber == s.serial else { return nil }
        var rows: [Row] = []

        // Score
        let scoreDelta = model.report.score - s.score
        rows.append(Row(label: "Overall Score", then: "\(s.score)", now: "\(model.report.score)",
                        delta: scoreDelta == 0 ? nil : (scoreDelta > 0 ? "+\(scoreDelta)" : "\(scoreDelta)"),
                        deltaTint: scoreDelta >= 0 ? .green : .orange))

        // Battery cycles (cycles only increase; large jumps indicate heavy usage)
        if let then = s.batteryCycles, let now = model.currentBatteryCycles() {
            let d = now - then
            rows.append(Row(label: "Battery Cycles", then: "\(then) cycles", now: "\(now) cycles",
                            delta: d == 0 ? "No change" : "+\(d) cycles",
                            deltaTint: d > 0 ? .orange : .secondary))
        }

        // Battery health
        if let then = s.batteryHealth, let now = model.currentBatteryHealth() {
            let tp = Int(then.replacingOccurrences(of: "%", with: "")) ?? 0
            let np = Int(now.replacingOccurrences(of: "%", with: "")) ?? 0
            let d = np - tp
            rows.append(Row(label: "Battery Health", then: then, now: now,
                            delta: d == 0 ? "No change" : "\(d)%",
                            deltaTint: d < 0 ? .orange : .green))
        }
        return rows
    }

    private func metric(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(DS.Font.caption).foregroundStyle(.secondary)
            Text(value).font(DS.Font.bodyEmphasis)
        }
    }

    private func scoreColor(_ score: Int) -> Color {
        if score < 60 { return .red }
        if score < 90 { return .orange }
        return .green
    }
}
