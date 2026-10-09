import SwiftUI
import AppKit

/// 详情面板路由：概览 / 硬件规格 / 各检测分类 / 交互测试。
struct DetailRouter: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        switch model.selection ?? .overview {
        case .overview:
            OverviewView()
        case .specs:
            SpecsView()
        case .keyboard:
            FullscreenLaunchPane(item: .keyboard, test: .keyboard,
                icon: "keyboard.fill", title: "Keyboard Test",
                subtitle: "Full-screen key test: keys light up instantly when pressed to detect unresponsive or stuck keys.")
        case .screen:
            FullscreenLaunchPane(item: .screen, test: .screen,
                icon: "display", title: "Display Test",
                subtitle: "Solid colors, grayscale, and checkerboard patterns to check for dead pixels, bright spots, banding, and backlight bleed.")
        case .audio:
            AudioCheckView { model.recordTest($0) }
        case .microphone:
            MicrophoneCheckView { model.recordTest($0) }
        case .camera:
            CameraCheckView { model.recordTest($0) }
        case .touchID:
            TouchIDCheckView { model.recordTest($0) }
        case .trackpad:
            TrackpadCheckView { model.recordTest($0) }
        case .performance:
            PerformanceCheckView { model.recordTest($0) }
        case .diskSpeed:
            DiskSpeedCheckView { model.recordTest($0) }
        case .portsLive:
            PortLiveCheckView { model.recordTest($0) }
        case .aiModels:
            AIModelsView()
        case .history:
            HistoryView()
        case .settings:
            SettingsView()
        default:
            CategoryDetailView(item: model.selection ?? .overview)
        }
    }
}

// MARK: - 硬件规格（基础信息 · 系统 · 购买与保修）

struct SpecsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                if let p = model.profile {
                    basicInfoCard(p)
                    systemCard(p)
                    warrantyCard(p)
                } else {
                    ProgressView("Reading hardware specifications…")
                }
            }
            .padding(DS.Spacing.xl)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .navigationTitle("Hardware Specifications")
    }

    // 基础信息
    private func basicInfoCard(_ p: DeviceProfile) -> some View {
        Card {
            cardHeader(icon: "laptopcomputer", title: "Basic Information")
            KeyValueList {
                KVRow(icon: "macbook", key: "Model", value: p.marketingName)
                KVRow(icon: "barcode", key: "Serial Number", value: p.serialNumber, mono: true, copyable: true)
                KVRow(icon: "tag", key: "Model Identifier", value: p.modelIdentifier, mono: true)
                KVRow(icon: "cpu", key: "Chip", value: p.chip)
                KVRow(icon: "memorychip", key: "Memory", value: p.memory)
                KVRow(icon: "square.stack.3d.up", key: "Architecture", value: p.architecture, last: true)
            }
        }
    }

    // 系统
    private func systemCard(_ p: DeviceProfile) -> some View {
        Card {
            cardHeader(icon: "gearshape", title: "System")
            KeyValueList {
                KVRow(icon: "apple.logo", key: "macOS Version", value: p.macOSVersion, last: true)
            }
        }
    }

    // 购买与保修
    private func warrantyCard(_ p: DeviceProfile) -> some View {
        let lock = model.result(id: "management.activationLock")
        return Card {
            cardHeader(icon: "checkmark.seal", title: "Purchase & Warranty")
            KeyValueList {
                KVRow(icon: "calendar", key: "Model Year", value: p.modelYear.isEmpty ? "Unknown" : p.modelYear)
                KVRow(icon: "clock.arrow.circlepath", key: "Estimated Age", value: ageText(p.modelYear))
                KVRow(icon: "hammer", key: "Production Date", value: p.productionDate)
                KVRow(icon: "lock.shield",
                      key: "Activation Lock",
                      value: lock?.summary ?? "See Security & Lock",
                      valueTint: lock?.status.tint,
                      last: true)
            }

            InlineNotice(icon: "info.circle", tint: .secondary,
                text: "Warranty status and purchase/activation date must be checked via Apple servers. Since this app runs completely offline, click the button below to check on Apple's official website using your serial number.")

            HStack(spacing: DS.Spacing.md) {
                Button {
                    if let url = URL(string: "https://checkcoverage.apple.com/") {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    Label("Check Warranty on Apple.com", systemImage: "safari")
                }
                .buttonStyle(.borderedProminent)

                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(p.serialNumber, forType: .string)
                } label: {
                    Label("Copy Serial Number", systemImage: "doc.on.doc")
                }
                .buttonStyle(.bordered)
                .disabled(p.serialNumber.isEmpty)
            }
        }
    }

    private func cardHeader(icon: String, title: String) -> some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: icon).foregroundStyle(.tint).font(.system(size: 13, weight: .semibold))
            SectionLabel(text: title)
            Spacer()
        }
    }

    private func ageText(_ yearStr: String) -> String {
        guard let year = Int(yearStr) else { return "Unknown" }
        let now = Calendar.current.component(.year, from: Date())
        let age = now - year
        if age <= 0 { return "Current year model (< 1 year)" }
        return "Approx. \(age) years"
    }
}

/// 优雅的键值列表：图标 + 名称在左，值在右，行间发丝分隔。
struct KeyValueList<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View {
        VStack(spacing: 0) { content }
    }
}

struct KVRow: View {
    let icon: String
    let key: String
    let value: String
    var mono: Bool = false
    var copyable: Bool = false
    var valueTint: Color? = nil
    var last: Bool = false

    @State private var copied = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(width: 18)
                Text(key).font(DS.Font.body).foregroundStyle(.secondary)
                Spacer(minLength: DS.Spacing.lg)
                Text(value)
                    .font(mono ? DS.Font.mono : DS.Font.body)
                    .foregroundStyle(valueTint ?? .primary)
                    .multilineTextAlignment(.trailing)
                    .textSelection(.enabled)
                if copyable {
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(value, forType: .string)
                        copied = true
                    } label: {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.borderless)
                    .help("Copy")
                }
            }
            .padding(.vertical, DS.Spacing.sm)
            if !last { DS.Divider() }
        }
    }
}

// MARK: - 通用分类详情（电池 / 安全 / 存储 / 网络 / 接口）

struct CategoryDetailView: View {
    @EnvironmentObject private var model: AppModel
    let item: SidebarItem

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                let results = model.results(for: item)
                if results.isEmpty {
                    if model.isScanning {
                        ProgressView("Testing…")
                    } else {
                        InlineNotice(icon: "minus.circle", tint: .secondary, text: "No data available for this device or unsupported.")
                    }
                } else {
                    ForEach(results) { result in
                        resultCard(result)
                    }
                }
            }
            .padding(DS.Spacing.xl)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .navigationTitle(item.title)
    }

    private func resultCard(_ result: CheckResult) -> some View {
        Card {
            HStack(alignment: .top, spacing: DS.Spacing.md) {
                Image(systemName: result.status.symbolName)
                    .font(.system(size: 20)).foregroundStyle(result.status.tint)
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    HStack(spacing: DS.Spacing.sm) {
                        Text(result.title).font(DS.Font.bodyEmphasis)
                        StatusPill(status: result.status)
                    }
                    Text(result.summary).font(DS.Font.body).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }
            if let headline = result.isRedFlagHeadline {
                Text(headline)
                    .font(DS.Font.body)
                    .padding(DS.Spacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: DS.Radius.control).fill(Color.red.opacity(0.1)))
            }
            if !result.rawDetails.isEmpty {
                DS.Divider()
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    ForEach(result.rawDetails.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                        InfoRow(key: key, value: value, mono: true)
                    }
                }
            }
        }
    }
}

/// 小型状态药丸标签。
struct StatusPill: View {
    let status: CheckStatus
    var body: some View {
        Text(status.label)
            .font(.system(size: 10, weight: .semibold))
            .padding(.horizontal, DS.Spacing.sm)
            .padding(.vertical, 2)
            .background(Capsule().fill(status.tint.opacity(0.15)))
            .foregroundStyle(status.tint)
    }
}

// MARK: - 全屏测试启动面板（键盘 / 屏幕）

struct FullscreenLaunchPane: View {
    @EnvironmentObject private var model: AppModel
    let item: SidebarItem
    let test: FullscreenTest
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                CheckHeader(icon: icon, title: title, subtitle: subtitle)

                if let result = model.result(id: item.resultIDs.first ?? "") {
                    Card {
                        HStack(spacing: DS.Spacing.md) {
                            Image(systemName: result.status.symbolName)
                                .font(.system(size: 20)).foregroundStyle(result.status.tint)
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: DS.Spacing.sm) {
                                    Text("Previous Result").font(DS.Font.bodyEmphasis)
                                    StatusPill(status: result.status)
                                }
                                Text(result.summary).font(DS.Font.body).foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                    }
                }

                Button {
                    model.fullscreenTest = test
                } label: {
                    Label(model.result(id: item.resultIDs.first ?? "") == nil ? "Start Test" : "Retest",
                          systemImage: "play.fill")
                        .frame(minWidth: 160)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                InlineNotice(icon: "info.circle", tint: .secondary,
                    text: "The test will enter full screen. Long press Esc or press Cmd+Q at any time to safely exit.")
            }
            .padding(DS.Spacing.xl)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .navigationTitle(title)
    }
}
