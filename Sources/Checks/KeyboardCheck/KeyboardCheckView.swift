import SwiftUI

/// 键盘可视化测试：按一下键，对应键位立刻在屏幕上亮起并保持"已测"状态——不是打字框。
struct KeyboardCheckView: View {
    @StateObject private var model = KeyboardTestModel()
    let onFinish: (CheckResult) -> Void

    private let keyUnit: CGFloat = 46
    private let keySpacing: CGFloat = 6

    var body: some View {
        VStack(spacing: 28) {
            header
            keyboardGrid
            footer
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
        .onAppear {
            model.onRequestFinish = finish
            model.start()
        }
        .onDisappear { model.stop() }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Text("Keyboard Test")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.white)
            Text("Press each key in sequence; keys light up when tested. Hold Esc for 1.2s to exit at any time.")
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.7))
            ProgressView(value: model.progress)
                .frame(width: 360)
            Text("\(model.testedKeyCodes.count) / \(model.totalKeyCount) Tested")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.6))
        }
    }

    private var keyboardGrid: some View {
        VStack(spacing: keySpacing) {
            ForEach(Array(KeyboardLayout.rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: keySpacing) {
                    ForEach(row) { key in
                        keyView(key)
                    }
                }
            }
        }
    }

    private func keyView(_ key: KeyDef) -> some View {
        let isPressed = model.pressedKeyCodes.contains(key.keyCode)
        let isStuck = model.stuckKeyCodes.contains(key.keyCode)
        let isTested = model.testedKeyCodes.contains(key.keyCode)

        let fill: Color = isStuck ? .red : isPressed ? .green : isTested ? Color.green.opacity(0.35) : Color.white.opacity(0.08)
        let border: Color = isStuck ? .red : isTested ? .green : Color.white.opacity(0.3)

        return Text(key.label)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.white)
            .frame(width: keyUnit * key.widthUnits, height: keyUnit)
            .background(RoundedRectangle(cornerRadius: 6).fill(fill))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(border, lineWidth: 1.5))
            .animation(.easeOut(duration: 0.12), value: isPressed)
    }

    private var footer: some View {
        HStack(spacing: 16) {
            Button("Finish & Save Result") { finish() }
                .keyboardShortcut(.cancelAction)
            if model.isComplete {
                Text("All keys tested successfully ✅").foregroundStyle(.green)
            }
        }
        .buttonStyle(.bordered)
        .tint(.white)
    }

    private func finish() {
        onFinish(model.buildResult())
    }
}
