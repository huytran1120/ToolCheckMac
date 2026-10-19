import XCTest
@testable import ToolCheckMacBook

final class AIAdvisorTests: XCTestCase {

    func testMemoryBudgetCalculation() {
        // ramGB - 8, min 2
        XCTAssertEqual(AIModelAdvisor.budgetGB(ramGB: 8), 2.0)
        XCTAssertEqual(AIModelAdvisor.budgetGB(ramGB: 16), 8.0)
        XCTAssertEqual(AIModelAdvisor.budgetGB(ramGB: 32), 24.0)
        XCTAssertEqual(AIModelAdvisor.budgetGB(ramGB: 64), 56.0)
    }

    func testAIVerdictLocalization() {
        let smooth = AIVerdict.smooth
        XCTAssertEqual(smooth.localizedLabel(in: .vietnamese), "Chạy mượt")
        XCTAssertEqual(smooth.localizedLabel(in: .english), "Runs Smoothly")

        let runnable = AIVerdict.runnable
        XCTAssertEqual(runnable.localizedLabel(in: .vietnamese), "Chạy được")
        XCTAssertEqual(runnable.localizedLabel(in: .english), "Runnable")

        let tight = AIVerdict.tight
        XCTAssertEqual(tight.localizedLabel(in: .vietnamese), "Vừa đủ")
        XCTAssertEqual(tight.localizedLabel(in: .english), "Barely Runnable")

        let no = AIVerdict.no
        XCTAssertEqual(no.localizedLabel(in: .vietnamese), "Không khuyến nghị")
        XCTAssertEqual(no.localizedLabel(in: .english), "Not Recommended")
    }

    func testAIVerdictRank() {
        XCTAssertGreaterThan(AIVerdict.smooth.rank, AIVerdict.runnable.rank)
        XCTAssertGreaterThan(AIVerdict.runnable.rank, AIVerdict.tight.rank)
        XCTAssertGreaterThan(AIVerdict.tight.rank, AIVerdict.no.rank)
    }
}
