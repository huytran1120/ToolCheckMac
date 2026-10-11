import Foundation
import SwiftUI

/// Supported interface languages.
public enum AppLanguage: String, CaseIterable, Identifiable, Codable, Sendable {
    case vietnamese = "vi"
    case english = "en"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .vietnamese: return "Tiếng Việt 🇻🇳"
        case .english: return "English 🇬🇧"
        }
    }
}

/// Dynamic in-app localization manager for ToolCheckMacBook.
/// Allows instant switching between Vietnamese and English without restarting the app.
@MainActor
public final class LocalizationManager: ObservableObject {
    public static let shared = LocalizationManager()

    @Published public var currentLanguage: AppLanguage {
        didSet {
            UserDefaults.standard.set(currentLanguage.rawValue, forKey: "appLanguage")
        }
    }

    private init() {
        let saved = UserDefaults.standard.string(forKey: "appLanguage")
        if let saved, let lang = AppLanguage(rawValue: saved) {
            self.currentLanguage = lang
        } else {
            // Default to Vietnamese for local market
            self.currentLanguage = .vietnamese
        }
    }

    /// Primary lookup helper.
    public func t(_ key: String) -> String {
        Self.translate(key: key, language: currentLanguage)
    }

    nonisolated public static func translate(key: String, language: AppLanguage) -> String {
        switch language {
        case .vietnamese:
            return vietnameseStrings[key] ?? englishStrings[key] ?? key
        case .english:
            return englishStrings[key] ?? key
        }
    }

    // MARK: - String Dictionaries

    nonisolated private static let vietnameseStrings: [String: String] = [
        // Navigation / Sidebar
        "nav.overview": "Tổng quan",
        "nav.specs": "Thông số phần cứng",
        "nav.battery": "Pin & Nguồn điện",
        "nav.security": "Bảo mật & MDM / iCloud",
        "nav.storage": "Ổ cứng & NVMe SMART",
        "nav.network": "Mạng & Kết nối",
        "nav.ports": "Cổng kết nối",
        "nav.keyboard": "Kiểm tra Bàn phím",
        "nav.screen": "Kiểm tra Màn hình",
        "nav.audio": "Loa & Tai nghe",
        "nav.microphone": "Kiểm tra Microphone",
        "nav.camera": "Kiểm tra Camera",
        "nav.touchID": "Cảm biến Touch ID",
        "nav.trackpad": "Bàn rê chuột Trackpad",
        "nav.performance": "Hiệu năng CPU & Tản nhiệt",
        "nav.diskSpeed": "Đo tốc độ SSD",
        "nav.portsLive": "Cắm/rút cổng kết nối",
        "nav.aiModels": "Mô hình AI cục bộ",
        "nav.history": "Lịch sử kiểm tra",
        "nav.settings": "Cài đặt",

        // Sections
        "section.systemChecks": "Kiểm tra hệ thống",
        "section.hardwareTests": "Bài test phần cứng",
        "status.scanning": "Đang quét hệ thống…",
        "status.scanComplete": "Quét hệ thống hoàn tất",
        "status.rescan": "Quét lại",

        // Status Labels
        "status.normal": "Bình thường",
        "status.warning": "Cảnh báo",
        "status.critical": "Nguy hiểm (Cờ đỏ)",
        "status.skipped": "Đã bỏ qua",
        "status.unsupported": "Không áp dụng",

        // Overview
        "overview.saveHistory": "Lưu vào lịch sử",
        "overview.exportReport": "Xuất báo cáo",
        "overview.exportPNG": "Xuất ảnh biên bản (PNG)",
        "overview.exportPDF": "Xuất file PDF",
        "overview.overallScore": "Điểm tổng thể",
        "overview.criticalIssues": "Vấn đề nghiêm trọng · Cần kiểm tra ngay",
        "overview.tested": "Đã kiểm tra",
        "overview.notTested": "Chưa test",
        "overview.modelIdentifying": "Đang nhận diện dòng máy…",
        "overview.unknownSerial": "Không rõ số Sê-ri",
        "overview.model": "Dòng máy",
        "overview.footerNotice": "Ứng dụng chạy 100% offline tại máy, không kết nối mạng và không thu thập dữ liệu. Kết quả mang tính tham khảo kỹ thuật.",
        "overview.testTime": "Thời gian kiểm tra:",

        // Settings
        "settings.title": "Cài đặt",
        "settings.subtitle": "Tùy chỉnh ngôn ngữ và giao diện hiển thị của ToolCheckMacBook. Mọi cài đặt được lưu tự động trên máy.",
        "settings.theme.title": "Chủ đề giao diện",
        "settings.theme.subtitle": "Tự động theo giao diện hệ thống macOS, hoặc chọn chế độ Sáng / Tối.",
        "settings.theme.system": "Theo hệ thống",
        "settings.theme.light": "Sáng",
        "settings.theme.dark": "Tối",
        "settings.language.title": "Ngôn ngữ hiển thị (Language)",
        "settings.language.subtitle": "Chuyển đổi giao diện giữa Tiếng Việt và Tiếng Anh tức thì.",
        "settings.about.title": "Thông tin phần mềm",
        "settings.about.desc": "Công cụ kiểm tra phần cứng, chẩn đoán lỗi và thẩm định máy MacBook cũ chạy hoàn toàn offline 100% trên macOS.",
        "settings.about.version": "Phiên bản:",

        // Hardware Specs
        "specs.title": "Thông số phần cứng",
        "specs.reading": "Đang đọc thông số phần cứng…",
        "specs.basicInfo": "Thông tin cơ bản",
        "specs.system": "Hệ thống",
        "specs.warranty": "Mua máy & Bảo hành",
        "specs.model": "Dòng máy",
        "specs.serial": "Số Sê-ri (Serial)",
        "specs.modelIdentifier": "Mã định danh model",
        "specs.chip": "Vi xử lý (Chip)",
        "specs.memory": "Bộ nhớ RAM",
        "specs.architecture": "Kiến trúc CPU",
        "specs.macosVersion": "Phiên bản macOS",
        "specs.modelYear": "Năm sản xuất",
        "specs.estimatedAge": "Tuổi máy ước tính",
        "specs.productionDate": "Thời gian xuất xưởng",
        "specs.activationLock": "Khóa kích hoạt (iCloud)",
        "specs.checkApple": "Tra cứu bảo hành trên Apple.com",
        "specs.checkAppleQuick": "Tra cứu AppleCare",
        "specs.checkAppleCopied": "Đã copy Serial & Mở web",
        "specs.checkAppleHelp": "Click 1 cái là tự copy Serial và mở checkcoverage.apple.com để kiểm tra bảo hành.",
        "specs.checkAppleToast": "Đã copy số Serial vào bộ nhớ tạm (Nhấn Cmd+V để dán vào trang Apple)",
        "specs.copySerial": "Sao chép số Serial",
        "specs.warrantyNotice": "Hạn bảo hành chính hãng AppleCare và ngày kích hoạt máy cần được kiểm tra trực tiếp qua máy chủ của Apple. Vì ứng dụng chạy hoàn toàn offline, hãy bấm nút để tra cứu số Serial trên trang web chính thức của Apple.",
        "specs.seeSecurity": "Xem mục Bảo mật & Khóa",
        "specs.unknown": "Không rõ",
        "specs.currentYear": "Đời mới (< 1 năm)",
        "specs.approxYears": "Khoảng %d năm",

        // History
        "history.title": "Lịch sử kiểm tra",
        "history.emptyTitle": "Chưa có bản ghi nào",
        "history.emptySubtitle": "Bấm \"Lưu vào lịch sử\" trên trang Tổng quan để lưu kết quả test. Bạn có thể đối chiếu qua thời gian để theo dõi độ chai pin, số chu kỳ sạc và hiệu năng.",
        "history.score": "Điểm",
        "history.delete": "Xóa bản ghi này",

        // AI Models
        "ai.title": "Khả năng chạy AI",
        "ai.headerTitle": "Khả năng chạy Mô hình AI Cục bộ",
        "ai.headerSubtitle": "Trong kỷ nguyên AI, khả năng chạy LLM cục bộ phụ thuộc chính vào dung lượng RAM hợp nhất (Unified Memory). Bảng dưới đây đánh giá khả năng chạy các mô hình mã nguồn mở phổ biến.",
        "ai.deviceMemory": "Bộ nhớ RAM",
        "ai.chip": "Vi xử lý",
        "ai.budget": "RAM dành cho AI",
        "ai.sweetSpot": "Cấu hình tối ưu khuyến nghị:",
        "ai.runsSmoothly": "Chạy mượt",
        "ai.runnable": "Chạy được",
        "ai.barelyRunnable": "Vừa đủ",
        "ai.notRecommended": "Không khuyến nghị",

        // Interactive Tests
        "test.start": "Bắt đầu kiểm tra",
        "test.retest": "Kiểm tra lại",
        "test.prevResult": "Kết quả trước đó",
        "test.fullscreenNotice": "Bài test sẽ chuyển sang chế độ toàn màn hình. Nhấn giữ phím Esc hoặc bấm Cmd+Q bất cứ lúc nào để thoát an toàn.",
        "test.keyboard.title": "Kiểm tra Bàn phím",
        "test.keyboard.sub": "Kiểm tra bàn phím toàn màn hình: Các phím sáng đèn tức thì khi bấm giúp phát hiện phím liệt, kẹt hoặc chập.",
        "test.screen.title": "Kiểm tra Màn hình",
        "test.screen.sub": "Hiển thị màu đơn sắc, dải xám và caro để kiểm tra điểm chết, ám ố, sọc màn hình và hở sáng.",
        "test.audio.title": "Loa & Tai nghe",
        "test.audio.sub": "Phát âm thanh riêng biệt cho từng kênh Trái và Phải để kiểm tra độ trong và âm lượng.",
        "test.mic.title": "Kiểm tra Microphone",
        "test.mic.sub": "Hiển thị sóng âm thanh theo thời gian thực khi nói vào mic; không ghi âm hoặc lưu trữ giọng nói.",
        "test.camera.title": "Kiểm tra Camera",
        "test.camera.sub": "Khởi động webcam để kiểm tra độ nét, cảm biến hình ảnh và bụi bẩn ống kính.",
        "test.touchID.title": "Cảm biến Touch ID",
        "test.touchID.sub": "Xác thực sinh trắc học vân tay để xác nhận cảm biến hoạt động bình thường.",
        "test.trackpad.title": "Bàn rê chuột Trackpad",
        "test.trackpad.sub": "Kiểm tra vùng cảm ứng, thao tác đa ngón tay và cảm biến lực nhấn Force Touch.",
        "test.performance.title": "Hiệu năng CPU & Tản nhiệt",
        "test.performance.sub": "Chạy tải nặng đa nhân CPU để kiểm tra độ ổn định nhiệt độ và quạt tản nhiệt.",
        "test.diskSpeed.title": "Đo tốc độ ổ cứng SSD",
        "test.diskSpeed.sub": "Đo tốc độ đọc và ghi tuần tự thực tế của ổ cứng qua cơ chế Direct I/O bỏ qua bộ đệm RAM.",
        "test.portsLive.title": "Cắm/rút cổng USB & Thunderbolt",
        "test.portsLive.sub": "Nhận diện tức thì sự kiện cắm và rút thiết bị ngoại vi vào từng cổng vật lý.",

        // Interactive Test Controls & Feedback
        "test.result": "Kết quả kiểm tra:",
        "test.stop": "Dừng",
        "test.saveResult": "Lưu kết quả",
        "test.skip": "Bỏ qua bài test này",

        // Audio Test
        "test.audio.left": "Phát loa Trái",
        "test.audio.right": "Phát loa Phải",
        "test.audio.pass": "Cả hai kênh bình thường",
        "test.audio.fail": "Phát hiện kênh loa bất thường",

        // Camera Test
        "test.camera.permission": "Quyền truy cập Camera bị từ chối. Vui lòng cho phép ToolCheckMacBook trong \"Cài đặt hệ thống › Quyền riêng tư & Bảo mật › Camera\".",
        "test.camera.pass": "Rõ nét & Bình thường",
        "test.camera.fail": "Phát hiện hình ảnh bất thường",

        // Microphone Test
        "test.mic.listening": "Đang lắng nghe…",
        "test.mic.unable": "Không thể bắt đầu nghe",
        "test.mic.permission": "Quyền Microphone bị từ chối. Vui lòng cấp quyền cho ToolCheckMacBook trong \"Cài đặt hệ thống › Quyền riêng tư & Bảo mật › Microphone\".",
        "test.mic.openSettings": "Mở Cài đặt Microphone",
        "test.mic.retry": "Thử lại",
        "test.mic.pass": "Mức âm thanh phản hồi tốt",
        "test.mic.fail": "Không phản hồi / Bất thường",

        // Disk Speed Test
        "test.diskSpeed.write": "Ghi tuần tự",
        "test.diskSpeed.read": "Đọc tuần tự",
        "test.diskSpeed.start": "Bắt đầu đo tốc độ",
        "test.diskSpeed.retest": "Đo lại tốc độ",
        "test.diskSpeed.writing": "Đang ghi",
        "test.diskSpeed.reading": "Đang đọc",

        // Performance Test
        "test.perf.progress": "Tiến độ",
        "test.perf.throughput": "Tốc độ xử lý",
        "test.perf.thermal": "Trạng thái nhiệt độ",
        "test.perf.socTemp": "Nhiệt độ chip SoC",
        "test.perf.fan": "Tốc độ quạt",
        "test.perf.peakTemp": "Nhiệt độ đỉnh",
        "test.perf.start": "Bắt đầu test tải nặng",
        "test.perf.retest": "Test lại tải nặng",
        "test.perf.stressTesting": "Đang chạy tải nặng %ds…",
        "test.perf.coolingGood": "Hiệu quả tản nhiệt hoạt động tốt.",
        "test.perf.coolingWarn": "Đã đạt ngưỡng nhiệt độ cao; cần lưu ý kiểm tra keo tản nhiệt hoặc quạt gió.",
        "test.perf.peakNotice": "Trạng thái nhiệt độ đỉnh: %@. %@",

        // Touch ID Test
        "test.touchID.prompt": "Bấm nút bên dưới để xác thực với dấu vân tay đã đăng ký.",
        "test.touchID.unsupported": "Máy Mac này không hỗ trợ Touch ID, hoặc chưa đăng ký dấu vân tay nào.",
        "test.touchID.start": "Bắt đầu xác thực vân tay",
        "test.touchID.placeFinger": "Đặt ngón tay lên cảm biến Touch ID…",
        "test.touchID.cancelled": "Đã hủy, bạn có thể thử lại.",
        "test.touchID.failed": "Xác thực không thành công, bạn có thể thử lại hoặc bỏ qua.",

        // Trackpad Test
        "test.trackpad.hint": "Rê ngón tay trong vùng này",
        "test.trackpad.pressure": "Lực nhấn",
        "test.trackpad.forceTouch": "Cảm ứng lực",
        "test.trackpad.gestures": "Cử chỉ đa điểm",
        "test.trackpad.triggered": "Đã nhận",
        "test.trackpad.notTriggered": "Chưa nhận",
        "test.trackpad.clear": "Xóa nét vẽ",
        "test.trackpad.pass": "Rê chuột, cử chỉ & Force Touch bình thường",
        "test.trackpad.fail": "Phát hiện điểm bất thường",

        // Port Live Test
        "test.portsLive.monitoring": "Đang theo dõi, vui lòng cắm thiết bị…",
        "test.portsLive.notStarted": "Chưa bắt đầu",
        "test.portsLive.captured": "Đã ghi nhận %d lần cắm",
        "test.portsLive.noEvents": "Chưa có sự kiện cắm/rút cổng nào",
        "test.portsLive.connected": "Đã cắm",
        "test.portsLive.disconnected": "Đã rút",
        "test.portsLive.start": "Bắt đầu theo dõi cổng",
        "test.portsLive.stop": "Dừng theo dõi",
        "test.portsLive.clear": "Xóa nhật ký",
        "test.portsLive.pass": "Tất cả các cổng nhận bình thường",
        "test.portsLive.fail": "Phát hiện cổng không nhận",

        // Screen Test
        "test.screen.hint": "Màn hình %d / %d · Bấm chuột hoặc Space để chuyển · Bấm F báo lỗi · Esc để thoát",
        "test.screen.flag": "Báo lỗi tại đây",
        "test.screen.next": "Tiếp tục",
        "test.screen.finish": "Hoàn tất kiểm tra",
        "test.screen.black": "Màu Đen — Kiểm tra điểm sáng, hở sáng viền màn hình",
        "test.screen.white": "Màu Trắng — Kiểm tra điểm chết, đốm đen, ố vàng",
        "test.screen.red": "Màu Đỏ — Kiểm tra điểm ảnh phụ (subpixel)",
        "test.screen.green": "Màu Xanh lá — Kiểm tra subpixel xanh lá",
        "test.screen.blue": "Màu Xanh dương — Kiểm tra subpixel xanh dương",
        "test.screen.gradient": "Dải xám chuyển sắc — Kiểm tra dải màu & bóng ma",
        "test.screen.checkerboard": "Bàn cờ caro — Kiểm tra lưu ảnh, độ đồng đều",

        // Keyboard Test
        "test.keyboard.hint": "Bấm lần lượt từng phím trên bàn phím; phím sẽ sáng đèn khi được nhận diện. Giữ phím Esc 1.2 giây để thoát bất cứ lúc nào.",
        "test.keyboard.testedCount": "%d / %d phím đã bấm",
        "test.keyboard.finish": "Hoàn tất & Lưu kết quả",
        "test.keyboard.allPass": "Tất cả các phím hoạt động bình thường ✅"
    ]

    nonisolated private static let englishStrings: [String: String] = [
        // Navigation / Sidebar
        "nav.overview": "Overview",
        "nav.specs": "Hardware Specifications",
        "nav.battery": "Battery",
        "nav.security": "Security & Lock",
        "nav.storage": "Storage",
        "nav.network": "Network",
        "nav.ports": "Ports",
        "nav.keyboard": "Keyboard",
        "nav.screen": "Display",
        "nav.audio": "Speaker / Headphones",
        "nav.microphone": "Microphone",
        "nav.camera": "Camera",
        "nav.touchID": "Touch ID",
        "nav.trackpad": "Trackpad",
        "nav.performance": "Performance Test",
        "nav.diskSpeed": "Disk Speed Test",
        "nav.portsLive": "Port Live Test",
        "nav.aiModels": "AI Models",
        "nav.history": "History",
        "nav.settings": "Settings",

        // Sections
        "section.systemChecks": "System Checks",
        "section.hardwareTests": "Hardware Tests",
        "status.scanning": "Scanning…",
        "status.scanComplete": "System scan complete",
        "status.rescan": "Rescan",

        // Status Labels
        "status.normal": "Normal",
        "status.warning": "Warning",
        "status.critical": "Critical",
        "status.skipped": "Skipped",
        "status.unsupported": "Unsupported",

        // Overview
        "overview.saveHistory": "Save to History",
        "overview.exportReport": "Export Report",
        "overview.exportPNG": "Export as Image (PNG)",
        "overview.exportPDF": "Export as PDF",
        "overview.overallScore": "Overall Score",
        "overview.criticalIssues": "Critical Issues · Please Review First",
        "overview.tested": "Tested",
        "overview.notTested": "Not Tested",
        "overview.modelIdentifying": "Identifying model…",
        "overview.unknownSerial": "Unknown Serial Number",
        "overview.model": "Model",
        "overview.footerNotice": "Runs completely locally without network connection or data collection. Results are for reference only and do not constitute a warranty.",
        "overview.testTime": "Test Time:",

        // Settings
        "settings.title": "Settings",
        "settings.subtitle": "Adjust ToolCheckMacBook display preferences. Settings are saved locally.",
        "settings.theme.title": "Appearance Theme",
        "settings.theme.subtitle": "Follow system appearance, or select light or dark mode.",
        "settings.theme.system": "System",
        "settings.theme.light": "Light",
        "settings.theme.dark": "Dark",
        "settings.language.title": "Display Language",
        "settings.language.subtitle": "Switch app interface between Vietnamese and English instantly.",
        "settings.about.title": "About ToolCheckMacBook",
        "settings.about.desc": "All-in-one native macOS hardware diagnostic, inspection, and verification tool running 100% offline.",
        "settings.about.version": "Version:",

        // Hardware Specs
        "specs.title": "Hardware Specifications",
        "specs.reading": "Reading hardware specifications…",
        "specs.basicInfo": "Basic Information",
        "specs.system": "System",
        "specs.warranty": "Purchase & Warranty",
        "specs.model": "Model",
        "specs.serial": "Serial Number",
        "specs.modelIdentifier": "Model Identifier",
        "specs.chip": "Chip",
        "specs.memory": "Memory",
        "specs.architecture": "Architecture",
        "specs.macosVersion": "macOS Version",
        "specs.modelYear": "Model Year",
        "specs.estimatedAge": "Estimated Age",
        "specs.productionDate": "Production Date",
        "specs.activationLock": "Activation Lock",
        "specs.checkApple": "Check Warranty on Apple.com",
        "specs.checkAppleQuick": "Check AppleCare",
        "specs.checkAppleCopied": "Copied Serial & Opened",
        "specs.checkAppleHelp": "1-Click to automatically copy Serial number and open checkcoverage.apple.com in your browser.",
        "specs.checkAppleToast": "Copied Serial number to clipboard (Press Cmd+V on Apple page)",
        "specs.copySerial": "Copy Serial Number",
        "specs.warrantyNotice": "Warranty status and purchase/activation date must be checked via Apple servers. Since this app runs completely offline, click the button below to check on Apple's official website using your serial number.",
        "specs.seeSecurity": "See Security & Lock",
        "specs.unknown": "Unknown",
        "specs.currentYear": "Current year model (< 1 year)",
        "specs.approxYears": "Approx. %d years",

        // History
        "history.title": "History",
        "history.emptyTitle": "No Saved Snapshots Yet",
        "history.emptySubtitle": "Click \"Save to History\" on the Overview page to save this test. Future tests can be compared against it to track battery cycles, health, and score changes.",
        "history.score": "Score",
        "history.delete": "Delete this snapshot",

        // AI Models
        "ai.title": "AI Models",
        "ai.headerTitle": "AI Model Feasibility",
        "ai.headerSubtitle": "In the AI era, running local LLMs depends primarily on memory. Below is an estimate of mainstream open-source models based on device memory to help gauge AI capabilities.",
        "ai.deviceMemory": "Device Memory",
        "ai.chip": "Chip",
        "ai.budget": "Model Memory Budget",
        "ai.sweetSpot": "Recommended Sweet Spot:",
        "ai.runsSmoothly": "Runs Smoothly",
        "ai.runnable": "Runnable",
        "ai.barelyRunnable": "Barely Runnable",
        "ai.notRecommended": "Not Recommended",

        // Interactive Tests
        "test.start": "Start Test",
        "test.retest": "Retest",
        "test.prevResult": "Previous Result",
        "test.fullscreenNotice": "The test will enter full screen. Long press Esc or press Cmd+Q at any time to safely exit.",
        "test.keyboard.title": "Keyboard Test",
        "test.keyboard.sub": "Full-screen key test: keys light up instantly when pressed to detect unresponsive or stuck keys.",
        "test.screen.title": "Display Test",
        "test.screen.sub": "Solid colors, grayscale, and checkerboard patterns to check for dead pixels, bright spots, banding, and backlight bleed.",
        "test.audio.title": "Speaker / Headphone Test",
        "test.audio.sub": "Play left and right channels separately to confirm clear sound from both sides. Plug in headphones to verify headphone jack.",
        "test.mic.title": "Microphone Test",
        "test.mic.sub": "Live input level visualizer to verify microphone sensitivity without recording or saving audio.",
        "test.camera.title": "Camera Test",
        "test.camera.sub": "Live camera preview to verify webcam sensor clarity and spot lens defects.",
        "test.touchID.title": "Touch ID Test",
        "test.touchID.sub": "Prompts biometric authentication via LocalAuthentication to confirm sensor functionality.",
        "test.trackpad.title": "Trackpad Test",
        "test.trackpad.sub": "Canvas drawing with gesture recognition and Force Touch pressure gauge.",
        "test.performance.title": "Performance Test",
        "test.performance.sub": "Multi-core CPU stress benchmark monitoring real-time thermal throttling states.",
        "test.diskSpeed.title": "Disk Speed Test",
        "test.diskSpeed.sub": "Sequential read and write benchmark bypassing OS cache via Direct I/O.",
        "test.portsLive.title": "Port Live Test",
        "test.portsLive.sub": "Real-time USB device tree differential detection to verify physical ports.",

        // Interactive Test Controls & Feedback
        "test.result": "Test Result:",
        "test.stop": "Stop",
        "test.saveResult": "Save Result",
        "test.skip": "Skip Test",

        // Audio Test
        "test.audio.left": "Play Left Channel",
        "test.audio.right": "Play Right Channel",
        "test.audio.pass": "Both Channels Normal",
        "test.audio.fail": "Channel Issue Detected",

        // Camera Test
        "test.camera.permission": "Camera permission denied. Please allow ToolCheckMacBook in \"System Settings › Privacy & Security › Camera\".",
        "test.camera.pass": "Clear & Normal",
        "test.camera.fail": "Image Anomaly Detected",

        // Microphone Test
        "test.mic.listening": "Listening…",
        "test.mic.unable": "Unable to start listening",
        "test.mic.permission": "Microphone permission denied. Please allow ToolCheckMacBook in \"System Settings › Privacy & Security › Microphone\".",
        "test.mic.openSettings": "Open Microphone Settings",
        "test.mic.retry": "Retry Check",
        "test.mic.pass": "Level Responding Normally",
        "test.mic.fail": "No Response / Abnormal",

        // Disk Speed Test
        "test.diskSpeed.write": "Sequential Write",
        "test.diskSpeed.read": "Sequential Read",
        "test.diskSpeed.start": "Start Speed Test",
        "test.diskSpeed.retest": "Retest Speed",
        "test.diskSpeed.writing": "Writing",
        "test.diskSpeed.reading": "Reading",

        // Performance Test
        "test.perf.progress": "Progress",
        "test.perf.throughput": "Throughput",
        "test.perf.thermal": "Current Thermal State",
        "test.perf.socTemp": "SoC Temperature",
        "test.perf.fan": "Fan Speed",
        "test.perf.peakTemp": "Peak Temperature",
        "test.perf.start": "Start Stress Test",
        "test.perf.retest": "Retest Stress",
        "test.perf.stressTesting": "Stress testing %ds…",
        "test.perf.coolingGood": "Cooling performance is good.",
        "test.perf.coolingWarn": "Reached serious thermal state or above; monitor cooling performance.",
        "test.perf.peakNotice": "Peak thermal state: %@. %@",

        // Touch ID Test
        "test.touchID.prompt": "Click the button below to verify with an enrolled fingerprint.",
        "test.touchID.unsupported": "This Mac does not support Touch ID, or no fingerprints are enrolled.",
        "test.touchID.start": "Start Fingerprint Verification",
        "test.touchID.placeFinger": "Place your finger on Touch ID…",
        "test.touchID.cancelled": "Cancelled, you may try again.",
        "test.touchID.failed": "Recognition failed, you may retry or skip.",

        // Trackpad Test
        "test.trackpad.hint": "Move finger in this area",
        "test.trackpad.pressure": "Pressure",
        "test.trackpad.forceTouch": "Force Touch",
        "test.trackpad.gestures": "Multi-touch Gestures",
        "test.trackpad.triggered": "Triggered",
        "test.trackpad.notTriggered": "Not Triggered",
        "test.trackpad.clear": "Clear",
        "test.trackpad.pass": "Tracking, Gestures & Force Touch Normal",
        "test.trackpad.fail": "Anomaly Detected",

        // Port Live Test
        "test.portsLive.monitoring": "Monitoring, please insert a device…",
        "test.portsLive.notStarted": "Not Started",
        "test.portsLive.captured": "Captured %d insertion(s)",
        "test.portsLive.noEvents": "No plug/unplug events yet",
        "test.portsLive.connected": "Connected",
        "test.portsLive.disconnected": "Disconnected",
        "test.portsLive.start": "Start Monitoring",
        "test.portsLive.stop": "Stop Monitoring",
        "test.portsLive.clear": "Clear Log",
        "test.portsLive.pass": "All Ports Recognized Normally",
        "test.portsLive.fail": "Unresponsive Port Detected",

        // Screen Test
        "test.screen.hint": "Screen %d of %d · Click or press Space for next · Press F to flag anomaly · Esc to exit",
        "test.screen.flag": "Flag Anomaly",
        "test.screen.next": "Next",
        "test.screen.finish": "Complete Test",
        "test.screen.black": "Solid Black — Check for bright spots/backlight bleed",
        "test.screen.white": "Solid White — Check for dead/dark spots",
        "test.screen.red": "Solid Red — Check for defective subpixels",
        "test.screen.green": "Solid Green — Check for defective subpixels",
        "test.screen.blue": "Solid Blue — Check for defective subpixels",
        "test.screen.gradient": "Grayscale Gradient — Check for banding/color gradation",
        "test.screen.checkerboard": "Checkerboard — Check for image retention/uniformity",

        // Keyboard Test
        "test.keyboard.hint": "Press each key in sequence; keys light up when tested. Hold Esc for 1.2s to exit at any time.",
        "test.keyboard.testedCount": "%d / %d Tested",
        "test.keyboard.finish": "Finish & Save Result",
        "test.keyboard.allPass": "All keys tested successfully ✅"
    ]
}

// MARK: - Extension for CheckResult and CheckStatus Localization

extension CheckStatus {
    public func localizedLabel(in language: AppLanguage) -> String {
        switch language {
        case .vietnamese:
            switch self {
            case .pass: return "Bình thường"
            case .warning: return "Cảnh báo"
            case .redFlag: return "Nguy hiểm"
            case .skipped: return "Đã bỏ qua"
            case .unsupported: return "Không áp dụng"
            }
        case .english:
            return self.label
        }
    }
}

extension SidebarItem {
    public func localizedTitle(in language: AppLanguage) -> String {
        LocalizationManager.translate(key: "nav.\(self.rawValue)", language: language)
    }
}

extension CheckResult {
    /// Returns localized title for display.
    public func localizedTitle(in language: AppLanguage) -> String {
        guard language == .vietnamese else { return title }
        switch id {
        case "hardware.serial": return "Đối soát số Sê-ri"
        case "hardware.securityChip": return "Chip bảo mật"
        case "management.mdm": return "Quản lý từ xa MDM"
        case "management.appleID": return "Đăng nhập Apple ID"
        case "management.activationLock": return "Khóa kích hoạt Find My / iCloud"
        case "battery.cycleCount": return "Chu kỳ sạc pin"
        case "battery.health": return "Sức khỏe pin"
        case "storage": return "Sức khỏe ổ cứng NVMe SMART"
        case "network.wifi": return "Card mạng Wi-Fi"
        case "network.bluetooth": return "Bộ điều khiển Bluetooth"
        case "ports": return "Cổng USB & Thunderbolt"
        case "keyboard": return "Kiểm tra bàn phím"
        case "screen": return "Kiểm tra màn hình"
        case "audio": return "Loa & Tai nghe"
        case "microphone": return "Kiểm tra Microphone"
        case "camera": return "Kiểm tra Camera"
        case "touchID": return "Cảm biến Touch ID"
        case "trackpad": return "Bàn rê Trackpad"
        case "performance": return "Hiệu năng & Tản nhiệt"
        case "diskSpeed": return "Tốc độ đọc/ghi SSD"
        case "portsLive": return "Cắm/rút cổng kết nối"
        default: return title
        }
    }

    /// Returns localized summary text.
    public func localizedSummary(in language: AppLanguage) -> String {
        guard language == .vietnamese else { return summary }
        switch id {
        case "hardware.serial":
            if status == .redFlag {
                return "Số sê-ri từ IOKit và system_profiler không khớp; có dấu hiệu làm giả danh tính máy!"
            } else if status == .warning {
                return "Không đọc được số sê-ri; có thể là máy ảo hoặc môi trường bị hạn chế."
            } else {
                return "Số sê-ri trùng khớp qua các phương thức đọc; hãy tra cứu bảo hành trên trang Apple."
            }

        case "hardware.securityChip":
            if summary.contains("Apple Silicon") {
                return "Apple Silicon (Tích hợp sẵn Secure Enclave) — Khóa kích hoạt gắn trực tiếp với chip M-series."
            } else if summary.contains("T2") {
                return "Mac Intel có chip bảo mật T2 — Hỗ trợ khóa kích hoạt Activation Lock."
            } else {
                return "Mac Intel đời cũ (Không có chip T2) — Không hỗ trợ khóa kích hoạt iCloud."
            }

        case "management.mdm":
            if status == .redFlag {
                return "Máy dính quản lý từ xa MDM (Mobile Device Management) của công ty/doanh nghiệp"
            } else if status == .warning {
                return "Phát hiện bản ghi Apple DEP; cài lại macOS có thể bị khóa quản lý tự động"
            } else {
                return "Không phát hiện hồ sơ quản lý MDM, máy sạch an tâm mua"
            }

        case "management.appleID":
            if status == .warning {
                return "Tài khoản Apple ID vẫn đang đăng nhập; hãy yêu cầu người bán đăng xuất trước khi mua"
            } else {
                return "Không có tài khoản Apple ID nào đăng nhập trên máy"
            }

        case "management.activationLock":
            if status == .redFlag {
                return "Khóa kích hoạt Activation Lock (Find My Mac) đang BẬT ngầm"
            } else {
                return "Khóa kích hoạt đã tắt, máy sạch sẵn sàng sử dụng"
            }

        case "battery.cycleCount":
            return summary.replacingOccurrences(of: "Cycle Count:", with: "Số chu kỳ sạc:")
                .replacingOccurrences(of: "Max Capacity:", with: "Dung lượng tối đa:")

        case "battery.health":
            return summary.replacingOccurrences(of: "Battery Health:", with: "Sức khỏe pin:")
                .replacingOccurrences(of: "Design Capacity:", with: "Dung lượng thiết kế:")
                .replacingOccurrences(of: "Condition:", with: "Tình trạng:")

        case "storage":
            return summary.replacingOccurrences(of: "SMART Verified", with: "Chuẩn SMART Verified (Bình thường)")
                .replacingOccurrences(of: "SMART Failing", with: "CẢNH BÁO: Ổ cứng sắp hỏng (SMART Failing)")

        case "network.wifi":
            return summary.replacingOccurrences(of: "Connected to", with: "Đã kết nối")
                .replacingOccurrences(of: "Wi-Fi interface active", with: "Card Wi-Fi hoạt động bình thường")

        case "network.bluetooth":
            return summary.replacingOccurrences(of: "Bluetooth controller active", with: "Bộ điều khiển Bluetooth hoạt động bình thường")

        case "ports":
            return summary.replacingOccurrences(of: "Thunderbolt buses detected", with: "bus Thunderbolt được phát hiện")
                .replacingOccurrences(of: "USB buses detected", with: "bus USB được phát hiện")

        case "diskSpeed":
            return summary.replacingOccurrences(of: "Write", with: "Ghi")
                .replacingOccurrences(of: "Read", with: "Đọc")
                .replacingOccurrences(of: "Normal read/write speeds", with: "Tốc độ đọc/ghi bình thường")
                .replacingOccurrences(of: "Low speed, possible external slow drive or disk anomaly", with: "Tốc độ thấp, có thể là ổ ngoài chậm hoặc ổ có vấn đề")

        case "performance":
            return summary.replacingOccurrences(of: "CPU Stress Test passed", with: "Đã vượt qua bài kiểm tra chịu tải CPU")
                .replacingOccurrences(of: "Thermal state:", with: "Nhiệt độ:")
                .replacingOccurrences(of: "Nominal", with: "Mát mẻ (Nominal)")
                .replacingOccurrences(of: "Fair", with: "Ấm (Fair)")
                .replacingOccurrences(of: "Serious", with: "Nóng (Serious)")
                .replacingOccurrences(of: "Critical", with: "Rất nóng (Critical)")

        case "keyboard":
            return summary.replacingOccurrences(of: "keys tested", with: "phím đã bấm kiểm tra")
                .replacingOccurrences(of: "all normal", with: "hoạt động bình thường")
                .replacingOccurrences(of: "unresponsive keys detected", with: "phím không phản hồi")

        case "screen":
            return summary.replacingOccurrences(of: "Display test completed", with: "Đã hoàn thành kiểm tra màn hình")
                .replacingOccurrences(of: "user confirmed no dead pixels or discoloration", with: "không phát hiện điểm chết hay ám ố")

        case "audio":
            return summary.replacingOccurrences(of: "Both left and right channels play normally", with: "Cả hai kênh loa trái và phải phát âm thanh bình thường")
                .replacingOccurrences(of: "Audio channel anomaly reported", with: "Phát hiện âm thanh bất thường ở loa hoặc tai nghe")

        case "microphone":
            return summary.replacingOccurrences(of: "Microphone test passed", with: "Microphone thu âm tốt, độ nhạy đạt chuẩn")
                .replacingOccurrences(of: "Microphone input detected", with: "Đã phát hiện tín hiệu âm thanh vào micro")

        case "camera":
            return summary.replacingOccurrences(of: "Camera preview is clear with no defects or abnormalities", with: "Hình ảnh webcam rõ nét, không lỗi cảm biến hay điểm chết")
                .replacingOccurrences(of: "Camera display anomaly reported", with: "Phát hiện hình ảnh webcam bị lỗi hoặc bất thường")

        case "touchID":
            return summary.replacingOccurrences(of: "Touch ID verification succeeded", with: "Xác thực cảm biến vân tay Touch ID thành công")
                .replacingOccurrences(of: "Sensor working normally", with: "Cảm biến hoạt động bình thường")

        case "trackpad":
            return summary.replacingOccurrences(of: "Trackpad gestures and Force Touch verified", with: "Đã xác nhận cảm ứng đa điểm và lực nhấn Force Touch bình thường")

        case "portsLive":
            return summary.replacingOccurrences(of: "USB port plug/unplug events verified", with: "Đã xác nhận sự kiện cắm/rút thiết bị vào các cổng USB")

        default:
            return summary
        }
    }

    /// Returns localized red flag headline banner text.
    public func localizedHeadline(in language: AppLanguage) -> String? {
        guard let headline = isRedFlagHeadline else { return nil }
        guard language == .vietnamese else { return headline }

        switch id {
        case "management.mdm":
            if status == .redFlag {
                return "⛔ Máy này đang nằm trong hệ thống quản lý từ xa MDM của công ty hoặc trường học. Tổ chức có thể khóa máy hoặc xóa dữ liệu từ xa bất cứ lúc nào, cài lại macOS cũng KHÔNG THỂ XÓA ĐƯỢC (đặc biệt là dạng DEP tự động). TUYỆT ĐỐI KHÔNG NÊN MUA trừ khi người bán cung cấp bằng chứng đã gỡ bỏ hoàn toàn khỏi tổ chức!"
            } else {
                return "⚠️ Thiết bị này có hồ sơ đăng ký Apple DEP của doanh nghiệp. Cài lại macOS qua mạng có thể tự động khóa quản lý trở lại. Yêu cầu người bán gỡ thiết bị khỏi DEP trước khi giao dịch!"
            }

        case "management.activationLock":
            return "⛔ Khóa kích hoạt Activation Lock (Find My Mac) đang được BẬT trên máy này. Nếu người bán không thể đăng xuất và tắt trực tiếp bằng mật khẩu Apple ID ngay tại chỗ, máy có nguy cơ bị khóa vĩnh viễn thành 'cục gạch'. TUYỆT ĐỐI KHÔNG THANH TOÁN!"

        case "management.appleID":
            return "⚠️ Một tài khoản Apple ID vẫn đang đăng nhập trên máy này. Nếu đây không phải tài khoản của bạn, người bán chưa đăng xuất. Yêu cầu người bán đăng xuất hoàn toàn tại Cài đặt hệ thống > Tài khoản trước khi giao dịch!"

        case "hardware.serial":
            return "⛔ Số sê-ri đọc từ IOKit và system_profiler không trùng khớp nhau! Dữ liệu nhận dạng phần cứng có thể đã bị can thiệp hoặc làm giả số sê-ri. Không nên dựa vào máy này để giao dịch; hãy kiểm tra lại trên trang web chính thức của Apple."

        default:
            return headline
        }
    }
}
