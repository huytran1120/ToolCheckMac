import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// Report export: Renders ReportDocumentView into PNG or PDF via NSSavePanel.
@MainActor
enum ReportExporter {

    enum Format { case png, pdf }

    enum ExportError: LocalizedError {
        case renderingFailed, invalidDestination

        var errorDescription: String? {
            switch self {
            case .renderingFailed: return "Unable to render a valid report."
            case .invalidDestination: return "No valid report destination was selected."
            }
        }
    }

    static func export(
        profile: DeviceProfile?, report: MacCheckReport, format: Format,
        language: AppLanguage = .vietnamese, onError: @escaping (Error) -> Void
    ) {
        do {
            let data = try render(profile: profile, report: report, format: format, language: language)
            let base = "ToolCheckMacBook-Hardware-Report-\(fileTimestamp(report.generatedAt))"
            save(data: data, suggestedName: base, format: format, onError: onError)
        } catch {
            onError(error)
        }
    }

    static func render(profile: DeviceProfile?, report: MacCheckReport, format: Format, language: AppLanguage = .vietnamese) throws -> Data {
        let doc = ReportDocumentView(profile: profile, report: report, language: language)
        let renderer = ImageRenderer(content: doc)
        renderer.scale = 2.0   // Retina sharpness

        switch format {
        case .png:
            guard let nsImage = renderer.nsImage,
                  let tiff = nsImage.tiffRepresentation,
                  let rep = NSBitmapImageRep(data: tiff),
                  let data = rep.representation(using: .png, properties: [:]) else { throw ExportError.renderingFailed }
            return data

        case .pdf:
            let pdfData = NSMutableData()
            var rendered = false
            renderer.render { size, renderInContext in
                var mediaBox = CGRect(origin: .zero, size: size)
                guard let consumer = CGDataConsumer(data: pdfData),
                      let ctx = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else { return }
                ctx.beginPDFPage(nil)
                renderInContext(ctx)
                ctx.endPDFPage()
                ctx.closePDF()
                rendered = true
            }
            guard rendered, pdfData.length > 0 else { throw ExportError.renderingFailed }
            return pdfData as Data
        }
    }

    private static func fileTimestamp(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd-HHmm"
        return f.string(from: date)
    }

    static func write(_ data: Data, to url: URL) throws {
        guard !data.isEmpty else { throw ExportError.renderingFailed }
        try data.write(to: url, options: .atomic)
    }

    private static func save(data: Data, suggestedName: String, format: Format, onError: @escaping (Error) -> Void) {
        let panel = NSSavePanel()
        let type: UTType = format == .png ? .png : .pdf
        panel.nameFieldStringValue = suggestedName + (format == .png ? ".png" : ".pdf")
        panel.allowedContentTypes = [type]
        panel.canCreateDirectories = true
        panel.begin { response in
            guard response == .OK else { return }
            guard let url = panel.url else {
                onError(ExportError.invalidDestination)
                return
            }
            do {
                try write(data, to: url)
            } catch {
                onError(error)
            }
        }
    }
}
