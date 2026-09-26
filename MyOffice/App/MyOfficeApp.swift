import SwiftUI

@main
struct MyOfficeApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var store = StoreManager()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(appState)
                .environmentObject(store)
                .task {
                    store.start(appState: appState)
                }
        }
    }
}
