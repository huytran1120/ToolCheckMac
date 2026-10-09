import SwiftUI
import AppKit

/// 报告导出：把 ReportDocumentView 渲染成 PNG 长图或 PDF，走 NSSavePanel 让用户选择保存位置。
@MainActor
enum ReportExporter {

    enum Format { case png, pdf }

    static func export(profile: DeviceProfile?, report: MacCheckReport, format: Format) {
        let doc = ReportDocumentView(profile: profile, report: report)
        let renderer = ImageRenderer(content: doc)
        renderer.scale = 2.0   // Retina 清晰度

        let base = "MacCheck-Hardware-Report-\(fileTimestamp(report.generatedAt))"

        switch format {
        case .png:
            guard let nsImage = renderer.nsImage,
                  let tiff = nsImage.tiffRepresentation,
                  let rep = NSBitmapImageRep(data: tiff),
                  let data = rep.representation(using: .png, properties: [:]) else { return }
            save(data: data, suggestedName: base + ".png", type: "png")

        case .pdf:
            let pdfData = NSMutableData()
            renderer.render { size, renderInContext in
                var mediaBox = CGRect(origin: .zero, size: size)
                guard let consumer = CGDataConsumer(data: pdfData),
                      let ctx = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else { return }
                ctx.beginPDFPage(nil)
                renderInContext(ctx)
                ctx.endPDFPage()
                ctx.closePDF()
            }
            save(data: pdfData as Data, suggestedName: base + ".pdf", type: "pdf")
        }
    }

    private static func fileTimestamp(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd-HHmm"
        return f.string(from: date)
    }

    private static func save(data: Data, suggestedName: String, type: String) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = suggestedName
        panel.canCreateDirectories = true
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            try? data.write(to: url)
        }
    }
}
