import Foundation
import UIKit

final class WebSocketClient: NSObject {
    static let shared = WebSocketClient()

    private var webSocketTask: URLSessionWebSocketTask?
    private var session: URLSession!
    private let commandHandler = CommandHandler()
    private var receiveLoopRunning = false
    private let sendQueue = DispatchQueue(label: "aegis.ws.send", qos: .userInitiated)
    private var heartbeatTimer: DispatchSourceTimer?
    private var reconnectTimer: DispatchWorkItem?
    private var reconnectAttempts = 0
    private var intentionalDisconnect = false

    private override init() {
        super.init()
        session = URLSession(configuration: .default, delegate: self, delegateQueue: OperationQueue())
        UIDevice.current.isBatteryMonitoringEnabled = true
    }

    func connect(urlString: String) {
        intentionalDisconnect = false
        reconnectAttempts = 0
        connectInternal(urlString: urlString)
    }

    private func connectInternal(urlString: String) {
        disconnectInternal(stopReconnect: false)
        guard let url = URL(string: urlString) else { return }
        webSocketTask = session.webSocketTask(with: url)
        webSocketTask?.resume()
        receiveLoopRunning = true
        listen()
    }

    func disconnect() {
        intentionalDisconnect = true
        reconnectAttempts = 0
        reconnectTimer?.cancel()
        reconnectTimer = nil
        disconnectInternal(stopReconnect: true)
    }

    private func disconnectInternal(stopReconnect: Bool) {
        stopHeartbeat()
        receiveLoopRunning = false
        ScreenCaptureService.shared.stop()
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        if stopReconnect {
            reconnectTimer?.cancel()
            reconnectTimer = nil
        }
        DispatchQueue.main.async {
            AppState.shared.isConnected = false
            AppState.shared.connectionStatus = "未连接"
        }
    }

    // MARK: - Send（串行队列，防并发乱序）

    func sendEnvelope(type: String, encodable: Encodable) {
        guard let data = try? JSONEncoder().encode(AnyEncodable(encodable)),
              let payloadString = String(data: data, encoding: .utf8) else { return }
        sendRaw(type: type, payloadString: payloadString)
    }

    func sendEnvelope(type: String, jsonObject: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: jsonObject),
              let payloadString = String(data: data, encoding: .utf8) else { return }
        sendRaw(type: type, payloadString: payloadString)
    }

    func sendError(_ message: String) {
        sendEnvelope(type: "error", encodable: ErrorPayload(message: message))
    }

    private func sendRaw(type: String, payloadString: String) {
        let envelope = MessageEnvelope(type: type, targetId: nil, clientId: nil, payload: payloadString)
        guard let data = try? JSONEncoder().encode(envelope),
              let text = String(data: data, encoding: .utf8) else { return }
        let task = webSocketTask
        sendQueue.async {
            task?.send(.string(text)) { error in
                if let error = error {
                    print("[WebSocket] send error: \(error)")
                }
            }
        }
    }

    // MARK: - Init payload（在 didOpen 后发送）

    private func sendInit() {
        var payload = DeviceInfoProvider.registrationFields(
            wdaUrl: AppState.shared.wdaURL,
            localIP: localIPAddress()
        )
        let token = ConfigStore.clientToken.trimmingCharacters(in: .whitespacesAndNewlines)
        if !token.isEmpty { payload["clientToken"] = token }
        sendEnvelope(type: "init", jsonObject: payload)
    }

    // MARK: - Heartbeat

    private func startHeartbeat() {
        stopHeartbeat()
        let timer = DispatchSource.makeTimerSource(queue: sendQueue)
        timer.schedule(deadline: .now() + 60, repeating: 60)
        timer.setEventHandler { [weak self] in
            guard let self = self, self.webSocketTask != nil else { return }
            var info = DeviceInfoProvider.registrationFields(
                wdaUrl: AppState.shared.wdaURL,
                localIP: self.localIPAddress()
            )
            self.sendEnvelope(type: "device_info", jsonObject: info)
        }
        timer.resume()
        heartbeatTimer = timer
    }

    private func stopHeartbeat() {
        heartbeatTimer?.cancel()
        heartbeatTimer = nil
    }

    // MARK: - Receive loop

    private func listen() {
        guard receiveLoopRunning, let task = webSocketTask else { return }
        task.receive { [weak self] result in
            guard let self = self, self.receiveLoopRunning else { return }
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    self.handleMessage(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        self.handleMessage(text)
                    }
                @unknown default:
                    break
                }
                self.listen()
            case .failure(let error):
                print("[WebSocket] receive error: \(error)")
                self.receiveLoopRunning = false
                self.stopHeartbeat()
                ScreenCaptureService.shared.stop()
                DispatchQueue.main.async {
                    AppState.shared.isConnected = false
                    AppState.shared.connectionStatus = "连接断开，正在重连…"
                }
                self.scheduleReconnect()
            }
        }
    }

    private func handleMessage(_ text: String) {
        guard let data = text.data(using: .utf8),
              let envelope = try? JSONDecoder().decode(MessageEnvelope.self, from: data) else { return }
        commandHandler.handle(type: envelope.type, payloadJSON: envelope.payload, client: self)
    }

    // MARK: - Auto reconnect

    private func scheduleReconnect() {
        guard !intentionalDisconnect else { return }
        let urlString = AppState.shared.serverURL
        guard !urlString.isEmpty else { return }
        reconnectAttempts += 1
        guard reconnectAttempts <= 12 else {
            DispatchQueue.main.async {
                AppState.shared.connectionStatus = "无法连接服务器"
            }
            return
        }
        let delay = min(Double(reconnectAttempts) * 3.0, 30.0)
        let work = DispatchWorkItem { [weak self] in
            guard let self = self, !self.intentionalDisconnect else { return }
            self.connectInternal(urlString: urlString)
        }
        reconnectTimer = work
        DispatchQueue.global().asyncAfter(deadline: .now() + delay, execute: work)
    }

    // MARK: - Helpers

    private func localIPAddress() -> String? {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else { return nil }
        defer { freeifaddrs(firstAddr) }
        var ptr = firstAddr
        while true {
            let iface = ptr.pointee
            let family = iface.ifa_addr.pointee.sa_family
            if family == UInt8(AF_INET) {
                let name = String(cString: iface.ifa_name)
                if name == "en0" || name == "en1" {
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    if getnameinfo(iface.ifa_addr, socklen_t(iface.ifa_addr.pointee.sa_len),
                                   &hostname, socklen_t(hostname.count),
                                   nil, 0, NI_NUMERICHOST) == 0 {
                        address = String(cString: hostname)
                    }
                }
            }
            guard let next = iface.ifa_next else { break }
            ptr = next
        }
        return address
    }
}

// MARK: - URLSessionWebSocketDelegate

extension WebSocketClient: URLSessionWebSocketDelegate {
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask,
                    didOpenWithProtocol protocol: String?) {
        reconnectAttempts = 0
        DispatchQueue.main.async {
            ConfigStore.setActivated(true)
            AppState.shared.isConnected = true
            AppState.shared.connectionStatus = "已连接服务器"
        }
        // 连接成功后发 init 并启动心跳
        sendInit()
        startHeartbeat()
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask,
                    didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        receiveLoopRunning = false
        stopHeartbeat()
        ScreenCaptureService.shared.stop()
        DispatchQueue.main.async {
            AppState.shared.isConnected = false
            AppState.shared.connectionStatus = "连接已关闭"
        }
        scheduleReconnect()
    }
}

// MARK: - AnyEncodable

private struct AnyEncodable: Encodable {
    private let encodeFunc: (Encoder) throws -> Void
    init(_ value: Encodable) { encodeFunc = value.encode }
    func encode(to encoder: Encoder) throws { try encodeFunc(encoder) }
}
