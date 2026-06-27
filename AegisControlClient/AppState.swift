import Foundation
import Combine

final class AppState: ObservableObject {
    static let shared = AppState()

    @Published var serverURL: String = UserDefaults.standard.string(forKey: "server_url")
        ?? "ws://192.168.1.100:9000/ws/client"
    @Published var wdaURL: String = UserDefaults.standard.string(forKey: "wda_url") ?? ""
    @Published var controlMode: String = UserDefaults.standard.string(forKey: "aegis_control_mode") ?? "vnc"
    @Published var vncHost: String = UserDefaults.standard.string(forKey: "aegis_vnc_host") ?? ""
    @Published var owner: String = UserDefaults.standard.string(forKey: "aegis_owner") ?? ""
    @Published var clientToken: String = UserDefaults.standard.string(forKey: "aegis_client_token") ?? ""
    @Published var connectionStatus: String = "未连接"
    @Published var isConnected: Bool = false

    func saveSettings() {
        UserDefaults.standard.set(serverURL, forKey: "server_url")
        UserDefaults.standard.set(wdaURL, forKey: "wda_url")
        ConfigStore.setControlMode(controlMode)
        ConfigStore.setVncHost(vncHost)
        ConfigStore.setOwner(owner)
        ConfigStore.setClientToken(clientToken)
    }
}
