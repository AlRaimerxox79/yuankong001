import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    Image(systemName: "iphone.gen3")
                        .font(.system(size: 56))
                        .foregroundStyle(.blue)

                    Text("Aegis iOS 客户端")
                        .font(.title2.bold())

                    Text("配置 WDA 后可在 Web 控制台远程点击、滑动操控 iPhone。")
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("控制中心 WebSocket")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("ws://IP:9000/ws/client", text: $appState.serverURL)
                            .textFieldStyle(.roundedBorder)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }
                    .padding(.horizontal)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("绑定用户名 (owner)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("与 Web 控制台登录用户名一致", text: $appState.owner)
                            .textFieldStyle(.roundedBorder)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }
                    .padding(.horizontal)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("客户端密钥 (client-token)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        SecureField("与服务端 -client-token 一致", text: $appState.clientToken)
                            .textFieldStyle(.roundedBorder)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }
                    .padding(.horizontal)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("远控模式")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Picker("远控模式", selection: $appState.controlMode) {
                            Text("TrollVNC (iOS≤17)").tag("vnc")
                            Text("WDA (全版本)").tag("wda")
                            Text("仅观看").tag("app")
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding(.horizontal)

                    if appState.controlMode == "wda" {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("WDA 地址（服务端可访问）")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            TextField("http://127.0.0.1:8100", text: $appState.wdaURL)
                                .textFieldStyle(.roundedBorder)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                            Text("详见 ios/WDA_SETUP.md")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal)
                    }

                    if appState.controlMode == "vnc" {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("VNC 直连地址（可选，局域网调试）")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            TextField("192.168.1.x:5901", text: $appState.vncHost)
                                .textFieldStyle(.roundedBorder)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                            Text("留空则使用 TrollVNC 反向连接，Repeater ID = 设备 ID（见 ios/TROLLVNC_SETUP.md）")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal)
                    }

                    HStack {
                        Circle()
                            .fill(appState.isConnected ? Color.green : Color.red)
                            .frame(width: 10, height: 10)
                        Text(appState.connectionStatus)
                            .font(.subheadline)
                    }

                    Button(action: toggleConnection) {
                        Text(appState.isConnected ? "断开连接" : "连接并激活")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(appState.isConnected ? Color.red.opacity(0.85) : Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .padding(.horizontal)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("模式说明")
                            .font(.headline)
                        Text("• VNC：iOS 16 及以下 / 17.0，需 TrollStore + TrollVNC")
                        Text("• WDA：全 iOS 版本，需 Mac + WebDriverAgent")
                        Text("• 仅观看：ReplayKit，不能远程触控")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(10)
                    .padding(.horizontal)
                }
                .padding(.top, 24)
                .padding(.bottom, 40)
            }
            .navigationTitle("Aegis Control")
        }
        .onAppear {
            EmbedConfig.applyIfNeeded(to: appState)
            if EmbedConfig.hasEmbeddedConfig() && !appState.isConnected {
                appState.saveSettings()
                WebSocketClient.shared.connect(urlString: appState.serverURL)
            }
        }
    }

    private func toggleConnection() {
        if appState.isConnected {
            WebSocketClient.shared.disconnect()
        } else {
            appState.saveSettings()
            WebSocketClient.shared.connect(urlString: appState.serverURL)
        }
    }
}
