import SwiftUI
import TideKit

@main
struct LittleTideApp: App {
    @State private var model: AppModel
    @Environment(\.scenePhase) private var scenePhase

    init() {
        _model = State(initialValue: AppEnvironment.makeModel())
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .task { await model.loadCatalogIfNeeded() }
                .onOpenURL { model.handle($0) }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { model.refresh(manual: false) }
                }
        }
    }
}

/// Builds the production model, or a deterministic one for UI tests and screenshots.
enum AppEnvironment {
    @MainActor
    static func makeModel() -> AppModel {
        #if DEBUG
        if let demo = DemoConfiguration(arguments: ProcessInfo.processInfo.arguments) {
            return demo.makeModel()
        }
        #endif
        return AppModel(
            repository: SharedContainer.makeRepository(),
            settings: SharedSettings(),
            clock: .system
        )
    }
}
