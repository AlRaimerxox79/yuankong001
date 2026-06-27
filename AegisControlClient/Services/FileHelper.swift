import Foundation

enum FileHelper {
    private static let maxDownloadBytes = 50 * 1024 * 1024  // 50 MB

    static func documentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }

    // 所有路径操作限定在沙盒 Documents 目录内
    static func resolveDirectory(path: String) -> URL {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed == "/sdcard" || trimmed == "/sdcard/" {
            return documentsDirectory()
        }
        if trimmed.hasPrefix("/") {
            let url = URL(fileURLWithPath: trimmed).standardized
            let base = documentsDirectory().standardized
            if isInsideSandbox(url, base: base) { return url }
            return base
        }
        return documentsDirectory().appendingPathComponent(trimmed).standardized
    }

    /// 严格校验：路径必须等于 base 或以 base+"/" 开头，防止 /Documents_evil 等前缀绕过
    private static func isInsideSandbox(_ url: URL, base: URL) -> Bool {
        let target = url.path
        let basePath = base.path
        return target == basePath || target.hasPrefix(basePath + "/")
    }

    private static func sandboxedFileURL(path: String) throws -> URL {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = documentsDirectory().standardized
        let url: URL
        if trimmed.hasPrefix("/") {
            url = URL(fileURLWithPath: trimmed).standardized
        } else {
            url = base.appendingPathComponent(trimmed).standardized
        }
        guard isInsideSandbox(url, base: base) else {
            throw NSError(domain: "FileHelper", code: 5,
                          userInfo: [NSLocalizedDescriptionKey: "路径超出沙盒范围"])
        }
        return url
    }

    static func listFiles(path: String) -> [String: Any] {
        let target = resolveDirectory(path: path)
        var files: [[String: Any]] = []
        var errorMessage: String?

        var isDir: ObjCBool = false
        if !FileManager.default.fileExists(atPath: target.path, isDirectory: &isDir) {
            errorMessage = "路径不存在: \(target.path)"
        } else if !isDir.boolValue {
            errorMessage = "不是目录: \(target.path)"
        } else if let items = try? FileManager.default.contentsOfDirectory(
            at: target,
            includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) {
            let sorted = items.sorted { a, b in
                let aDir = (try? a.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                let bDir = (try? b.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                if aDir != bDir { return aDir }
                return a.lastPathComponent.localizedCaseInsensitiveCompare(b.lastPathComponent) == .orderedAscending
            }
            for url in sorted {
                let values = try? url.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey])
                files.append([
                    "name": url.lastPathComponent,
                    "isDirectory": values?.isDirectory ?? false,
                    "size": values?.fileSize ?? 0
                ])
            }
        }

        var resp: [String: Any] = ["path": target.path, "files": files]
        if let errorMessage {
            resp["error"] = errorMessage
        }
        return resp
    }

    static func downloadFile(path: String) throws -> [String: Any] {
        let fileURL = try sandboxedFileURL(path: path)
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw NSError(domain: "FileHelper", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "文件不存在"])
        }
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: fileURL.path, isDirectory: &isDir),
              !isDir.boolValue else {
            throw NSError(domain: "FileHelper", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "不是可读文件"])
        }
        let attrs = try FileManager.default.attributesOfItem(atPath: fileURL.path)
        let fileSize = (attrs[.size] as? Int) ?? 0
        guard fileSize <= maxDownloadBytes else {
            throw NSError(domain: "FileHelper", code: 6,
                          userInfo: [NSLocalizedDescriptionKey: "文件过大（>\(maxDownloadBytes / 1024 / 1024) MB）"])
        }
        let data = try Data(contentsOf: fileURL)
        return [
            "filename": fileURL.lastPathComponent,
            "content": data.base64EncodedString(),
            "size": data.count
        ]
    }

    static func uploadFile(path: String, filename: String, base64Content: String) throws -> [String: Any] {
        // filename 不允许含路径分隔符或 ..
        let safeFilename = filename.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !safeFilename.isEmpty,
              !safeFilename.contains("/"),
              !safeFilename.contains("\\"),
              !safeFilename.contains("..") else {
            throw NSError(domain: "FileHelper", code: 7,
                          userInfo: [NSLocalizedDescriptionKey: "非法文件名"])
        }
        guard let data = Data(base64Encoded: base64Content) else {
            throw NSError(domain: "FileHelper", code: 3,
                          userInfo: [NSLocalizedDescriptionKey: "无效的 Base64 内容"])
        }
        let dir = resolveDirectory(path: path)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let fileURL = dir.appendingPathComponent(safeFilename)
        try data.write(to: fileURL, options: .atomic)
        return [
            "status": "success",
            "message": "File uploaded successfully: \(safeFilename)",
            "path": fileURL.path
        ]
    }

    static func deleteFile(path: String) throws -> [String: Any] {
        let fileURL = try sandboxedFileURL(path: path)
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw NSError(domain: "FileHelper", code: 4,
                          userInfo: [NSLocalizedDescriptionKey: "文件不存在"])
        }
        try FileManager.default.removeItem(at: fileURL)
        return ["status": "success", "message": "已删除: \(fileURL.lastPathComponent)"]
    }

    static func mkdir(path: String) throws -> [String: Any] {
        let dir = resolveDirectory(path: path)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return ["status": "success", "message": "目录已创建", "path": dir.path]
    }
}
