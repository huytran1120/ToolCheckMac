import SwiftUI

/// Sidebar: Overview + System Checks + Hardware Tests sections, displaying SF Symbols and status dots per row.
struct SidebarView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var loc: LocalizationManager

    var body: some View {
        List(selection: $model.selection) {
            row(.overview)
            row(.history)
            row(.settings)

            Section(loc.t("section.systemChecks")) {
                ForEach(SidebarItem.autoCategories) { row($0) }
                row(.aiModels)
            }

            Section(loc.t("section.hardwareTests")) {
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
                Text(item.localizedTitle(in: loc.currentLanguage))
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
                    Text(loc.t("status.scanning")).font(DS.Font.caption).foregroundStyle(.secondary)
                } else {
                    Image(systemName: "checkmark.seal.fill").foregroundStyle(.green).font(.system(size: 12))
                    Text(loc.t("status.scanComplete")).font(DS.Font.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    Task { await model.rescan() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .disabled(model.isScanning)
                .help(loc.t("status.rescan"))
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm)
        }
    }
}
