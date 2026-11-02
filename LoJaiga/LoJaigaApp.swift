import SwiftUI

@main
struct LoJaigaApp: App {
    @StateObject private var store = TripStore()
    @StateObject private var voice = VoiceCommandEngine.shared
    @Environment(\.scenePhase) private var phase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(voice)
                .preferredColorScheme(.dark)
                .task { wire() }
        }
        .onChange(of: phase) { _, newPhase in
            if newPhase != .active { store.flush() }
        }
    }

    private func wire() {
        let router = CommandRouter(store: store)
        voice.store = store
        voice.onCommand = { index in router.handle(index: index) }
    }
}
