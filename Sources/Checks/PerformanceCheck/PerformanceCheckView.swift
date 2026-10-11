import SwiftUI
import Foundation

/// Performance stress test: Runs multi-core load for several seconds and monitors thermal state.
/// Measures throughput and identifies thermal throttling issues.
@MainActor
final class PerformanceCheckModel: ObservableObject {
    @Published var isRunning = false
    @Published var progress: Double = 0
    @Published var elapsed: Int = 0
    @Published var opsPerSecond: Double = 0
    @Published var thermalSamples: [ProcessInfo.ThermalState] = []
    @Published var finished = false

    // SMC exact temperature and fan speeds
    @Published var currentReading: SMCReading?
    @Published var peakTemp: Double?
    @Published var peakRPM: Double?
    @Published var idleReading: SMCReading?   // Baseline readings prior to test

    private let durationSeconds = 15
    private var task: Task<Void, Never>?

    var coreCount: Int { ProcessInfo.processInfo.activeProcessorCount }
    var smcAvailable: Bool { idleReading != nil || currentReading != nil }

    var worstThermal: ProcessInfo.ThermalState {
        thermalSamples.max(by: { $0.severity < $1.severity }) ?? .nominal
    }

    func start() {
        guard !isRunning else { return }
        reset()
        isRunning = true
        task = Task { await run() }
    }

    func cancel() {
        task?.cancel()
        task = nil
        isRunning = false
    }

    private func reset() {
        progress = 0; elapsed = 0; opsPerSecond = 0; thermalSamples = []; finished = false
        currentReading = nil; peakTemp = nil; peakRPM = nil
    }

    private func run() async {
        let cores = coreCount
        let total = durationSeconds
        // Record idle baseline temperature
        idleReading = await Task.detached { SMCService.snapshot() }.value

        for second in 1...total {
            if Task.isCancelled { break }
            // Run multi-core load each second to measure throughput
            let start = DispatchTime.now()
            let ops = await withTaskGroup(of: Double.self) { group -> Double in
                for _ in 0..<cores {
                    group.addTask { PerformanceCheckModel.busyCompute(iterations: 4_000_000) }
                }
                var sum = 0.0
                for await r in group { sum += r }
                return sum
            }
            let dt = Double(DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000_000
            _ = ops
            let opsCount = Double(cores) * 4_000_000
            self.opsPerSecond = dt > 0 ? opsCount / dt : 0
            self.thermalSamples.append(ProcessInfo.processInfo.thermalState)

            // Sample SMC temperature and fan speeds in background
            let reading = await Task.detached { SMCService.snapshot() }.value
            if let reading {
                self.currentReading = reading
                if let t = reading.maxTemp { self.peakTemp = max(self.peakTemp ?? 0, t) }
                if let r = reading.fanRPMs.max() { self.peakRPM = max(self.peakRPM ?? 0, r) }
            }

            self.elapsed = second
            self.progress = Double(second) / Double(total)
        }
        isRunning = false
        finished = !Task.isCancelled
    }

    /// Pure compute workload executed on background thread.
    nonisolated static func busyCompute(iterations: Int) -> Double {
        var acc = 0.0
        var x = 1.000001
        for _ in 0..<iterations {
            x = x * 1.0000001 + 0.0000001
            acc += x.squareRoot()
        }
        return acc
    }

    func buildResult() -> CheckResult {
        let worst = worstThermal
        let throttled = worst.severity >= ProcessInfo.ThermalState.serious.severity
        let mops = opsPerSecond / 1_000_000
        var details: [String: String] = [
            "Core Count": "\(coreCount)",
            "Test Duration": "\(elapsed) seconds",
            "Final Throughput": String(format: "%.0f M ops/s", mops),
            "Peak Thermal State": worst.label,
        ]
        details["Thermal Samples"] = thermalSamples.map(\.label).joined(separator: " → ")
        if let peakTemp { details["Peak Load Temperature"] = String(format: "%.1f °C", peakTemp) }
        if let idle = idleReading?.maxTemp { details["Idle Temperature"] = String(format: "%.1f °C", idle) }
        if let peakRPM { details["Peak Fan Speed"] = String(format: "%.0f RPM", peakRPM) }

        let tempSuffix: String = {
            guard let peakTemp else { return "" }
            let rpm = peakRPM.map { String(format: ", fan %.0f RPM", $0) } ?? ""
            return String(format: ", peak load %.0f°C", peakTemp) + rpm
        }()

        if throttled {
            return CheckResult(id: "performance", title: "Performance Test", status: .warning,
                summary: "Reached \"\(worst.label)\" thermal state during stress test; possible cooling degradation or thermal throttling detected, recommend checking cooling" + tempSuffix,
                rawDetails: details)
        }
        return CheckResult(id: "performance", title: "Performance Test", status: .pass,
            summary: "Full load for \(elapsed) seconds, thermal state \"\(worst.label)\", cooling and performance normal" + tempSuffix,
            rawDetails: details)
    }
}

extension ProcessInfo.ThermalState {
    var severity: Int {
        switch self {
        case .nominal: return 0
        case .fair: return 1
        case .serious: return 2
        case .critical: return 3
        @unknown default: return 0
        }
    }
    var label: String {
        switch self {
        case .nominal: return "Nominal"
        case .fair: return "Fair"
        case .serious: return "Serious"
        case .critical: return "Critical"
        @unknown default: return "Unknown"
        }
    }
    var tint: Color {
        switch self {
        case .nominal: return .green
        case .fair: return .yellow
        case .serious: return .orange
        case .critical: return .red
        @unknown default: return .secondary
        }
    }
}

struct PerformanceCheckView: View {
    @EnvironmentObject private var loc: LocalizationManager
    @StateObject private var model = PerformanceCheckModel()
    let onComplete: (CheckResult) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            CheckHeader(
                icon: "gauge.with.dots.needle.67percent",
                title: loc.t("test.performance.title"),
                subtitle: loc.t("test.performance.sub")
            )

            gauge

            if model.finished {
                let statusMsg = model.worstThermal.severity >= 2 ? loc.t("test.perf.coolingWarn") : loc.t("test.perf.coolingGood")
                let notice = String(format: loc.t("test.perf.peakNotice"), model.worstThermal.label, statusMsg)
                InlineNotice(icon: model.worstThermal.severity >= 2 ? "exclamationmark.triangle.fill" : "checkmark.circle.fill",
                             tint: model.worstThermal.tint,
                             text: notice)
            }

            DS.Divider()

            HStack(spacing: DS.Spacing.md) {
                if model.isRunning {
                    Button(loc.t("test.stop")) { model.cancel() }.buttonStyle(.bordered)
                    ProgressView().controlSize(.small)
                    Text(String(format: loc.t("test.perf.stressTesting"), model.elapsed)).font(DS.Font.caption).foregroundStyle(.secondary)
                } else {
                    Button(model.finished ? loc.t("test.perf.retest") : loc.t("test.perf.start")) { model.start() }
                        .buttonStyle(.borderedProminent)
                    if model.finished {
                        Button(loc.t("test.saveResult")) { onComplete(model.buildResult()) }
                            .buttonStyle(.bordered)
                    }
                }
            }
        }
        .padding(DS.Spacing.xl)
        .checkPane(loc.t("test.performance.title"))
        .onDisappear { model.cancel() }
    }

    private var gauge: some View {
        Card {
            HStack(spacing: DS.Spacing.xl) {
                stat(title: loc.t("test.perf.progress"), value: "\(Int(model.progress * 100))%")
                stat(title: loc.t("test.perf.throughput"), value: model.opsPerSecond > 0 ? String(format: "%.0f M/s", model.opsPerSecond / 1_000_000) : "—")
                stat(title: loc.t("test.perf.thermal"),
                     value: (model.thermalSamples.last ?? .nominal).label,
                     tint: (model.thermalSamples.last ?? .nominal).tint)
                Spacer()
            }
            ProgressView(value: model.progress)

            // SMC temperature / fan
            if model.smcAvailable {
                DS.Divider()
                HStack(spacing: DS.Spacing.xl) {
                    stat(title: loc.t("test.perf.socTemp"),
                         value: model.currentReading?.maxTemp.map { String(format: "%.0f °C", $0) } ?? "—",
                         tint: tempTint(model.currentReading?.maxTemp))
                    if let rpm = model.currentReading?.fanRPMs, !rpm.isEmpty {
                        stat(title: rpm.count > 1 ? loc.t("test.perf.fan") : loc.t("test.perf.fan"),
                             value: rpm.map { String(format: "%.0f", $0) }.joined(separator: " / ") + " RPM")
                    }
                    if let peak = model.peakTemp {
                        stat(title: loc.t("test.perf.peakTemp"), value: String(format: "%.0f °C", peak), tint: tempTint(peak))
                    }
                    Spacer()
                }
            } else if model.isRunning {
                Text("No readable SMC temperature/fan sensors on this Mac")
                    .font(DS.Font.caption).foregroundStyle(.tertiary)
            }
        }
    }

    private func tempTint(_ t: Double?) -> Color {
        guard let t else { return .primary }
        if t >= 95 { return .red }
        if t >= 85 { return .orange }
        return .green
    }

    private func stat(title: String, value: String, tint: Color = .primary) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(DS.Font.caption).foregroundStyle(.secondary)
            Text(value).font(.system(size: 18, weight: .semibold)).foregroundStyle(tint)
        }
    }
}
