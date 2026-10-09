import SwiftUI

/// Layout designed for export (long PNG / PDF). Fixed width, self-contained, non-interactive, suitable for ImageRenderer.
struct ReportDocumentView: View {
    let profile: DeviceProfile?
    let report: MacCheckReport

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

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("ToolCheckMacBook Hardware Report")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.black)
                Text(profile?.marketingName ?? "")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.black)
                if let p = profile {
                    Text("\(p.chip) · \(p.memory) · \(p.macOSVersion)")
                        .font(.system(size: 12)).foregroundStyle(.gray)
                    Text("Serial Number: \(p.serialNumber) · \(p.modelIdentifier)")
                        .font(.system(size: 11, design: .monospaced)).foregroundStyle(.gray)
                }
            }
            Spacer()
            VStack(spacing: 2) {
                Text("\(report.score)")
                    .font(.system(size: 40, weight: .heavy))
                    .foregroundStyle(scoreColor)
                Text("Overall Score").font(.system(size: 11)).foregroundStyle(.gray)
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
            Text("⛔ Critical Issues").font(.system(size: 14, weight: .bold)).foregroundStyle(.red)
            ForEach(report.redFlags) { flag in
                Text(flag.isRedFlagHeadline ?? flag.summary)
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
            Text("Test Details").font(.system(size: 14, weight: .bold)).foregroundStyle(.black)
                .padding(.bottom, 8)
            ForEach(report.results) { r in
                HStack(alignment: .top, spacing: 8) {
                    Text(r.status.exportGlyph).font(.system(size: 12))
                    Text(r.title).font(.system(size: 12, weight: .semibold)).foregroundStyle(.black)
                        .frame(width: 140, alignment: .leading)
                    Text(r.summary).font(.system(size: 12)).foregroundStyle(.gray)
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
            Text("Test Time: \(report.generatedAt.formatted(date: .abbreviated, time: .shortened)) · ToolCheckMacBook v\(report.appVersion)")
            Text("This report was generated locally by ToolCheckMacBook. Fully offline, no data uploaded. For reference only; does not constitute a warranty.")
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
