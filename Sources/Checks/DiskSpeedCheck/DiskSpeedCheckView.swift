import SwiftUI
import Foundation
import OSLog

/// Disk read/write benchmark: Sequential write then read to measure throughput in MB/s.
/// Reads use `F_NOCACHE` to bypass system page cache and measure real drive performance.
@MainActor
final class DiskSpeedCheckModel: ObservableObject {
    @Published var isRunning = false
    @Published var phase = ""
    @Published var progress = 0.0
    @Published var writeMBps: Double?
    @Published var readMBps: Double?
    @Published var finished = false
    @Published var errorText: String?

    private let totalBytes = 1024 * 1024 * 1024   // 1 GB
    private let chunkBytes = 32 * 1024 * 1024      // 32 MB chunks for stable throughput
    private var task: Task<Void, Never>?
    private var worker: Task<(Double, Double), Error>?

    func start() {
        guard task == nil else { return }
        writeMBps = nil; readMBps = nil; progress = 0; finished = false; errorText = nil
        isRunning = true
        task = Task { await run() }
    }

    func cancel() {
        task?.cancel()
        worker?.cancel()
    }

    private func run() async {
        let path = NSTemporaryDirectory() + "toolcheckmacbook_speedtest_\(UUID().uuidString).bin"
        let total = totalBytes, chunk = chunkBytes

        // Stream progress back via AsyncStream
        let (stream, cont) = AsyncStream.makeStream(of: (String, Double).self)

        let work = Task.detached { () throws -> (Double, Double) in
            defer { cont.finish() }
            do {
                try Task.checkCancellation()
                let w = try DiskSpeedCheckModel.measure(path: path, total: total, chunk: chunk, writing: true) {
                    cont.yield(("Writing", $0))
                }
                try Task.checkCancellation()
                let r = try DiskSpeedCheckModel.measure(path: path, total: total, chunk: chunk, writing: false) {
                    cont.yield(("Reading", $0))
                }
                try Task.checkCancellation()
                try FileManager.default.removeItem(atPath: path)
                return (w, r)
            } catch {
                if FileManager.default.fileExists(atPath: path) {
                    do {
                        try FileManager.default.removeItem(atPath: path)
                    } catch {
                        Logger(subsystem: "com.toolcheckmacbook", category: "DiskSpeed")
                            .error("Benchmark cleanup failed: \(error.localizedDescription, privacy: .private)")
                        throw error
                    }
                }
                throw error
            }
        }
        worker = work
        defer {
            worker = nil
            task = nil
            isRunning = false
        }

        await withTaskCancellationHandler {
            for await (ph, p) in stream where !Task.isCancelled {
                phase = ph
                progress = p
            }
            do {
                let (w, r) = try await work.value
                try Task.checkCancellation()
                writeMBps = w
                readMBps = r
                finished = true
            } catch is CancellationError {
                finished = false
            } catch {
                errorText = (error as? DiskError)?.description ?? error.localizedDescription
            }
        } onCancel: {
            work.cancel()
        }
    }

    enum DiskError: Error, CustomStringConvertible {
        case open, io, incomplete, cache, flush, invalidSize
        var description: String {
            switch self {
            case .open: return "Unable to create test file (disk may be full or lack write permissions)"
            case .io: return "I/O error occurred during read/write operation"
            case .incomplete: return "The test file ended before all benchmark data could be read"
            case .cache: return "Unable to bypass the disk cache; benchmark was not completed"
            case .flush: return "Unable to flush test data to disk; write speed could not be verified"
            case .invalidSize: return "Benchmark data and chunk sizes must be positive"
            }
        }
    }

    /// Blocking POSIX read/write, returning MB/s. Executed on a background thread.
    nonisolated static func measure(
        path: String, total: Int, chunk: Int, writing: Bool,
        isCancelled: () -> Bool = { Task.isCancelled },
        synchronize: (Int32) -> Int32 = Darwin.fsync,
        transfer: (Int32, UnsafeMutableRawPointer, Int, Bool) -> Int = { fd, buffer, count, writing in
            writing ? Darwin.write(fd, buffer, count) : Darwin.read(fd, buffer, count)
        },
        progress: (Double) -> Void
    ) throws -> Double {
        guard total > 0, chunk > 0 else { throw DiskError.invalidSize }
        if isCancelled() { throw CancellationError() }
        let buffer = UnsafeMutableRawPointer.allocate(byteCount: chunk, alignment: 4096)
        defer { buffer.deallocate() }
        if writing { memset(buffer, 0xA5, chunk) }

        let flags = writing ? (O_WRONLY | O_CREAT | O_EXCL) : O_RDONLY
        let fd = open(path, flags, 0o600)
        guard fd >= 0 else { throw DiskError.open }
        defer { close(fd) }
        // Bypass page cache to measure real drive speed rather than RAM cache
        guard fcntl(fd, F_NOCACHE, 1) == 0 else { throw DiskError.cache }

        let start = DispatchTime.now()
        var done = 0
        while done < total {
            if isCancelled() { throw CancellationError() }
            let n = min(chunk, total - done)
            let moved = transfer(fd, buffer, n, writing)
            if moved < 0 {
                if errno == EINTR { continue }
                throw DiskError.io
            }
            guard moved > 0 else { throw DiskError.incomplete }
            done += moved
            progress(Double(done) / Double(total))
        }
        if isCancelled() { throw CancellationError() }
        if writing {
            while synchronize(fd) != 0 {
                if errno != EINTR { throw DiskError.flush }
                if isCancelled() { throw CancellationError() }
            }
        }
        if isCancelled() { throw CancellationError() }
        let elapsed = Double(DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000_000
        let mb = Double(done) / (1024 * 1024)
        return elapsed > 0 ? mb / elapsed : 0
    }

    func buildResult() -> CheckResult {
        guard finished, let writeMBps, let readMBps,
              writeMBps.isFinite, readMBps.isFinite, writeMBps > 0, readMBps > 0 else {
            return CheckResult(id: "diskSpeed", title: "Disk Speed Test", status: .skipped,
                               summary: "Disk speed test did not complete; no verified speed result is available")
        }
        let w = writeMBps, r = readMBps
        let low = (w > 0 && w < 200) || (r > 0 && r < 200)
        let details: [String: String] = [
            "Sequential Write": String(format: "%.0f MB/s", w),
            "Sequential Read": String(format: "%.0f MB/s", r),
            "Test Data Size": "1 GB",
            "I/O Mode": "F_NOCACHE bypass cache (write includes fsync for synchronous disk speed)",
        ]
        return CheckResult(
            id: "diskSpeed",
            title: "Disk Speed Test",
            status: low ? .warning : .pass,
            summary: String(format: "Write %.0f MB/s · Read %.0f MB/s", w, r) + (low ? " — Low speed, possible external slow drive or disk anomaly" : " — Normal read/write speeds"),
            rawDetails: details
        )
    }
}

struct DiskSpeedCheckView: View {
    @EnvironmentObject private var loc: LocalizationManager
    @StateObject private var model = DiskSpeedCheckModel()
    let onComplete: (CheckResult) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            CheckHeader(
                icon: "speedometer",
                title: loc.t("test.diskSpeed.title"),
                subtitle: loc.t("test.diskSpeed.sub")
            )

            Card {
                HStack(spacing: DS.Spacing.xl) {
                    speedStat(title: loc.t("test.diskSpeed.write"), value: model.writeMBps)
                    speedStat(title: loc.t("test.diskSpeed.read"), value: model.readMBps)
                    Spacer()
                }
                if model.isRunning {
                    ProgressView(value: model.progress) {
                        let phaseText = model.phase == "Writing" ? loc.t("test.diskSpeed.writing") : (model.phase == "Reading" ? loc.t("test.diskSpeed.reading") : model.phase)
                        Text("\(phaseText) \(Int(model.progress * 100))%")
                            .font(DS.Font.caption).foregroundStyle(.secondary)
                    }
                }
            }

            if let err = model.errorText {
                InlineNotice(icon: "exclamationmark.triangle.fill", tint: .orange, text: err)
            }

            DS.Divider()

            HStack(spacing: DS.Spacing.md) {
                if model.isRunning {
                    Button(loc.t("test.stop")) { model.cancel() }.buttonStyle(.bordered)
                } else {
                    Button(model.finished ? loc.t("test.diskSpeed.retest") : loc.t("test.diskSpeed.start")) { model.start() }
                        .buttonStyle(.borderedProminent)
                    if model.finished {
                        Button(loc.t("test.saveResult")) { onComplete(model.buildResult()) }
                            .buttonStyle(.bordered)
                    }
                }
            }
        }
        .padding(DS.Spacing.xl)
        .checkPane(loc.t("test.diskSpeed.title"))
        .onDisappear { model.cancel() }
    }

    private func speedStat(title: String, value: Double?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(DS.Font.caption).foregroundStyle(.secondary)
            Text(value.map { String(format: "%.0f", $0) } ?? "—")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(.primary)
            + Text(value != nil ? " MB/s" : "")
                .font(DS.Font.caption).foregroundStyle(.secondary)
        }
    }
}
