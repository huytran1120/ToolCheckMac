import SwiftUI
import AppKit

/// Detail panel routing: Overview / Hardware Specs / System Categories / Interactive Tests.
struct DetailRouter: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var loc: LocalizationManager

    var body: some View {
        switch model.selection ?? .overview {
        case .overview:
            OverviewView()
        case .specs:
            SpecsView()
        case .keyboard:
            FullscreenLaunchPane(item: .keyboard, test: .keyboard,
                icon: "keyboard.fill", title: loc.t("test.keyboard.title"),
                subtitle: loc.t("test.keyboard.sub"))
        case .screen:
            FullscreenLaunchPane(item: .screen, test: .screen,
                icon: "display", title: loc.t("test.screen.title"),
                subtitle: loc.t("test.screen.sub"))
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

// MARK: - Hardware Specifications (Basic Info · System · Purchase & Warranty)

struct SpecsView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var loc: LocalizationManager

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                if let p = model.profile {
                    basicInfoCard(p)
                    systemCard(p)
                    warrantyCard(p)
                } else {
                    ProgressView(loc.t("specs.reading"))
                }
            }
            .padding(DS.Spacing.xl)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .navigationTitle(loc.t("specs.title"))
    }

    // Basic Information
    private func basicInfoCard(_ p: DeviceProfile) -> some View {
        Card {
            cardHeader(icon: "laptopcomputer", title: loc.t("specs.basicInfo"))
            KeyValueList {
                KVRow(icon: "macbook", key: loc.t("specs.model"), value: p.marketingName)
                KVRow(icon: "barcode", key: loc.t("specs.serial"), value: p.serialNumber, mono: true, copyable: true)
                KVRow(icon: "tag", key: loc.t("specs.modelIdentifier"), value: p.modelIdentifier, mono: true)
                KVRow(icon: "cpu", key: loc.t("specs.chip"), value: p.chip)
                KVRow(icon: "memorychip", key: loc.t("specs.memory"), value: p.memory)
                KVRow(icon: "square.stack.3d.up", key: loc.t("specs.architecture"), value: p.architecture, last: true)
            }
        }
    }

    // System
    private func systemCard(_ p: DeviceProfile) -> some View {
        Card {
            cardHeader(icon: "gearshape", title: loc.t("specs.system"))
            KeyValueList {
                KVRow(icon: "apple.logo", key: loc.t("specs.macosVersion"), value: p.macOSVersion, last: true)
            }
        }
    }

    // Purchase & Warranty
    private func warrantyCard(_ p: DeviceProfile) -> some View {
        let lock = model.result(id: "management.activationLock")
        return Card {
            cardHeader(icon: "checkmark.seal", title: loc.t("specs.warranty"))
            KeyValueList {
                KVRow(icon: "calendar", key: loc.t("specs.modelYear"), value: p.modelYear.isEmpty ? loc.t("specs.unknown") : p.modelYear)
                KVRow(icon: "clock.arrow.circlepath", key: loc.t("specs.estimatedAge"), value: ageText(p.modelYear))
                KVRow(icon: "hammer", key: loc.t("specs.productionDate"), value: p.productionDate)
                KVRow(icon: "lock.shield",
                      key: loc.t("specs.activationLock"),
                      value: lock?.localizedSummary(in: loc.currentLanguage) ?? loc.t("specs.seeSecurity"),
                      valueTint: lock?.status.tint,
                      last: true)
            }

            InlineNotice(icon: "info.circle", tint: .secondary,
                text: loc.t("specs.warrantyNotice"))

            HStack(spacing: DS.Spacing.md) {
                Button {
                    if let url = URL(string: "https://checkcoverage.apple.com/") {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    Label(loc.t("specs.checkApple"), systemImage: "safari")
                }
                .buttonStyle(.borderedProminent)

                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(p.serialNumber, forType: .string)
                } label: {
                    Label(loc.t("specs.copySerial"), systemImage: "doc.on.doc")
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
        guard let year = Int(yearStr) else { return loc.t("specs.unknown") }
        let now = Calendar.current.component(.year, from: Date())
        let age = now - year
        if age <= 0 { return loc.t("specs.currentYear") }
        return String(format: loc.t("specs.approxYears"), age)
    }
}

/// Clean key-value list: icon + key on the left, value on the right, hairline dividers between rows.
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

// MARK: - General Category Detail (Battery / Security / Storage / Network / Ports)

struct CategoryDetailView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var loc: LocalizationManager
    let item: SidebarItem

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                let results = model.results(for: item)
                if results.isEmpty {
                    if model.isScanning {
                        ProgressView(loc.t("status.scanning"))
                    } else {
                        InlineNotice(icon: "minus.circle", tint: .secondary,
                            text: loc.currentLanguage == .vietnamese ? "Không có dữ liệu hoặc thiết bị không hỗ trợ mục này." : "No data available for this device or unsupported.")
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
        .navigationTitle(item.localizedTitle(in: loc.currentLanguage))
    }

    private func resultCard(_ result: CheckResult) -> some View {
        Card {
            HStack(alignment: .top, spacing: DS.Spacing.md) {
                Image(systemName: result.status.symbolName)
                    .font(.system(size: 20)).foregroundStyle(result.status.tint)
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    HStack(spacing: DS.Spacing.sm) {
                        Text(result.localizedTitle(in: loc.currentLanguage)).font(DS.Font.bodyEmphasis)
                        StatusPill(status: result.status)
                    }
                    Text(result.localizedSummary(in: loc.currentLanguage)).font(DS.Font.body).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }
            if let headline = result.localizedHeadline(in: loc.currentLanguage) {
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

/// Compact status pill badge.
struct StatusPill: View {
    @EnvironmentObject private var loc: LocalizationManager
    let status: CheckStatus
    var body: some View {
        Text(status.localizedLabel(in: loc.currentLanguage))
            .font(.system(size: 10, weight: .semibold))
            .padding(.horizontal, DS.Spacing.sm)
            .padding(.vertical, 2)
            .background(Capsule().fill(status.tint.opacity(0.15)))
            .foregroundStyle(status.tint)
    }
}

// MARK: - Fullscreen Test Launch Pane (Keyboard / Display)

struct FullscreenLaunchPane: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var loc: LocalizationManager
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
                                    Text(loc.t("test.prevResult")).font(DS.Font.bodyEmphasis)
                                    StatusPill(status: result.status)
                                }
                                Text(result.localizedSummary(in: loc.currentLanguage)).font(DS.Font.body).foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                    }
                }

                Button {
                    model.fullscreenTest = test
                } label: {
                    Label(model.result(id: item.resultIDs.first ?? "") == nil ? loc.t("test.start") : loc.t("test.retest"),
                          systemImage: "play.fill")
                        .frame(minWidth: 160)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                InlineNotice(icon: "info.circle", tint: .secondary,
                    text: loc.t("test.fullscreenNotice"))
            }
            .padding(DS.Spacing.xl)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .navigationTitle(title)
    }
}
