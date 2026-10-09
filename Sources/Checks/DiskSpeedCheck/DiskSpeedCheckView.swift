import SwiftUI
import Foundation

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

    func start() {
        guard !isRunning else { return }
        writeMBps = nil; readMBps = nil; progress = 0; finished = false; errorText = nil
        isRunning = true
        task = Task { await run() }
    }

    func cancel() {
        task?.cancel(); task = nil
        isRunning = false
    }

    private func run() async {
        let path = NSTemporaryDirectory() + "toolcheckmacbook_speedtest_\(UUID().uuidString).bin"
        let total = totalBytes, chunk = chunkBytes

        // Stream progress back via AsyncStream
        let (stream, cont) = AsyncStream.makeStream(of: (String, Double).self)

        let work = Task.detached { () -> Result<(Double, Double), DiskError> in
            defer { cont.finish() }
            do {
                let w = try DiskSpeedCheckModel.measure(path: path, total: total, chunk: chunk, writing: true) {
                    cont.yield(("Writing", $0))
                }
                let r = try DiskSpeedCheckModel.measure(path: path, total: total, chunk: chunk, writing: false) {
                    cont.yield(("Reading", $0))
                }
                try? FileManager.default.removeItem(atPath: path)
                return .success((w, r))
            } catch let e as DiskError {
                try? FileManager.default.removeItem(atPath: path)
                return .failure(e)
            } catch {
                try? FileManager.default.removeItem(atPath: path)
                return .failure(.io)
            }
        }

        for await (ph, p) in stream {
            phase = ph
            progress = p
        }

        switch await work.value {
        case .success(let (w, r)):
            writeMBps = w
            readMBps = r
            finished = true
        case .failure(let e):
            errorText = e.description
        }
        isRunning = false
    }

    enum DiskError: Error, CustomStringConvertible {
        case open, io
        var description: String {
            switch self {
            case .open: return "Unable to create test file (disk may be full or lack write permissions)"
            case .io: return "I/O error occurred during read/write operation"
            }
        }
    }

    /// Blocking POSIX read/write, returning MB/s. Executed on a background thread.
    nonisolated static func measure(path: String, total: Int, chunk: Int, writing: Bool, progress: (Double) -> Void) throws -> Double {
        let buffer = UnsafeMutableRawPointer.allocate(byteCount: chunk, alignment: 4096)
        defer { buffer.deallocate() }
        if writing { memset(buffer, 0xA5, chunk) }

        let flags = writing ? (O_WRONLY | O_CREAT | O_TRUNC) : O_RDONLY
        let fd = open(path, flags, 0o644)
        guard fd >= 0 else { throw DiskError.open }
        defer { close(fd) }
        // Bypass page cache to measure real drive speed rather than RAM cache
        _ = fcntl(fd, F_NOCACHE, 1)

        let start = DispatchTime.now()
        var done = 0
        while done < total {
            let n = min(chunk, total - done)
            let moved = writing ? write(fd, buffer, n) : read(fd, buffer, n)
            if moved <= 0 { break }
            done += moved
            progress(Double(done) / Double(total))
        }
        if writing { fsync(fd) }   // Ensure data is flushed to disk before stopping timer
        let elapsed = Double(DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000_000
        let mb = Double(done) / (1024 * 1024)
        return elapsed > 0 ? mb / elapsed : 0
    }

    func buildResult() -> CheckResult {
        let w = writeMBps ?? 0, r = readMBps ?? 0
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
    @StateObject private var model = DiskSpeedCheckModel()
    let onComplete: (CheckResult) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            CheckHeader(
                icon: "speedometer",
                title: "Disk Speed Test",
                subtitle: "Sequentially writes and reads 1GB to measure real disk speeds (bypassing system cache). Detects slow external drives, fake capacity drives, or performance issues."
            )

            Card {
                HStack(spacing: DS.Spacing.xl) {
                    speedStat(title: "Sequential Write", value: model.writeMBps)
                    speedStat(title: "Sequential Read", value: model.readMBps)
                    Spacer()
                }
                if model.isRunning {
                    ProgressView(value: model.progress) {
                        Text("\(model.phase) \(Int(model.progress * 100))%")
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
                    Button("Stop") { model.cancel() }.buttonStyle(.bordered)
                } else {
                    Button(model.finished ? "Retest Speed" : "Start Speed Test") { model.start() }
                        .buttonStyle(.borderedProminent)
                    if model.finished {
                        Button("Save Result") { onComplete(model.buildResult()) }
                            .buttonStyle(.bordered)
                    }
                }
            }
        }
        .padding(DS.Spacing.xl)
        .checkPane("Disk Speed Test")
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
