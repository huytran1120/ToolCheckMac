import Foundation

enum ScreenStage: Int, CaseIterable {
    case black, white, red, green, blue, grayGradient, checkerboard

    func localizedTitle(in language: AppLanguage) -> String {
        switch self {
        case .black: return LocalizationManager.translate(key: "test.screen.black", language: language)
        case .white: return LocalizationManager.translate(key: "test.screen.white", language: language)
        case .red: return LocalizationManager.translate(key: "test.screen.red", language: language)
        case .green: return LocalizationManager.translate(key: "test.screen.green", language: language)
        case .blue: return LocalizationManager.translate(key: "test.screen.blue", language: language)
        case .grayGradient: return LocalizationManager.translate(key: "test.screen.gradient", language: language)
        case .checkerboard: return LocalizationManager.translate(key: "test.screen.checkerboard", language: language)
        }
    }

    var title: String {
        localizedTitle(in: .english)
    }
}

@MainActor
final class ScreenCheckModel: ObservableObject {
    @Published var currentIndex: Int = 0
    @Published var flaggedStages: Set<Int> = []
    @Published var didFinishEarly = false

    let stages = ScreenStage.allCases

    var currentStage: ScreenStage { stages[currentIndex] }
    var isLastStage: Bool { currentIndex == stages.count - 1 }
    var completedCount: Int { currentIndex + (isLastStage ? 1 : 0) }

    func advance() {
        if isLastStage {
            didFinishEarly = false
        } else {
            currentIndex += 1
        }
    }

    func flagCurrent() {
        flaggedStages.insert(currentIndex)
    }

    func buildResult(exitedEarly: Bool) -> CheckResult {
        let stageNames = flaggedStages.sorted().map { stages[$0].title }
        var details: [String: String] = [
            "Completed Stages": "\(exitedEarly ? currentIndex : stages.count) / \(stages.count)",
        ]
        if !stageNames.isEmpty {
            details["Stages Flagged with Anomalies"] = stageNames.joined(separator: "; ")
        }

        if !flaggedStages.isEmpty {
            return CheckResult(
                id: "screen",
                title: "Display Test",
                status: .warning,
                summary: "Anomalies flagged in the following screens: \(stageNames.joined(separator: ", ")), recommend re-inspecting in a dimmer environment",
                rawDetails: details
            )
        }
        if exitedEarly {
            return CheckResult(
                id: "screen",
                title: "Display Test",
                status: .warning,
                summary: "Exited after testing only \(currentIndex)/\(stages.count) screens, complete test recommended",
                rawDetails: details
            )
        }
        return CheckResult(
            id: "screen",
            title: "Display Test",
            status: .pass,
            summary: "Tested all \(stages.count) screens (solid colors, grayscale, checkerboard) with no abnormalities found",
            rawDetails: details
        )
    }
}
