import SwiftUI
import AppKit

/// Report export: Renders ReportDocumentView into PNG or PDF via NSSavePanel.
@MainActor
enum ReportExporter {

    enum Format { case png, pdf }

    static func export(profile: DeviceProfile?, report: MacCheckReport, format: Format) {
        let doc = ReportDocumentView(profile: profile, report: report)
        let renderer = ImageRenderer(content: doc)
        renderer.scale = 2.0   // Retina sharpness

        let base = "ToolCheckMacBook-Hardware-Report-\(fileTimestamp(report.generatedAt))"

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
