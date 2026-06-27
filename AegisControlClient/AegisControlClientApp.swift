import SwiftUI

@main
struct AegisControlClientApp: App {
    @StateObject private var appState = AppState.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .onOpenURL { url in
                    if ConfigURLHandler.apply(url: url, to: appState) {
                        appState.connectionStatus = "已通过链接写入配置"
                    }
                }
        }
    }
}