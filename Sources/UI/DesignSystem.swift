import SwiftUI

/// Design System — following Apple HIG and clean minimalist aesthetics:
/// Neutral background tones, restrained semantic colors, clear typographic hierarchy, consistent corner radius and whitespace.
/// Single global entry point `DS` to eliminate magic numbers across views.
enum DS {

    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 20
        static let xl: CGFloat = 28
    }

    enum Radius {
        static let card: CGFloat = 12
        static let control: CGFloat = 8
        static let pill: CGFloat = 999
    }

    enum Font {
        static let largeTitle = SwiftUI.Font.system(size: 26, weight: .bold)
        static let title = SwiftUI.Font.system(size: 19, weight: .semibold)
        static let section = SwiftUI.Font.system(size: 12, weight: .semibold)   // Section subtitle (all-caps tracked)
        static let body = SwiftUI.Font.system(size: 13)
        static let bodyEmphasis = SwiftUI.Font.system(size: 13, weight: .semibold)
        static let caption = SwiftUI.Font.system(size: 11)
        static let mono = SwiftUI.Font.system(size: 11, design: .monospaced)
    }

    enum Color {
        static let cardBackground = SwiftUI.Color(nsColor: .controlBackgroundColor)
        static let windowBackground = SwiftUI.Color(nsColor: .windowBackgroundColor)
        static let hairline = SwiftUI.Color.primary.opacity(0.08)
        static let secondaryText = SwiftUI.Color.secondary
    }

    /// Hairline divider.
    static func Divider() -> some View {
        Rectangle().fill(Color.hairline).frame(height: 1)
    }
}

// MARK: - Status Semantics (unified SF Symbols + semantic colors)

extension CheckStatus {
    var symbolName: String {
        switch self {
        case .pass: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .redFlag: return "exclamationmark.octagon.fill"
        case .skipped: return "minus.circle"
        case .unsupported: return "minus.circle"
        }
    }

    var tint: Color {
        switch self {
        case .pass: return .green
        case .warning: return .orange
        case .redFlag: return .red
        case .skipped, .unsupported: return .secondary
        }
    }

    var label: String {
        switch self {
        case .pass: return "Normal"
        case .warning: return "Warning"
        case .redFlag: return "Critical"
        case .skipped: return "Skipped"
        case .unsupported: return "Unsupported"
        }
    }
}

// MARK: - Reusable Components

/// Status dot badge (for sidebar and card top-right).
struct StatusDot: View {
    let status: CheckStatus
    var body: some View {
        Image(systemName: status.symbolName)
            .font(.system(size: 13))
            .foregroundStyle(status.tint)
    }
}

/// Header block for interactive test detail pages.
struct CheckHeader: View {
    let icon: String
    let title: String
    let subtitle: String
    var body: some View {
        HStack(alignment: .top, spacing: DS.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 26))
                .foregroundStyle(.tint)
                .frame(width: 40)
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text(title).font(DS.Font.title)
                Text(subtitle).font(DS.Font.body).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// Inline notice banner (permission denied, warnings, etc.).
struct InlineNotice: View {
    let icon: String
    let tint: Color
    let text: String
    var body: some View {
        HStack(alignment: .top, spacing: DS.Spacing.sm) {
            Image(systemName: icon).foregroundStyle(tint)
            Text(text).font(DS.Font.body).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
        .padding(DS.Spacing.md)
        .background(RoundedRectangle(cornerRadius: DS.Radius.control).fill(tint.opacity(0.1)))
    }
}

/// Section subtitle (all-caps tracked).
struct SectionLabel: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(DS.Font.section)
            .tracking(0.6)
            .foregroundStyle(.secondary)
    }
}

/// Key-value information row.
struct InfoRow: View {
    let key: String
    let value: String
    var mono: Bool = false
    var body: some View {
        HStack(alignment: .top) {
            Text(key).font(DS.Font.body).foregroundStyle(.secondary)
            Spacer(minLength: DS.Spacing.lg)
            Text(value).font(mono ? DS.Font.mono : DS.Font.body)
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
        }
    }
}

extension View {
    /// Container for interactive test pages: embeds in ScrollView (centered + titled).
    func checkPane(_ title: String) -> some View {
        ScrollView {
            self
                .frame(maxWidth: 720)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .navigationTitle(title)
    }
}

/// Unified card container.
struct Card<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            content
        }
        .padding(DS.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: DS.Radius.card).fill(DS.Color.cardBackground))
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.card).strokeBorder(DS.Color.hairline))
    }
}
