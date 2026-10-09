import SwiftUI

/// Display test: Fullscreen test patterns with pure colors and gradients. Click or press Space to advance.
struct ScreenCheckView: View {
    @StateObject private var model = ScreenCheckModel()
    @FocusState private var isFocused: Bool
    let onFinish: (CheckResult) -> Void

    var body: some View {
        ZStack {
            stageBackground(for: model.currentStage)
                .ignoresSafeArea()

            VStack {
                Spacer()
                overlayBar
            }
        }
        .focusable()
        .focused($isFocused)
        .onAppear { isFocused = true }
        .onKeyPress(.space) { model.advance(); return .handled }
        .onKeyPress(.rightArrow) { model.advance(); return .handled }
        .onKeyPress(.escape) { finish(exitedEarly: !model.isLastStage); return .handled }
        .onKeyPress(characters: CharacterSet(charactersIn: "fF")) { _ in
            model.flagCurrent()
            return .handled
        }
        .onTapGesture { model.advance() }
    }

    @ViewBuilder
    private func stageBackground(for stage: ScreenStage) -> some View {
        switch stage {
        case .black: Color.black
        case .white: Color.white
        case .red: Color.red
        case .green: Color.green
        case .blue: Color.blue
        case .grayGradient:
            LinearGradient(colors: [.black, .white], startPoint: .leading, endPoint: .trailing)
        case .checkerboard:
            CheckerboardView()
        }
    }

    private var overlayBar: some View {
        VStack(spacing: 10) {
            Text(model.currentStage.title)
                .font(.system(size: 16, weight: .semibold))
            Text("Screen \(model.currentIndex + 1) of \(model.stages.count) · Click or press Space for next · Press F to flag anomaly · Esc to exit")
                .font(.system(size: 12))
                .opacity(0.75)
            HStack(spacing: 12) {
                Button("Flag Anomaly") { model.flagCurrent() }
                Button(model.isLastStage ? "Complete Test" : "Next") {
                    if model.isLastStage {
                        finish(exitedEarly: false)
                    } else {
                        model.advance()
                    }
                }
            }
            .buttonStyle(.bordered)
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .foregroundStyle(model.currentStage == .white || model.currentStage == .green ? .black : .white)
        .padding(.bottom, 40)
    }

    private func finish(exitedEarly: Bool) {
        onFinish(model.buildResult(exitedEarly: exitedEarly))
    }
}

private struct CheckerboardView: View {
    var body: some View {
        Canvas { context, size in
            let cell: CGFloat = 40
            let cols = Int((size.width / cell).rounded(.up))
            let rows = Int((size.height / cell).rounded(.up))
            for r in 0..<rows {
                for c in 0..<cols {
                    let isBlack = (r + c).isMultiple(of: 2)
                    let rect = CGRect(x: CGFloat(c) * cell, y: CGFloat(r) * cell, width: cell, height: cell)
                    context.fill(Path(rect), with: .color(isBlack ? .black : .white))
                }
            }
        }
    }
}
