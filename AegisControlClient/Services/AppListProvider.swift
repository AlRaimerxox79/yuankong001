import Foundation

enum AppListProvider {
    static func fetchInstalledApps() -> [[String: Any]] {
        var results: [[String: Any]] = []

        guard let workspaceClass = NSClassFromString("LSApplicationWorkspace") as? NSObject.Type else {
            return results
        }
        let defaultSel = NSSelectorFromString("defaultWorkspace")
        guard workspaceClass.responds(to: defaultSel),
              let workspace = workspaceClass.perform(defaultSel)?.takeUnretainedValue() as? NSObject else {
            return results
        }
        let appsSel = NSSelectorFromString("allInstalledApplications")
        guard workspace.responds(to: appsSel),
              let apps = workspace.perform(appsSel)?.takeUnretainedValue() as? [NSObject] else {
            return results
        }

        for app in apps {
            let bundleId = app.value(forKey: "applicationIdentifier") as? String ?? ""
            if bundleId.isEmpty { continue }
            let name = app.value(forKey: "localizedName") as? String ?? bundleId
            let version = app.value(forKey: "shortVersionString") as? String ?? "--"
            let bundleVersion = app.value(forKey: "bundleVersion") as? String ?? "0"
            let appType = app.value(forKey: "applicationType") as? String ?? ""
            let isSystem = appType == "System"

            results.append([
                "name": name,
                "packageName": bundleId,
                "version": version,
                "versionCode": Int(bundleVersion) ?? 0,
                "isSystem": isSystem,
                "enabled": true,
                "firstInstallTime": 0,
                "lastUpdateTime": 0
            ])
        }

        results.sort {
            ($0["name"] as? String ?? "").localizedCaseInsensitiveCompare(($1["name"] as? String ?? "")) == .orderedAscending
        }
        return results
    }
}
