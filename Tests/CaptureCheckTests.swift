import AVFoundation
import os
import XCTest
@testable import ToolCheckMacBook

@MainActor
final class CaptureCheckTests: XCTestCase {
    func testImmediateStopDoesNotPresentPermissionAfterLeaving() async throws {
        var requests = 0
        let probe = DeviceProbe()
        let model = TestCaptureModel(
            permission: CapturePermission(status: { .notDetermined }, request: { requests += 1; return true }),
            probe: probe
        )
        model.start()
        model.stop()
        try await Task.sleep(for: .milliseconds(20))
        XCTAssertEqual(requests, 0)
        XCTAssertEqual(probe.snapshot.creations, 0)
        XCTAssertEqual(model.phase, .idle)
    }

    func testDeniedAndRestrictedPermissionsNeverOpenHardware() async throws {
        for status in [AVAuthorizationStatus.denied, .restricted] {
            var requests = 0
            let permission = CapturePermission(status: { status }, request: { requests += 1; return true })
            let probe = DeviceProbe()
            let model = TestCaptureModel(permission: permission, probe: probe)
            model.start()
            try await waitUntil { model.phase == .denied }
            XCTAssertEqual(requests, 0)
            XCTAssertEqual(probe.snapshot.creations, 0)
            XCTAssertFalse(model.canRecordResult)
            XCTAssertTrue(model.canStart)
        }
    }

    func testAuthorizedDeviceLifecycleRunsOffMainThread() async throws {
        let probe = DeviceProbe()
        let model = TestCaptureModel(permission: authorizedPermission(), probe: probe)
        model.start()
        model.start()
        try await waitUntil { model.isRunning }
        XCTAssertEqual(probe.snapshot.starts, 1)
        XCTAssertTrue(model.canRecordResult)
        model.stop()
        try await waitUntil { model.phase == .idle }
        XCTAssertEqual(probe.snapshot.stops, 1)
        XCTAssertEqual(probe.snapshot.mainThreadCalls, 0, "Creation, start and stop must all leave the UI thread")
        XCTAssertFalse(model.canRecordResult)
    }

    func testPendingPermissionIsSharedAcrossViewLifetimes() async throws {
        let prompt = PermissionPrompt()
        let permission = CapturePermission(status: { .notDetermined }, request: { await prompt.request() })
        let oldProbe = DeviceProbe()
        let old = TestCaptureModel(permission: permission, probe: oldProbe)
        old.start()
        try await waitUntil { prompt.requests == 1 }
        old.stop()
        XCTAssertEqual(old.phase, .idle)

        let newProbe = DeviceProbe()
        let new = TestCaptureModel(permission: permission, probe: newProbe)
        new.start()
        XCTAssertFalse(new.canRecordResult)
        prompt.answer(true)
        try await waitUntil { new.isRunning }
        XCTAssertEqual(prompt.requests, 1)
        XCTAssertEqual(oldProbe.snapshot.starts, 0)
        XCTAssertEqual(old.phase, .idle)
        new.stop()
        try await waitUntil { new.phase == .idle }
    }

    func testDeniedPromptDoesNotStartCapture() async throws {
        let prompt = PermissionPrompt()
        let probe = DeviceProbe()
        let model = TestCaptureModel(
            permission: CapturePermission(status: { .notDetermined }, request: { await prompt.request() }),
            probe: probe
        )
        model.start()
        try await waitUntil { prompt.requests == 1 }
        prompt.answer(false)
        try await waitUntil { model.permissionDenied }
        XCTAssertEqual(probe.snapshot.starts, 0)
        XCTAssertFalse(model.canRecordResult)
    }

    func testStartupTimeoutDoesNotLimitTimeToAnswerPermissionPrompt() async throws {
        let prompt = PermissionPrompt()
        let model = TestCaptureModel(
            permission: CapturePermission(status: { .notDetermined }, request: { await prompt.request() }),
            probe: DeviceProbe(),
            startupTimeout: .milliseconds(10)
        )
        model.start()
        try await waitUntil { prompt.requests == 1 }
        try await Task.sleep(for: .milliseconds(40))
        XCTAssertEqual(model.phase, .permission)
        XCTAssertNil(model.failure)
        prompt.answer(false)
        try await waitUntil { model.phase == .denied }
    }

    func testStopDuringNativeStartupWaitsForCleanupBeforeRetry() async throws {
        let probe = DeviceProbe(blockStart: true)
        defer { probe.releaseStart.signal() }
        let model = TestCaptureModel(permission: authorizedPermission(), probe: probe)
        model.start()
        try await waitUntil { probe.snapshot.starts == 1 }
        XCTAssertEqual(model.phase, .starting)
        model.stop()
        model.start()
        XCTAssertEqual(model.phase, .stopping)
        XCTAssertFalse(model.canStart)
        XCTAssertFalse(model.canRecordResult)
        probe.releaseStart.signal()
        try await waitUntil { model.phase == .idle }
        XCTAssertEqual(probe.snapshot.starts, 1)
        XCTAssertEqual(probe.snapshot.stops, 1)
        XCTAssertEqual(probe.snapshot.mainThreadCalls, 0)

        probe.releaseStart.signal()
        model.start()
        try await waitUntil { model.isRunning }
        model.stop()
        try await waitUntil { model.phase == .idle }
        XCTAssertEqual(probe.snapshot.starts, 2)
        XCTAssertEqual(probe.snapshot.stops, 2)
        XCTAssertEqual(probe.snapshot.maximumActive, 1)
    }

    func testCancellationDuringDeviceCreationNeverStartsTheDevice() async throws {
        let probe = DeviceProbe(blockCreation: true)
        defer { probe.releaseCreation.signal() }
        let model = TestCaptureModel(permission: authorizedPermission(), probe: probe)
        model.start()
        try await waitUntil { probe.snapshot.creations == 1 }
        model.stop()
        XCTAssertEqual(model.phase, .stopping)
        probe.releaseCreation.signal()
        try await waitUntil { model.phase == .idle }
        XCTAssertEqual(probe.snapshot.starts, 0)
        XCTAssertEqual(probe.snapshot.stops, 1)
        XCTAssertEqual(probe.snapshot.active, 0)
    }

    func testNativeStartupTimeoutStaysResponsiveAndNeverReportsRunningLate() async throws {
        let probe = DeviceProbe(blockStart: true)
        defer { probe.releaseStart.signal() }
        let model = TestCaptureModel(
            permission: authorizedPermission(), probe: probe, startupTimeout: .milliseconds(30)
        )
        model.start()
        try await waitUntil { model.failure == .timedOut }
        XCTAssertEqual(model.phase, .stopping)
        XCTAssertFalse(model.canRecordResult)
        XCTAssertFalse(model.canStart)
        model.start()
        probe.releaseStart.signal()
        try await waitUntil { model.phase == .failed }
        XCTAssertEqual(model.failure, .timedOut)
        XCTAssertEqual(probe.snapshot.starts, 1)
        XCTAssertEqual(probe.snapshot.stops, 1)
        XCTAssertFalse(model.isRunning)
        XCTAssertTrue(model.canStart)
    }

    func testFailedStartupIsNotPermissionDenialAndReleasesPartialResources() async throws {
        let probe = DeviceProbe(failStart: true)
        let model = TestCaptureModel(permission: authorizedPermission(), probe: probe)
        model.start()
        try await waitUntil { model.phase == .failed }
        XCTAssertEqual(model.failure, .noDevice)
        XCTAssertFalse(model.permissionDenied)
        XCTAssertFalse(model.canRecordResult)
        XCTAssertEqual(probe.snapshot.stops, 1)
        XCTAssertEqual(probe.snapshot.active, 0)
        XCTAssertTrue(model.canStart)
    }

    func testNativeStopDoesNotBlockUIOrAllowOverlappingRestart() async throws {
        let probe = DeviceProbe(blockStop: true)
        defer { probe.releaseStop.signal() }
        let model = TestCaptureModel(permission: authorizedPermission(), probe: probe)
        model.start()
        try await waitUntil { model.isRunning }
        model.stop()
        try await waitUntil { probe.snapshot.stops == 1 }
        XCTAssertEqual(model.phase, .stopping)
        XCTAssertFalse(model.canStart)
        model.start()
        XCTAssertEqual(probe.snapshot.starts, 1)
        probe.releaseStop.signal()
        try await waitUntil { model.phase == .idle }
        XCTAssertEqual(probe.snapshot.mainThreadCalls, 0)
    }

    func testSharedWorkerRejectsOverlappingDevicesAndIgnoresStaleStops() async throws {
        let worker = CaptureWorker(label: "test.capture.ownership")
        let probe = DeviceProbe()
        let first = UUID()
        let second = UUID()
        try await worker.start(id: first) { TestDevice(probe: probe) }
        do {
            try await worker.start(id: second) { TestDevice(probe: probe) }
            XCTFail("A second device must not replace an active device")
        } catch {
            XCTAssertEqual(error as? CaptureFailure, .busy)
        }
        await worker.stop(id: second)
        XCTAssertEqual(probe.snapshot.stops, 0)
        await worker.stop(id: first)
        try await worker.start(id: second) { TestDevice(probe: probe) }
        await worker.stop(id: first)
        XCTAssertEqual(probe.snapshot.stops, 1)
        await worker.stop(id: second)
        XCTAssertEqual(probe.snapshot.stops, 2)
        XCTAssertEqual(probe.snapshot.maximumActive, 1)
    }

    private func authorizedPermission() -> CapturePermission {
        CapturePermission(status: { .authorized }, request: {
            XCTFail("An authorized device must not request permission again")
            return false
        })
    }

    private func waitUntil(_ condition: () -> Bool) async throws {
        let deadline = ContinuousClock.now + .seconds(2)
        while !condition(), ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(5))
        }
        XCTAssertTrue(condition(), "Capture lifecycle did not reach the expected state")
    }
}

@MainActor
private final class PermissionPrompt {
    private(set) var requests = 0
    private var continuation: CheckedContinuation<Bool, Never>?

    func request() async -> Bool {
        requests += 1
        return await withCheckedContinuation { continuation = $0 }
    }

    func answer(_ granted: Bool) {
        continuation?.resume(returning: granted)
        continuation = nil
    }
}

@MainActor
private final class TestCaptureModel: CaptureCheckModel {
    private let worker = CaptureWorker(label: "test.capture.lifecycle")
    private let probe: DeviceProbe

    init(permission: CapturePermission, probe: DeviceProbe, startupTimeout: Duration = .seconds(1)) {
        self.probe = probe
        super.init(permission: permission, startupTimeout: startupTimeout)
    }

    override func beginCapture(id: UUID) async throws {
        try await worker.start(id: id) { [probe] in TestDevice(probe: probe) }
    }

    override func endCapture(id: UUID) async {
        await worker.stop(id: id)
    }
}

private final class DeviceProbe: Sendable {
    struct State {
        var creations = 0
        var starts = 0
        var stops = 0
        var active = 0
        var maximumActive = 0
        var mainThreadCalls = 0
    }

    let state = OSAllocatedUnfairLock(initialState: State())
    let releaseCreation = DispatchSemaphore(value: 0)
    let releaseStart = DispatchSemaphore(value: 0)
    let releaseStop = DispatchSemaphore(value: 0)
    let blockCreation: Bool
    let blockStart: Bool
    let blockStop: Bool
    let failStart: Bool
    var snapshot: State { state.withLock { $0 } }

    init(blockCreation: Bool = false, blockStart: Bool = false, blockStop: Bool = false, failStart: Bool = false) {
        self.blockCreation = blockCreation
        self.blockStart = blockStart
        self.blockStop = blockStop
        self.failStart = failStart
    }
}

private final class TestDevice: CaptureDevice {
    let probe: DeviceProbe
    private var started = false

    init(probe: DeviceProbe) {
        self.probe = probe
        probe.state.withLock {
            $0.creations += 1
            if Thread.isMainThread { $0.mainThreadCalls += 1 }
        }
        if probe.blockCreation {
            _ = probe.releaseCreation.wait(timeout: .now() + 3)
        }
    }

    func start() throws {
        started = true
        probe.state.withLock {
            $0.starts += 1
            $0.active += 1
            $0.maximumActive = max($0.maximumActive, $0.active)
            if Thread.isMainThread { $0.mainThreadCalls += 1 }
        }
        if probe.blockStart {
            guard probe.releaseStart.wait(timeout: .now() + 3) == .success else {
                throw CaptureFailure.timedOut
            }
        }
        if probe.failStart { throw CaptureFailure.noDevice }
    }

    func stop() {
        probe.state.withLock {
            $0.stops += 1
            if Thread.isMainThread { $0.mainThreadCalls += 1 }
        }
        if probe.blockStop {
            _ = probe.releaseStop.wait(timeout: .now() + 3)
        }
        if started {
            probe.state.withLock { $0.active -= 1 }
            started = false
        }
    }
}
