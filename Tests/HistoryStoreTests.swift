import XCTest
@testable import ToolCheckMacBook

final class HistoryStoreTests: XCTestCase {
    private let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("toolcheck-history-test-\(UUID().uuidString)", isDirectory: true)

    override func setUpWithError() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: directory)
    }

    private func snapshot(savedAt: Date = Date()) -> SavedReport {
        SavedReport(id: UUID(), savedAt: savedAt, deviceName: "Synthetic MacBook", serial: "TEST-SERIAL",
                    score: 100, batteryCycles: 100, batteryHealth: "95%",
                    report: ToolCheckMacBookReport(generatedAt: savedAt, appVersion: "1.3.0"))
    }

    private var profile: DeviceProfile {
        DeviceProfile(marketingName: "Synthetic MacBook", modelIdentifier: "TestMac1,1",
                      chip: "Synthetic chip", memory: "16 GB", macOSVersion: "macOS",
                      serialNumber: "TEST-SERIAL", architecture: "arm64", modelYear: "2024", productionDate: "")
    }

    func testLegacyHistoryNormalization() {
        var legacyReport = ToolCheckMacBookReport(generatedAt: Date(), appVersion: "1.0.0")
        legacyReport.add(CheckResult(
            id: "battery",
            title: "电池循环",
            status: .pass,
            summary: "正常"
        ))

        let saved = SavedReport(
            id: UUID(),
            savedAt: Date(),
            deviceName: "MacBook Pro（14 英寸，2021）",
            serial: "C02XYZ123456",
            score: 100,
            batteryCycles: 42,
            batteryHealth: "正常",
            report: legacyReport
        )

        let normalized = HistoryStore.normalize(saved)

        XCTAssertEqual(normalized.deviceName, "MacBook Pro (14-inch, 2021)")
        XCTAssertEqual(normalized.batteryHealth, "Normal")
        XCTAssertEqual(normalized.report.results.first?.title, "Battery Cycles")
    }

    func testMissingHistoryIsEmpty() throws {
        XCTAssertTrue(try HistoryStore.load(from: directory.appendingPathComponent("missing.json")).isEmpty)
    }

    func testHistoryRoundTripAndSortOrder() throws {
        let file = directory.appendingPathComponent("nested/history.json")
        let old = snapshot(savedAt: Date(timeIntervalSince1970: 100))
        let recent = snapshot(savedAt: Date(timeIntervalSince1970: 200))
        try HistoryStore.save([old, recent], to: file)
        XCTAssertEqual(try HistoryStore.load(from: file).map(\.id), [recent.id, old.id])
    }

    func testCorruptHistoryThrowsWithoutChangingFile() throws {
        let file = directory.appendingPathComponent("history.json")
        let original = Data("not-json".utf8)
        try original.write(to: file)
        XCTAssertThrowsError(try HistoryStore.load(from: file))
        XCTAssertEqual(try Data(contentsOf: file), original)
    }

    func testHistoryReadFailureIsNotTreatedAsEmptyHistory() {
        XCTAssertThrowsError(try HistoryStore.load(from: directory))
    }

    func testLegacyMigrationPreservesOriginal() throws {
        let legacy = directory.appendingPathComponent("legacy.json")
        let current = directory.appendingPathComponent("new/history.json")
        let saved = snapshot()
        try HistoryStore.save([saved], to: legacy)
        let original = try Data(contentsOf: legacy)
        XCTAssertEqual(try HistoryStore.load(from: current, legacyURL: legacy).first?.id, saved.id)
        XCTAssertEqual(try Data(contentsOf: legacy), original)
        XCTAssertEqual(try Data(contentsOf: current), original)
    }

    func testCorruptLegacyHistoryDoesNotCreateMigratedFile() throws {
        let legacy = directory.appendingPathComponent("legacy.json")
        let current = directory.appendingPathComponent("new/history.json")
        try Data("invalid".utf8).write(to: legacy)
        XCTAssertThrowsError(try HistoryStore.load(from: current, legacyURL: legacy))
        XCTAssertFalse(FileManager.default.fileExists(atPath: current.path))
    }

    func testHistoryWriteFailureThrows() throws {
        let blocker = directory.appendingPathComponent("blocker")
        try Data("file".utf8).write(to: blocker)
        XCTAssertThrowsError(try HistoryStore.save([snapshot()], to: blocker.appendingPathComponent("history.json")))
    }

    @MainActor
    func testFailedSaveDoesNotAddInMemorySnapshot() throws {
        let blocker = directory.appendingPathComponent("blocker")
        let model = AppModel(historyURL: blocker.appendingPathComponent("history.json"))
        model.profile = profile
        try Data("file".utf8).write(to: blocker)
        model.saveCurrentToHistory()
        XCTAssertTrue(model.history.isEmpty)
        XCTAssertNotNil(model.operationError)
    }

    @MainActor
    func testFailedDeletePreservesInMemorySnapshot() throws {
        let file = directory.appendingPathComponent("history.json")
        let saved = snapshot()
        try HistoryStore.save([saved], to: file)
        let model = AppModel(historyURL: file)
        try FileManager.default.removeItem(at: file)
        try FileManager.default.createDirectory(at: file, withIntermediateDirectories: true)
        model.deleteHistory(saved.id)
        XCTAssertEqual(model.history.map(\.id), [saved.id])
        XCTAssertNotNil(model.operationError)
    }

    @MainActor
    func testCorruptHistoryBlocksWritesUntilReloadSucceeds() throws {
        let file = directory.appendingPathComponent("history.json")
        let original = Data("corrupt".utf8)
        try original.write(to: file)
        let model = AppModel(historyURL: file)
        model.profile = profile
        XCTAssertFalse(model.historyAvailable)
        XCTAssertNotNil(model.operationError)
        model.saveCurrentToHistory()
        XCTAssertEqual(try Data(contentsOf: file), original)
        try HistoryStore.save([], to: file)
        model.reloadHistory()
        XCTAssertTrue(model.historyAvailable)
        model.saveCurrentToHistory()
        XCTAssertEqual(model.history.count, 1)
        XCTAssertEqual(try HistoryStore.load(from: file).count, 1)
    }
}
