import Foundation

enum ScreenStage: Int, CaseIterable {
    case black, white, red, green, blue, grayGradient, checkerboard

    var title: String {
        switch self {
        case .black: return "Solid Black — Check for bright spots/backlight bleed"
        case .white: return "Solid White — Check for dead/dark spots"
        case .red: return "Solid Red — Check for defective subpixels"
        case .green: return "Solid Green — Check for defective subpixels"
        case .blue: return "Solid Blue — Check for defective subpixels"
        case .grayGradient: return "Grayscale Gradient — Check for banding/color gradation"
        case .checkerboard: return "Checkerboard — Check for image retention/uniformity"
        }
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
