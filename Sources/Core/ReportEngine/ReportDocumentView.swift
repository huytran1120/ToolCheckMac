import SwiftUI

/// Layout designed for export (long PNG / PDF). Fixed width, self-contained, non-interactive, suitable for ImageRenderer.
struct ReportDocumentView: View {
    let profile: DeviceProfile?
    let report: MacCheckReport
    var language: AppLanguage = .vietnamese

    private let width: CGFloat = 720

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header
            if !report.redFlags.isEmpty { redFlags }
            resultsTable
            footer
        }
        .padding(32)
        .frame(width: width)
        .background(Color.white)
    }

    var logoImage: NSImage? = nil

    private var resolvedLogo: NSImage? {
        if let logo = logoImage { return logo }
        if let appIcon = NSImage(named: "AppIcon") { return appIcon }
        if let icon = NSApp?.applicationIconImage { return icon }
        return nil
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 14) {
            if let icon = resolvedLogo {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 52, height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                    .shadow(color: Color.black.opacity(0.15), radius: 4, x: 0, y: 2)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(language == .vietnamese ? "Biên Bản Kiểm Định Phần Cứng ToolCheckMacBook" : "ToolCheckMacBook Hardware Report")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.black)
                Text(profile?.marketingName ?? "")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.black)
                if let p = profile {
                    Text("\(p.chip) · \(p.memory) · \(p.macOSVersion)")
                        .font(.system(size: 12)).foregroundStyle(.gray)
                    Text("\(language == .vietnamese ? "Số Sê-ri" : "Serial Number"): \(p.serialNumber) · \(p.modelIdentifier)")
                        .font(.system(size: 11, design: .monospaced)).foregroundStyle(.gray)
                }
            }
            Spacer()
            VStack(spacing: 2) {
                Text("\(report.score)")
                    .font(.system(size: 40, weight: .heavy))
                    .foregroundStyle(scoreColor)
                Text(language == .vietnamese ? "Điểm Tổng Thể" : "Overall Score").font(.system(size: 11)).foregroundStyle(.gray)
            }
        }
    }

    private var scoreColor: Color {
        if !report.redFlags.isEmpty || report.score < 60 { return .red }
        if report.score < 90 { return .orange }
        return .green
    }

    private var redFlags: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(language == .vietnamese ? "⛔ Vấn Đề Nghiêm Trọng · Cần Kiểm Tra Kỹ" : "⛔ Critical Issues").font(.system(size: 14, weight: .bold)).foregroundStyle(.red)
            ForEach(report.redFlags) { flag in
                Text(flag.localizedHeadline(in: language) ?? flag.localizedSummary(in: language))
                    .font(.system(size: 12)).foregroundStyle(.black)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(6)
            }
        }
    }

    private var resultsTable: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(language == .vietnamese ? "Chi Tiết Các Bài Kiểm Tra" : "Test Details").font(.system(size: 14, weight: .bold)).foregroundStyle(.black)
                .padding(.bottom, 8)
            ForEach(report.results) { r in
                HStack(alignment: .top, spacing: 8) {
                    Text(r.status.exportGlyph).font(.system(size: 12))
                    Text(r.localizedTitle(in: language)).font(.system(size: 12, weight: .semibold)).foregroundStyle(.black)
                        .frame(width: 150, alignment: .leading)
                    Text(r.localizedSummary(in: language)).font(.system(size: 12)).foregroundStyle(.gray)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer()
                }
                .padding(.vertical, 6)
                Rectangle().fill(Color.black.opacity(0.06)).frame(height: 1)
            }
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(language == .vietnamese
                 ? "Thời gian kiểm tra: \(report.generatedAt.formatted(date: .abbreviated, time: .shortened)) · ToolCheckMacBook v\(report.appVersion)"
                 : "Test Time: \(report.generatedAt.formatted(date: .abbreviated, time: .shortened)) · ToolCheckMacBook v\(report.appVersion)")
            Text(language == .vietnamese
                 ? "Biên bản được tạo cục bộ trên máy bởi ToolCheckMacBook. Hoàn toàn ngoại tuyến 100%, không tải lên dữ liệu. Dùng cho mục đích tham khảo kỹ thuật."
                 : "This report was generated locally by ToolCheckMacBook. Fully offline, no data uploaded. For reference only; does not constitute a warranty.")
        }
        .font(.system(size: 10)).foregroundStyle(.gray)
    }
}

extension CheckStatus {
    /// Uses text emojis in exported reports (avoids rendering inconsistencies with SF Symbols across environments).
    var exportGlyph: String {
        switch self {
        case .pass: return "✅"
        case .warning: return "⚠️"
        case .redFlag: return "⛔"
        case .skipped: return "⏭️"
        case .unsupported: return "➖"
        }
    }
}
