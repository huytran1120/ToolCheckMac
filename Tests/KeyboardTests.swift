import AppKit
import XCTest
@testable import ToolCheckMacBook

@MainActor
final class KeyboardTests: XCTestCase {
    private func event(_ type: NSEvent.EventType, code: UInt16, flags: NSEvent.ModifierFlags = []) throws -> NSEvent {
        try XCTUnwrap(NSEvent.keyEvent(
            with: type, location: .zero, modifierFlags: flags, timestamp: 0,
            windowNumber: 0, context: nil, characters: "", charactersIgnoringModifiers: "",
            isARepeat: false, keyCode: code
        ))
    }

    func testCommandKeysAreRecordedAndShortcutsPassThrough() throws {
        let model = KeyboardTestModel()
        for code in [UInt16(55), 54] {
            let down = try event(.flagsChanged, code: code, flags: .command)
            XCTAssertTrue(model.process(down) === down)
            XCTAssertTrue(model.testedKeyCodes.contains(code))
            XCTAssertTrue(model.pressedKeyCodes.contains(code))
            _ = model.process(try event(.flagsChanged, code: code))
            XCTAssertFalse(model.pressedKeyCodes.contains(code))
        }
        let shortcut = try event(.keyDown, code: 12, flags: .command)
        XCTAssertTrue(model.process(shortcut) === shortcut)
    }

    func testOrdinaryKeysAreConsumedAndUnknownKeysDoNotInflateCoverage() throws {
        let model = KeyboardTestModel()
        XCTAssertNil(model.process(try event(.keyDown, code: 0)))
        XCTAssertTrue(model.testedKeyCodes.contains(0))
        _ = model.process(try event(.keyDown, code: 200))
        XCTAssertEqual(model.testedKeyCodes.count, 1)
    }

    func testEveryLayoutKeyCanBeRecorded() throws {
        let model = KeyboardTestModel()
        for key in KeyboardLayout.allKeys {
            _ = model.process(try event(.keyDown, code: key.keyCode, flags: key.label == "⌘" ? .command : []))
        }
        XCTAssertTrue(model.isComplete)
        XCTAssertEqual(model.progress, 1)
        XCTAssertEqual(model.buildResult().status, .pass)
    }
}
