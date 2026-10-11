import SwiftUI

enum AppTheme: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject private var loc: LocalizationManager
    @AppStorage("appTheme") private var themeRawValue = AppTheme.system.rawValue

    private var selectedTheme: Binding<AppTheme> {
        Binding {
            AppTheme(rawValue: themeRawValue) ?? .system
        } set: { newValue in
            themeRawValue = newValue.rawValue
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                CheckHeader(
                    icon: "gearshape.fill",
                    title: loc.t("settings.title"),
                    subtitle: loc.t("settings.subtitle")
                )

                // Language selection card
                Card {
                    HStack(alignment: .top, spacing: DS.Spacing.md) {
                        Image(systemName: "globe")
                            .font(.system(size: 20))
                            .foregroundStyle(.tint)
                            .frame(width: 28)

                        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                            Text(loc.t("settings.language.title")).font(DS.Font.bodyEmphasis)
                            Text(loc.t("settings.language.subtitle"))
                                .font(DS.Font.body)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)

                            Picker("Language", selection: $loc.currentLanguage) {
                                ForEach(AppLanguage.allCases) { lang in
                                    Text(lang.title).tag(lang)
                                }
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()
                            .padding(.top, DS.Spacing.xs)
                        }
                    }
                }

                // Appearance Theme card
                Card {
                    HStack(alignment: .top, spacing: DS.Spacing.md) {
                        Image(systemName: "paintpalette.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(.tint)
                            .frame(width: 28)

                        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                            Text(loc.t("settings.theme.title")).font(DS.Font.bodyEmphasis)
                            Text(loc.t("settings.theme.subtitle"))
                                .font(DS.Font.body)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)

                            Picker("Appearance Theme", selection: selectedTheme) {
                                ForEach(AppTheme.allCases) { theme in
                                    Label(themeTitle(theme), systemImage: theme.icon)
                                        .tag(theme)
                                }
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()
                            .padding(.top, DS.Spacing.xs)
                        }
                    }
                }

                // About card
                Card {
                    HStack(alignment: .top, spacing: DS.Spacing.md) {
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(.tint)
                            .frame(width: 28)

                        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                            Text(loc.t("settings.about.title")).font(DS.Font.bodyEmphasis)
                            Text(loc.t("settings.about.desc"))
                                .font(DS.Font.body)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                            Text("ToolCheckMacBook • 100% Offline • Zero Telemetry")
                                .font(DS.Font.caption)
                                .foregroundStyle(.secondary)
                                .padding(.top, 4)
                        }
                    }
                }
            }
            .padding(DS.Spacing.xl)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .navigationTitle(loc.t("settings.title"))
    }

    private func themeTitle(_ theme: AppTheme) -> String {
        switch theme {
        case .system: return loc.t("settings.theme.system")
        case .light: return loc.t("settings.theme.light")
        case .dark: return loc.t("settings.theme.dark")
        }
    }
}
