import SwiftUI

struct RootView: View {
    @StateObject private var model = AppModel()
    @StateObject private var loc = LocalizationManager.shared
    @AppStorage("appTheme") private var themeRawValue = AppTheme.system.rawValue

    private var preferredScheme: ColorScheme? {
        (AppTheme(rawValue: themeRawValue) ?? .system).colorScheme
    }

    var body: some View {
        ZStack {
            NavigationSplitView {
                SidebarView()
            } detail: {
                DetailRouter()
            }
            .disabled(model.fullscreenTest != nil)

            if let test = model.fullscreenTest {
                fullscreenOverlay(test)
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .environmentObject(model)
        .environmentObject(loc)
        .preferredColorScheme(preferredScheme)
        .alert(loc.t("error.title"), isPresented: Binding(
            get: { model.operationError != nil },
            set: { if !$0 { model.operationError = nil } }
        )) {
            Button(loc.t("error.dismiss"), role: .cancel) { model.operationError = nil }
        } message: {
            Text(model.operationError ?? "")
        }
        .animation(.easeInOut(duration: 0.2), value: model.fullscreenTest?.id)
        .task { await model.scanIfNeeded() }
    }

    @ViewBuilder
    private func fullscreenOverlay(_ test: FullscreenTest) -> some View {
        switch test {
        case .keyboard:
            KeyboardCheckView { result in
                model.recordTest(result)
                model.fullscreenTest = nil
            }
        case .screen:
            ScreenCheckView { result in
                model.recordTest(result)
                model.fullscreenTest = nil
            }
        }
    }
}
