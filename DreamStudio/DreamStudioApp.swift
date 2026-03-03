import SwiftUI
import ComposableArchitecture
import OpenClawCore

@main
struct DreamStudioApp: App {
    init() {
        KeychainHelper.service = "com.openclaw.dreamstudio"
    }

    static let store = Store(initialState: GenerationFeature.State()) {
        GenerationFeature()
    }

    var body: some Scene {
        WindowGroup {
            ContentView(store: DreamStudioApp.store)
        }
    }
}
