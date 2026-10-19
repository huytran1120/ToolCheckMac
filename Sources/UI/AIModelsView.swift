import SwiftUI
import AppKit

/// AI Model Feasibility Advisor: evaluates which mainstream models can be run locally based on device memory.
struct AIModelsView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var loc: LocalizationManager

    private var ramGB: Double {
        guard let mem = model.profile?.memory else { return 0 }
        let digits = mem.filter { $0.isNumber }
        return Double(digits) ?? 0
    }
    private var appleSilicon: Bool {
        model.profile?.architecture.contains("Apple Silicon") ?? false
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                CheckHeader(
                    icon: "sparkles",
                    title: loc.t("ai.headerTitle"),
                    subtitle: loc.t("ai.headerSubtitle")
                )

                if ramGB <= 0 {
                    InlineNotice(icon: "hourglass", tint: .secondary,
                                 text: loc.currentLanguage == .vietnamese ? "Đang đọc thông số bộ nhớ RAM…" : "Reading memory information…")
                } else {
                    summaryCard
                    if !appleSilicon { intelNotice }
                    modelListCard
                    referencesCard
                    disclaimer
                }
            }
            .padding(DS.Spacing.xl)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .navigationTitle(loc.t("ai.title"))
    }

    private var summaryCard: some View {
        Card {
            HStack(spacing: DS.Spacing.xl) {
                stat(loc.t("ai.deviceMemory"), String(format: "%.0f GB", ramGB))
                stat(loc.t("ai.chip"), model.profile?.chip ?? "—")
                stat(loc.t("ai.budget"), String(format: "≈ %.0f GB", AIModelAdvisor.budgetGB(ramGB: ramGB)))
            }
            if let sweet = AIModelAdvisor.sweetSpot(ramGB: ramGB) {
                DS.Divider()
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: "star.fill").foregroundStyle(.orange)
                    Text(loc.t("ai.sweetSpot")).font(DS.Font.bodyEmphasis)
                    Text(loc.currentLanguage == .vietnamese
                         ? "\(sweet.name) (khoảng \(Int(sweet.footprintGB)) GB, lượng tử hóa Q4) chạy mượt mà trên máy"
                         : "\(sweet.name) (approx. \(Int(sweet.footprintGB)) GB, Q4 quantized) runs smoothly locally")
                        .font(DS.Font.body).foregroundStyle(.secondary)
                }
            }
        }
    }

    private var intelNotice: some View {
        InlineNotice(icon: "exclamationmark.triangle.fill", tint: .orange,
            text: loc.currentLanguage == .vietnamese
                ? "Máy Mac này chạy chip Intel, không có bộ nhớ Unified Memory hoặc GPU đồ họa chuyên dụng tốc độ cao. Tốc độ sinh chữ của mô hình AI sẽ chậm hơn đáng kể. Khuyến nghị chỉ thử nghiệm các mô hình dưới 8B."
                : "This Mac has an Intel processor without unified memory or a high-performance GPU. Local model inference will be noticeably slower. Testing models under 8B is recommended.")
    }

    private var modelListCard: some View {
        Card {
            SectionLabel(text: loc.currentLanguage == .vietnamese ? "Đánh giá các mô hình phổ biến (Lượng tử hóa Q4)" : "Mainstream Model Evaluation (Q4 Quantization)")
            ForEach(Array(AIModelAdvisor.suggestions(ramGB: ramGB).enumerated()), id: \.element.id) { index, s in
                HStack(spacing: DS.Spacing.md) {
                    Text(s.name).font(DS.Font.body).frame(maxWidth: .infinity, alignment: .leading)
                    Text("≈ \(Int(s.footprintGB)) GB").font(DS.Font.caption).foregroundStyle(.secondary)
                        .frame(width: 80, alignment: .trailing)
                    verdictBadge(s.verdict)
                }
                .padding(.vertical, DS.Spacing.xs)
                if index < AIModelAdvisor.catalog.count - 1 { DS.Divider() }
            }
        }
    }

    private func verdictBadge(_ v: AIVerdict) -> some View {
        let tint: Color = {
            switch v {
            case .smooth: return .green
            case .runnable: return .blue
            case .tight: return .orange
            case .no: return .secondary
            }
        }()
        return Text(v.localizedLabel(in: loc.currentLanguage))
            .font(.system(size: 11, weight: .semibold))
            .padding(.horizontal, DS.Spacing.sm)
            .padding(.vertical, 3)
            .background(Capsule().fill(tint.opacity(0.15)))
            .foregroundStyle(tint)
    }

    private var referencesCard: some View {
        Card {
            SectionLabel(text: loc.currentLanguage == .vietnamese ? "Tài liệu tham khảo & Tiêu chuẩn hiệu năng" : "Authoritative Resources & Benchmarks")
            ForEach(Array(AIModelAdvisor.references.enumerated()), id: \.offset) { index, ref in
                Button {
                    if let url = URL(string: ref.url) { NSWorkspace.shared.open(url) }
                } label: {
                    HStack(spacing: DS.Spacing.md) {
                        Image(systemName: "arrow.up.forward.square.fill").foregroundStyle(.tint)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(ref.title).font(DS.Font.bodyEmphasis).foregroundStyle(.primary)
                            Text(ref.subtitle).font(DS.Font.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").font(.system(size: 11)).foregroundStyle(.tertiary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.vertical, DS.Spacing.xs)
                if index < AIModelAdvisor.references.count - 1 { DS.Divider() }
            }
        }
    }

    private var disclaimer: some View {
        Text(loc.currentLanguage == .vietnamese
             ? "Lưu ý: Các ước tính trên mang tính tương đối dựa trên lượng tử hóa Q4. Hiệu năng thực tế còn phụ thuộc vào ngữ cảnh context window và các tác vụ khác đang chạy."
             : "Note: The above estimates are conservative based on Q4 quantization. Actual performance also depends on quantization level, context window length, and concurrent workloads. Very large models (e.g. 400B+) require server-grade hardware.")
            .font(DS.Font.caption).foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(DS.Font.caption).foregroundStyle(.secondary)
            Text(value).font(.system(size: 16, weight: .semibold))
        }
    }
}
