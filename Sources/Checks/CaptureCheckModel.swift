import AppKit
import AVFoundation
import Dispatch
import SwiftUI

enum CapturePhase: String {
    case idle, permission, starting, running, stopping, denied, failed
}

enum CaptureFailure: Error, Equatable {
    case noDevice, invalidFormat, notRunning, busy, timedOut
    case startFailed(String)

    var messageKey: String {
        switch self {
        case .noDevice: "test.capture.noDevice"
        case .invalidFormat: "test.capture.invalidFormat"
        case .notRunning: "test.capture.notRunning"
        case .busy: "test.capture.busy"
        case .timedOut: "test.capture.timedOut"
        case .startFailed: "test.capture.startFailed"
        }
    }

    @MainActor func localized(using loc: LocalizationManager) -> String {
        if case .startFailed(let detail) = self {
            return "\(loc.t(messageKey)) \(detail)"
        }
        return loc.t(messageKey)
    }
}

@MainActor
final class CapturePermission {
    static let microphone = CapturePermission(
        status: { AVCaptureDevice.authorizationStatus(for: .audio) },
        request: { await AVCaptureDevice.requestAccess(for: .audio) }
    )
    static let camera = CapturePermission(
        status: { AVCaptureDevice.authorizationStatus(for: .video) },
        request: { await AVCaptureDevice.requestAccess(for: .video) }
    )

    let status: () -> AVAuthorizationStatus
    private let request: () async -> Bool
    private var pending: (id: UUID, task: Task<Bool, Never>)?

    init(status: @escaping () -> AVAuthorizationStatus, request: @escaping () async -> Bool) {
        self.status = status
        self.request = request
    }

    func requestIfNeeded() async -> Bool {
        if let pending { return await pending.task.value }
        switch status() {
        case .authorized: return true
        case .denied, .restricted: return false
        case .notDetermined:
            let id = UUID()
            // A system permission prompt cannot be cancelled. Share it across view lifetimes.
            let task = Task { await request() }
            pending = (id, task)
            let granted = await task.value
            if pending?.id == id { pending = nil }
            return granted
        @unknown default: return false
        }
    }
}

protocol CaptureDevice: AnyObject {
    func start() throws
    func stop()
}

actor CaptureWorker {
    static let microphone = CaptureWorker(label: "com.toolcheckmacbook.microphone")
    static let camera = CaptureWorker(label: "com.toolcheckmacbook.camera")

    private nonisolated let queue: DispatchSerialQueue
    nonisolated var unownedExecutor: UnownedSerialExecutor { queue.asUnownedSerialExecutor() }
    private var device: (any CaptureDevice)?
    private var activeID: UUID?

    init(label: String) {
        queue = DispatchSerialQueue(label: label, qos: .userInitiated)
    }

    func start(id: UUID, makeDevice: @Sendable () -> any CaptureDevice) throws {
        try Task.checkCancellation()
        guard device == nil else { throw CaptureFailure.busy }
        let device = makeDevice()
        self.device = device
        activeID = id
        do {
            try Task.checkCancellation()
            try device.start()
            try Task.checkCancellation()
        } catch {
            stop(id: id)
            throw error
        }
    }

    func stop(id: UUID) {
        guard activeID == id else { return }
        device?.stop()
        device = nil
        activeID = nil
    }
}

@MainActor
class CaptureCheckModel: ObservableObject {
    @Published private(set) var phase: CapturePhase = .idle
    @Published private(set) var failure: CaptureFailure?
    private(set) var activeID: UUID?

    private let permission: CapturePermission
    private let startupTimeout: Duration
    private var work: Task<Void, Never>?
    private var timeout: Task<Void, Never>?

    var isRunning: Bool { phase == .running }
    var permissionDenied: Bool { phase == .denied }
    var canStart: Bool { work == nil && [.idle, .denied, .failed].contains(phase) }
    var canRecordResult: Bool { phase == .running }

    init(permission: CapturePermission, startupTimeout: Duration = .seconds(10)) {
        self.permission = permission
        self.startupTimeout = startupTimeout
    }

    func start() {
        guard canStart else { return }
        let id = UUID()
        activeID = id
        failure = nil
        switch permission.status() {
        case .authorized: phase = .starting
        case .notDetermined: phase = .permission
        case .denied, .restricted:
            phase = .denied
            activeID = nil
            return
        @unknown default:
            phase = .denied
            activeID = nil
            return
        }
        work = Task { [weak self, permission] in
            guard self?.activeID == id, !Task.isCancelled else { return }
            let granted = await permission.requestIfNeeded()
            guard let self, self.activeID == id, !Task.isCancelled else { return }
            guard granted else {
                self.phase = .denied
                self.activeID = nil
                self.work = nil
                return
            }
            self.phase = .starting
            self.armTimeout(id: id)
            do {
                try await self.beginCapture(id: id)
                try Task.checkCancellation()
                guard self.activeID == id else { return }
                self.timeout?.cancel()
                self.phase = .running
                self.work = nil
            } catch is CancellationError {
                // stop() owns cleanup, including a native start that returns after cancellation.
            } catch {
                self.timeout?.cancel()
                await self.endCapture(id: id)
                guard self.activeID == id else { return }
                self.failure = (error as? CaptureFailure) ?? .startFailed(error.localizedDescription)
                self.phase = .failed
                self.activeID = nil
                self.work = nil
            }
        }
    }

    func stop() {
        guard let id = activeID else { return }
        activeID = nil
        timeout?.cancel()
        let previous = work
        previous?.cancel()
        if phase == .permission {
            work = nil
            phase = .idle
            return
        }
        phase = .stopping
        work = Task {
            // Do not overlap native start/stop calls or allow retries before cleanup completes.
            await previous?.value
            await endCapture(id: id)
            work = nil
            phase = failure == nil ? .idle : .failed
        }
    }

    func beginCapture(id: UUID) async throws {
        preconditionFailure("Capture checks must implement beginCapture")
    }

    func endCapture(id: UUID) async {
        preconditionFailure("Capture checks must implement endCapture")
    }

    private func armTimeout(id: UUID) {
        timeout = Task { [weak self, startupTimeout] in
            do {
                try await Task.sleep(for: startupTimeout)
            } catch {
                return
            }
            guard let self, self.activeID == id, self.phase == .starting else { return }
            self.failure = .timedOut
            self.stop()
        }
    }
}
