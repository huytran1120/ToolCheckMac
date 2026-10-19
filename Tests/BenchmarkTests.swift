import Darwin
import XCTest
@testable import ToolCheckMacBook

@MainActor
final class BenchmarkTests: XCTestCase {
    private func temporaryFile() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("toolcheck-benchmark-test-\(UUID().uuidString)")
    }

    func testDiskWriteAndReadComplete() throws {
        let file = temporaryFile()
        defer { try? FileManager.default.removeItem(at: file) }
        var progress = 0.0
        let writeSpeed = try DiskSpeedCheckModel.measure(path: file.path, total: 65536, chunk: 4096, writing: true) {
            progress = $0
        }
        XCTAssertGreaterThan(writeSpeed, 0)
        XCTAssertEqual(progress, 1)
        let readSpeed = try DiskSpeedCheckModel.measure(path: file.path, total: 65536, chunk: 4096, writing: false) { _ in }
        XCTAssertGreaterThan(readSpeed, 0)
    }

    func testEarlyEOFDoesNotProduceSpeed() throws {
        let file = temporaryFile()
        defer { try? FileManager.default.removeItem(at: file) }
        try Data(repeating: 1, count: 16).write(to: file)
        XCTAssertThrowsError(try DiskSpeedCheckModel.measure(path: file.path, total: 64, chunk: 16, writing: false) { _ in }) {
            guard case DiskSpeedCheckModel.DiskError.incomplete = $0 else {
                return XCTFail("Expected an incomplete-read error")
            }
        }
    }

    func testFlushFailureDoesNotProduceSpeed() {
        let file = temporaryFile()
        defer { try? FileManager.default.removeItem(at: file) }
        XCTAssertThrowsError(try DiskSpeedCheckModel.measure(
            path: file.path, total: 4096, chunk: 4096, writing: true,
            synchronize: { _ in errno = EIO; return -1 }, progress: { _ in }
        )) {
            guard case DiskSpeedCheckModel.DiskError.flush = $0 else {
                return XCTFail("Expected a flush error")
            }
        }
    }

    func testDiskCancellationIsCheckedBetweenChunks() {
        let file = temporaryFile()
        defer { try? FileManager.default.removeItem(at: file) }
        var chunks = 0
        XCTAssertThrowsError(try DiskSpeedCheckModel.measure(
            path: file.path, total: 65536, chunk: 4096, writing: true,
            isCancelled: { chunks >= 2 }, progress: { _ in chunks += 1 }
        )) {
            XCTAssertTrue($0 is CancellationError)
        }
        XCTAssertEqual(chunks, 2)
    }

    func testWriteErrorDoesNotProduceSpeed() {
        let file = temporaryFile()
        defer { try? FileManager.default.removeItem(at: file) }
        XCTAssertThrowsError(try DiskSpeedCheckModel.measure(
            path: file.path, total: 4096, chunk: 4096, writing: true,
            transfer: { _, _, _, _ in errno = EIO; return -1 }, progress: { _ in }
        )) {
            guard case DiskSpeedCheckModel.DiskError.io = $0 else {
                return XCTFail("Expected a write I/O error")
            }
        }
    }

    func testPartialWritesCompleteAllBytes() throws {
        let file = temporaryFile()
        defer { try? FileManager.default.removeItem(at: file) }
        var progress = 0.0
        _ = try DiskSpeedCheckModel.measure(
            path: file.path, total: 64, chunk: 16, writing: true,
            transfer: { fd, buffer, count, _ in Darwin.write(fd, buffer, min(3, count)) },
            progress: { progress = $0 }
        )
        XCTAssertEqual(try Data(contentsOf: file).count, 64)
        XCTAssertEqual(progress, 1)
    }

    func testInterruptedFlushRetries() throws {
        let file = temporaryFile()
        defer { try? FileManager.default.removeItem(at: file) }
        var calls = 0
        _ = try DiskSpeedCheckModel.measure(
            path: file.path, total: 4096, chunk: 4096, writing: true,
            synchronize: { fd in
                calls += 1
                if calls == 1 { errno = EINTR; return -1 }
                return Darwin.fsync(fd)
            }, progress: { _ in }
        )
        XCTAssertEqual(calls, 2)
    }

    func testInvalidSizeAndMissingFileThrow() {
        XCTAssertThrowsError(try DiskSpeedCheckModel.measure(path: temporaryFile().path, total: 0, chunk: 4096, writing: true) { _ in })
        XCTAssertThrowsError(try DiskSpeedCheckModel.measure(path: temporaryFile().path, total: 4096, chunk: 4096, writing: false) { _ in })
    }

    func testCancelledDiskRunCannotBeSavedOrRestartedBeforeCleanup() async throws {
        let model = DiskSpeedCheckModel()
        model.start()
        model.cancel()
        model.start()
        try await waitForStop { model.isRunning }
        XCTAssertFalse(model.finished)
        XCTAssertNil(model.writeMBps)
        XCTAssertNil(model.readMBps)
        XCTAssertEqual(model.buildResult().status, .skipped)
    }

    func testStressTestUsesRealElapsedTime() async throws {
        let model = PerformanceCheckModel(durationSeconds: 0.08, readSensors: { nil })
        let start = ContinuousClock.now
        model.start()
        try await waitForStop { model.isRunning }
        let duration = start.duration(to: .now)
        XCTAssertGreaterThanOrEqual(model.elapsedSeconds, 0.08)
        XCTAssertLessThanOrEqual(model.elapsedSeconds, Double(duration.components.seconds) + Double(duration.components.attoseconds) / 1e18)
        XCTAssertTrue(model.finished)
        XCTAssertEqual(model.progress, 1)
        XCTAssertEqual(model.buildResult().status, .pass)
        XCTAssertEqual(model.buildResult().rawDetails["Test Duration"], String(format: "%.2f seconds", model.elapsedSeconds))
    }

    func testCancelledStressTestCannotReportPass() async throws {
        let model = PerformanceCheckModel(readSensors: { nil })
        model.start()
        model.cancel()
        try await waitForStop { model.isRunning }
        XCTAssertFalse(model.finished)
        XCTAssertEqual(model.buildResult().status, .skipped)
    }

    private func waitForStop(_ running: () -> Bool) async throws {
        let deadline = ContinuousClock.now + .seconds(5)
        while running(), ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTAssertFalse(running(), "Benchmark did not stop within five seconds")
    }
}
