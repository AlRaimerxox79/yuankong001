import Foundation

enum ConfigURLHandler {
    static func apply(url: URL, to appState: AppState) -> Bool {
        guard url.scheme?.lowercased() == "aegis" else { return false }
        let host = (url.host ?? "").lowercased()
        let path = url.path.lowercased()
        guard host == "activate" || path.hasPrefix("/aegis/activate") else { return false }

        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return false
        }
        let items = components.queryItems ?? []
        func value(_ name: String) -> String? {
            items.first(where: { $0.name == name })?.value?.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let server = value("server") ?? value("url")
        if let server, server.hasPrefix("ws") {
            appState.serverURL = server
        }
        if let user = value("user") ?? value("username") {
            appState.owner = user
        }
        if let token = value("token") ?? value("clientToken") {
            appState.clientToken = token
        }
        if let wda = value("wda") ?? value("wdaUrl") {
            appState.wdaURL = wda
            appState.controlMode = "wda"
        }
        if let mode = value("controlMode") ?? value("mode") {
            appState.controlMode = mode.lowercased()
        }
        if let vncHost = value("vncHost") ?? value("vnc") {
            appState.vncHost = vncHost
            if appState.controlMode.isEmpty {
                appState.controlMode = "vnc"
            }
        }
        appState.saveSettings()
        return true
    }
}
