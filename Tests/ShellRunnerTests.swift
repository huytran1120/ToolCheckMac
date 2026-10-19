import XCTest
@testable import ToolCheckMacBook

final class ShellRunnerTests: XCTestCase {
    func testCapturesStandardOutputAndError() throws {
        let output = try ShellRunner.execute("/bin/sh", ["-c", "printf output; printf diagnostic >&2"])
        XCTAssertEqual(output.stdout, "output")
        XCTAssertEqual(output.stderr, "diagnostic")
    }

    func testDrainsBothPipesBeyondTheirCapacity() throws {
        let output = try ShellRunner.execute("/bin/sh", [
            "-c", "/usr/bin/head -c 262144 /dev/zero; /usr/bin/head -c 262144 /dev/zero >&2",
        ], timeout: 10)
        XCTAssertEqual(output.stdout.utf8.count, 262144)
        XCTAssertEqual(output.stderr.utf8.count, 262144)
    }

    func testNonZeroExitIncludesDiagnostic() {
        XCTAssertThrowsError(try ShellRunner.execute("/bin/sh", ["-c", "printf failure >&2; exit 7"])) {
            guard case ShellRunner.CommandError.nonZeroExit(let status, let stderr) = $0 else {
                return XCTFail("Expected an explicit non-zero exit error")
            }
            XCTAssertEqual(status, 7)
            XCTAssertEqual(stderr, "failure")
        }
    }

    func testTimeoutTerminatesProcess() {
        let start = Date()
        XCTAssertThrowsError(try ShellRunner.execute("/bin/sleep", ["10"], timeout: 0.05)) {
            guard case ShellRunner.CommandError.timedOut = $0 else {
                return XCTFail("Expected a timeout error")
            }
        }
        XCTAssertLessThan(Date().timeIntervalSince(start), 3)
    }

    func testTimeoutKillsProcessThatIgnoresTermination() {
        XCTAssertThrowsError(try ShellRunner.execute("/bin/sh", ["-c", "trap '' TERM; while :; do :; done"], timeout: 0.1)) {
            guard case ShellRunner.CommandError.timedOut = $0 else {
                return XCTFail("Expected a timeout error")
            }
        }
    }

    func testContinuousOutputStillRespectsTimeout() {
        let start = Date()
        XCTAssertThrowsError(try ShellRunner.execute("/usr/bin/yes", ["test"], timeout: 0.02)) {
            guard case ShellRunner.CommandError.timedOut = $0 else {
                return XCTFail("Expected continuous output to respect the timeout")
            }
        }
        XCTAssertLessThan(Date().timeIntervalSince(start), 3)
    }

    func testInvalidTimeoutAndMissingExecutableThrow() {
        for timeout in [0, -1, Double.infinity, Double.nan] {
            XCTAssertThrowsError(try ShellRunner.execute("/usr/bin/true", [], timeout: timeout))
        }
        XCTAssertThrowsError(try ShellRunner.execute("/does-not-exist/toolcheckmacbook-test", []))
    }
}
