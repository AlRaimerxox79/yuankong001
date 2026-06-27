import UIKit

enum DeviceInfoProvider {
    static func deviceId() -> String {
        let key = "aegis_device_id"
        if let existing = UserDefaults.standard.string(forKey: key) {
            return existing
        }
        let id = UUID().uuidString
        UserDefaults.standard.set(id, forKey: key)
        return id
    }

    static func currentInfo(wdaUrl: String = "") -> ClientInfo {
        let payload = registrationFields(wdaUrl: wdaUrl)
        return ClientInfo(
            id: payload["id"] as? String ?? deviceId(),
            model: payload["model"] as? String ?? UIDevice.current.model,
            osVersion: payload["osVersion"] as? String ?? "",
            battery: payload["battery"] as? Int ?? 0,
            ip: payload["ip"] as? String ?? "",
            status: payload["status"] as? String ?? "online",
            platform: payload["platform"] as? String ?? "ios",
            controlMode: payload["controlMode"] as? String,
            wdaUrl: payload["wdaUrl"] as? String,
            vncHost: payload["vncHost"] as? String,
            vncRepeaterId: payload["vncRepeaterId"] as? String,
            owner: payload["owner"] as? String
        )
    }

    /// 注册/心跳共用字段（与 Go ClientInfo 对齐）
    static func registrationFields(wdaUrl: String = "", localIP: String? = nil) -> [String: Any] {
        UIDevice.current.isBatteryMonitoringEnabled = true
        let battery = Int(UIDevice.current.batteryLevel * 100)
        let deviceId = deviceId()
        var payload: [String: Any] = [
            "id": deviceId,
            "model": UIDevice.current.model + " " + UIDevice.current.name,
            "osVersion": "iOS " + UIDevice.current.systemVersion,
            "battery": battery >= 0 ? battery : 0,
            "ip": localIP ?? "",
            "status": "online",
            "platform": "ios"
        ]

        let mode = resolvedControlMode(explicitWda: wdaUrl)
        if !mode.isEmpty {
            payload["controlMode"] = mode
        }

        let trimmedWda = wdaUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        if mode == "wda", !trimmedWda.isEmpty {
            payload["wdaUrl"] = trimmedWda
        }

        let vncHost = ConfigStore.vncHost.trimmingCharacters(in: .whitespacesAndNewlines)
        if mode == "vnc", !vncHost.isEmpty {
            payload["vncHost"] = vncHost
        }
        if mode == "vnc" {
            payload["vncRepeaterId"] = deviceId
        }

        let owner = ConfigStore.owner.trimmingCharacters(in: .whitespacesAndNewlines)
        if !owner.isEmpty {
            payload["owner"] = owner
        }
        return payload
    }

    private static func resolvedControlMode(explicitWda: String) -> String {
        let configured = ConfigStore.controlMode.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if configured == "vnc" || configured == "wda" || configured == "app" {
            return configured
        }
        let wda = explicitWda.trimmingCharacters(in: .whitespacesAndNewlines)
        if !wda.isEmpty {
            return "wda"
        }
        let vncHost = ConfigStore.vncHost.trimmingCharacters(in: .whitespacesAndNewlines)
        if !vncHost.isEmpty {
            return "vnc"
        }
        return "app"
    }
}
