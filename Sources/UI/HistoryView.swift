import SwiftUI

/// History: list of saved test snapshots + comparison with current device status (focusing on battery degradation).
struct HistoryView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var loc: LocalizationManager

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
        .navigationTitle(loc.t("history.title"))
    }

    private var emptyState: some View {
        VStack(spacing: DS.Spacing.md) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 40)).foregroundStyle(.secondary)
            Text(loc.t("history.emptyTitle")).font(DS.Font.title)
            Text(loc.t("history.emptySubtitle"))
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
                    Text(loc.t("history.score")).font(DS.Font.caption).foregroundStyle(.secondary)
                }
                Button(role: .destructive) {
                    model.deleteHistory(s.id)
                } label: { Image(systemName: "trash") }
                    .buttonStyle(.borderless)
                    .help(loc.t("history.delete"))
            }

            DS.Divider()

            // Key metrics of the snapshot itself
            HStack(spacing: DS.Spacing.xl) {
                metric(loc.currentLanguage == .vietnamese ? "Chu kỳ sạc pin" : "Battery Cycles",
                       s.batteryCycles.map { loc.currentLanguage == .vietnamese ? "\($0) lần" : "\($0) cycles" } ?? "—")
                metric(loc.currentLanguage == .vietnamese ? "Sức khỏe pin" : "Battery Health", s.batteryHealth ?? "—")
                Spacer()
            }

            // Comparison with current state
            if let comparison = comparisonRows(s), !comparison.isEmpty {
                DS.Divider()
                Text(loc.currentLanguage == .vietnamese ? "So sánh với trạng thái hiện tại" : "Comparison with Current State")
                    .font(DS.Font.section).tracking(0.6).foregroundStyle(.secondary)
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
        let scoreLabel = loc.currentLanguage == .vietnamese ? "Điểm tổng thể" : "Overall Score"
        rows.append(Row(label: scoreLabel, then: "\(s.score)", now: "\(model.report.score)",
                        delta: scoreDelta == 0 ? nil : (scoreDelta > 0 ? "+\(scoreDelta)" : "\(scoreDelta)"),
                        deltaTint: scoreDelta >= 0 ? .green : .orange))

        // Battery cycles
        if let then = s.batteryCycles, let now = model.currentBatteryCycles() {
            let d = now - then
            let cycleLabel = loc.currentLanguage == .vietnamese ? "Chu kỳ sạc pin" : "Battery Cycles"
            let unit = loc.currentLanguage == .vietnamese ? "lần" : "cycles"
            let noChange = loc.currentLanguage == .vietnamese ? "Không đổi" : "No change"
            rows.append(Row(label: cycleLabel, then: "\(then) \(unit)", now: "\(now) \(unit)",
                            delta: d == 0 ? noChange : "+\(d) \(unit)",
                            deltaTint: d > 0 ? .orange : .secondary))
        }

        // Battery health
        if let then = s.batteryHealth, let now = model.currentBatteryHealth() {
            let tp = Int(then.replacingOccurrences(of: "%", with: "")) ?? 0
            let np = Int(now.replacingOccurrences(of: "%", with: "")) ?? 0
            let d = np - tp
            let healthLabel = loc.currentLanguage == .vietnamese ? "Sức khỏe pin" : "Battery Health"
            let noChange = loc.currentLanguage == .vietnamese ? "Không đổi" : "No change"
            rows.append(Row(label: healthLabel, then: then, now: now,
                            delta: d == 0 ? noChange : "\(d)%",
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
