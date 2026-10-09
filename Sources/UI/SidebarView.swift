import SwiftUI

/// 侧边栏：概览 + 系统检测 + 硬件测试三段分组，每行显示 SF Symbol 与状态圆点。
struct SidebarView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        List(selection: $model.selection) {
            row(.overview)
            row(.history)
            row(.settings)

            Section("System Checks") {
                ForEach(SidebarItem.autoCategories) { row($0) }
                row(.aiModels)
            }

            Section("Hardware Tests") {
                ForEach(SidebarItem.interactiveTests) { row($0) }
            }
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: 220, ideal: 240, max: 280)
        .safeAreaInset(edge: .bottom) { rescanBar }
    }

    private func row(_ item: SidebarItem) -> some View {
        Label {
            HStack {
                Text(item.title)
                Spacer()
                if let status = model.status(for: item) {
                    StatusDot(status: status)
                } else if item.isInteractive {
                    Image(systemName: "circle.dashed")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                }
            }
        } icon: {
            Image(systemName: item.icon)
        }
        .tag(item)
    }

    private var rescanBar: some View {
        VStack(spacing: 0) {
            DS.Divider()
            HStack(spacing: DS.Spacing.sm) {
                if model.isScanning {
                    ProgressView().controlSize(.small)
                    Text("Scanning…").font(DS.Font.caption).foregroundStyle(.secondary)
                } else {
                    Image(systemName: "checkmark.seal.fill").foregroundStyle(.green).font(.system(size: 12))
                    Text("System scan complete").font(DS.Font.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    Task { await model.rescan() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .disabled(model.isScanning)
                .help("Rescan")
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm)
        }
    }
}
