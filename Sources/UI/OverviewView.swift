import SwiftUI

/// 概览页：打开即见。机器档案头部 + 综合评分 + 红旗区 + 各分类状态一览（可点击跳转）。
struct OverviewView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                deviceHeader
                if !model.report.redFlags.isEmpty { redFlagSection }
                categorySummary
                testSummary
                footer
            }
            .padding(DS.Spacing.xl)
            .frame(maxWidth: 780)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .navigationTitle("Overview")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    model.saveCurrentToHistory()
                } label: {
                    Label("Save to History", systemImage: "square.and.arrow.down")
                }
                .disabled(model.isScanning || model.profile == nil)
                .help("Save current test snapshot for future comparison (e.g. battery degradation)")
            }
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        ReportExporter.export(profile: model.profile, report: model.report, format: .png)
                    } label: { Label("Export as Image (PNG)", systemImage: "photo") }
                    Button {
                        ReportExporter.export(profile: model.profile, report: model.report, format: .pdf)
                    } label: { Label("Export as PDF", systemImage: "doc.richtext") }
                } label: {
                    Label("Export Report", systemImage: "square.and.arrow.up")
                }
                .disabled(model.isScanning)
            }
        }
    }

    // MARK: - 机器档案头部

    private var deviceHeader: some View {
        Card {
            HStack(alignment: .top, spacing: DS.Spacing.lg) {
                Image(systemName: deviceSymbol)
                    .font(.system(size: 46))
                    .foregroundStyle(.tint)
                    .frame(width: 64)
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    Text(model.profile?.marketingName ?? "Identifying model…")
                        .font(DS.Font.largeTitle)
                        .fixedSize(horizontal: false, vertical: true)
                    if let p = model.profile {
                        Text("\(p.chip) · \(p.memory) · \(p.macOSVersion)")
                            .font(DS.Font.body).foregroundStyle(.secondary)
                        HStack(spacing: DS.Spacing.sm) {
                            metaChip(icon: "barcode", text: p.serialNumber.isEmpty ? "Unknown Serial Number" : p.serialNumber)
                            metaChip(icon: "cpu", text: p.architecture)
                            if !p.modelYear.isEmpty {
                                metaChip(icon: "calendar", text: "\(p.modelYear) Model")
                            }
                        }
                    }
                }
                Spacer(minLength: DS.Spacing.md)
                scoreBadge
            }
        }
    }

    /// 统一的元信息小胶囊，避免旧版三个 Label 直接换行挤在一起。
    private func metaChip(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 10))
            Text(text).font(DS.Font.caption)
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, DS.Spacing.sm)
        .padding(.vertical, 3)
        .background(Capsule().fill(Color.secondary.opacity(0.1)))
    }

    private var scoreBadge: some View {
        VStack(spacing: 2) {
            Text("\(model.report.score)")
                .font(.system(size: 40, weight: .heavy))
                .foregroundStyle(scoreColor)
                .contentTransition(.numericText())
            Text("Overall Score").font(DS.Font.caption).foregroundStyle(.secondary)
        }
    }

    private var scoreColor: Color {
        if !model.report.redFlags.isEmpty || model.report.score < 60 { return .red }
        if model.report.score < 90 { return .orange }
        return .green
    }

    private var deviceSymbol: String {
        let name = model.profile?.marketingName ?? ""
        if name.contains("mini") || name.contains("Mac Pro") || name.contains("Studio") { return "macstudio.fill" }
        if name.contains("iMac") { return "desktopcomputer" }
        if name.contains("Air") { return "macbook" }
        return "macbook"
    }

    // MARK: - 红旗区

    private var redFlagSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Label("Critical Issues · Please Review First", systemImage: "exclamationmark.octagon.fill")
                .font(DS.Font.title).foregroundStyle(.red)
            ForEach(model.report.redFlags) { flag in
                HStack(alignment: .top, spacing: DS.Spacing.sm) {
                    Text(flag.isRedFlagHeadline ?? flag.summary)
                        .font(DS.Font.body)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer()
                }
                .padding(DS.Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: DS.Radius.control).fill(Color.red.opacity(0.1)))
                .overlay(RoundedRectangle(cornerRadius: DS.Radius.control).strokeBorder(Color.red.opacity(0.25)))
            }
        }
    }

    // MARK: - 分类状态一览

    private var categorySummary: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            SectionLabel(text: "System Checks")
            Card {
                ForEach(Array(SidebarItem.autoCategories.enumerated()), id: \.element) { index, item in
                    summaryRow(item)
                    if index < SidebarItem.autoCategories.count - 1 { DS.Divider() }
                }
            }
        }
    }

    private var testSummary: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack {
                SectionLabel(text: "Hardware Tests")
                Spacer()
                Text("\(model.completedTestCount) / \(SidebarItem.interactiveTests.count) Tested")
                    .font(DS.Font.caption).foregroundStyle(.secondary)
            }
            Card {
                ForEach(Array(SidebarItem.interactiveTests.enumerated()), id: \.element) { index, item in
                    summaryRow(item)
                    if index < SidebarItem.interactiveTests.count - 1 { DS.Divider() }
                }
            }
        }
    }

    private func summaryRow(_ item: SidebarItem) -> some View {
        Button {
            model.selection = item
        } label: {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: item.icon).frame(width: 22).foregroundStyle(.tint)
                Text(item.title).font(DS.Font.bodyEmphasis)
                Spacer()
                if let status = model.status(for: item) {
                    Text(model.results(for: item).first?.summary ?? status.label)
                        .font(DS.Font.caption).foregroundStyle(.secondary)
                        .lineLimit(1).truncationMode(.tail).frame(maxWidth: 320, alignment: .trailing)
                    StatusDot(status: status)
                } else {
                    Text(item.isInteractive ? "Not Tested" : "—")
                        .font(DS.Font.caption).foregroundStyle(.tertiary)
                    Image(systemName: "chevron.right").font(.system(size: 10)).foregroundStyle(.tertiary)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - 底部

    private var footer: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            DS.Divider()
            Text("Test Time: \(model.generatedAt.formatted(date: .abbreviated, time: .shortened)) · ToolCheckMacBook v\(model.report.appVersion)")
            Text("Runs completely locally without network connection or data collection. Results are for reference only and do not constitute a warranty.")
        }
        .font(DS.Font.caption).foregroundStyle(.secondary)
        .padding(.top, DS.Spacing.sm)
    }
}
