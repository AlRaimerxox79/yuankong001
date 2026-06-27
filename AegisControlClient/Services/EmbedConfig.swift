import Foundation

enum EmbedConfig {
    private static func embeddedString(_ key: String) -> String {
        guard let value = Bundle.main.infoDictionary?[key] as? String else { return "" }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("$(") { return "" }
        return trimmed
    }

    static var hasEmbeddedServer: Bool {
        embeddedString("AEGIS_EMBED_SERVER_URL").hasPrefix("ws")
    }

    static var hasEmbeddedOwner: Bool {
        !embeddedString("AEGIS_EMBED_USERNAME").isEmpty
    }

    static func hasEmbeddedConfig() -> Bool {
        hasEmbeddedServer && hasEmbeddedOwner
    }

    /// 编译 IPA 时通过 xcodebuild AEGIS_EMBED_* 写入，仅首次激活前生效
    static func applyIfNeeded(to appState: AppState) {
        guard !ConfigStore.isActivated else { return }

        let server = embeddedString("AEGIS_EMBED_SERVER_URL")
        if server.hasPrefix("ws") {
            appState.serverURL = server
        }
        let owner = embeddedString("AEGIS_EMBED_USERNAME")
        if !owner.isEmpty {
            appState.owner = owner
        }
        let token = embeddedString("AEGIS_EMBED_CLIENT_TOKEN")
        if !token.isEmpty {
            appState.clientToken = token
        }
        let wda = embeddedString("AEGIS_EMBED_WDA_URL")
        if !wda.isEmpty {
            appState.wdaURL = wda
        }
        let mode = embeddedString("AEGIS_EMBED_CONTROL_MODE")
        if !mode.isEmpty {
            appState.controlMode = mode.lowercased()
        }
        let vncHost = embeddedString("AEGIS_EMBED_VNC_HOST")
        if !vncHost.isEmpty {
            appState.vncHost = vncHost
        }
        appState.saveSettings()
    }
}
