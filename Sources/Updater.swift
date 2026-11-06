import Cocoa

/// "1.2.0" / "v1.2.0" 形式的版本号，按数字逐段比较，缺的段按 0 处理。
struct AppVersion: Comparable, CustomStringConvertible {
    let parts: [Int]

    init?(_ text: String) {
        var value = text.trimmingCharacters(in: .whitespaces)
        if value.hasPrefix("v") || value.hasPrefix("V") { value.removeFirst() }
        let numbers = value.split(separator: ".", omittingEmptySubsequences: false).map { Int($0) }
        guard !numbers.isEmpty, numbers.allSatisfy({ $0 != nil }) else { return nil }
        parts = numbers.compactMap { $0 }
    }

    static var current: AppVersion {
        let text = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
        return AppVersion(text) ?? AppVersion("0")!
    }

    var description: String { parts.map(String.init).joined(separator: ".") }

    static func < (lhs: AppVersion, rhs: AppVersion) -> Bool {
        for index in 0..<max(lhs.parts.count, rhs.parts.count) {
            let left = index < lhs.parts.count ? lhs.parts[index] : 0
            let right = index < rhs.parts.count ? rhs.parts[index] : 0
            if left != right { return left < right }
        }
        return false
    }

    static func == (lhs: AppVersion, rhs: AppVersion) -> Bool {
        !(lhs < rhs) && !(rhs < lhs)
    }
}

/// GitHub 上一个带版本号的正式发布。
struct ReleaseInfo {
    let version: AppVersion
    let pageURL: URL
    let dmgURL: URL
}

enum UpdateError: LocalizedError {
    case message(String)

    var errorDescription: String? {
        switch self {
        case .message(let text): return text
        }
    }
}

/// 查询 GitHub 发布列表，找出版本号最高的正式发布。
/// 只认 v1.2.0 这类标签；网站下载用的 latest 标签不带版本号，会被忽略。
enum ReleaseChecker {
    static let repo = "pudongkai/voice-input"
    static let assetName = "VoiceInput.dmg"

    static func fetchNewest(completion: @escaping (Result<ReleaseInfo?, Error>) -> Void) {
        var request = URLRequest(url: URL(string: "https://api.github.com/repos/\(repo)/releases?per_page=30")!)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("VoiceInput/\(AppVersion.current)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 20

        URLSession.shared.dataTask(with: request) { data, response, error in
            let result: Result<ReleaseInfo?, Error>
            if let error {
                result = .failure(error)
            } else if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                result = .failure(UpdateError.message("GitHub 返回 \(http.statusCode)"))
            } else {
                result = Result { try newest(in: data ?? Data()) }
            }
            DispatchQueue.main.async { completion(result) }
        }.resume()
    }

    private struct Release: Decodable {
        let tag_name: String
        let html_url: URL
        let draft: Bool
        let prerelease: Bool
        let assets: [Asset]
    }

    private struct Asset: Decodable {
        let name: String
        let browser_download_url: URL
    }

    static func newest(in data: Data) throws -> ReleaseInfo? {
        let releases = try JSONDecoder().decode([Release].self, from: data)
        return releases.compactMap { release -> ReleaseInfo? in
            guard !release.draft, !release.prerelease,
                  let version = AppVersion(release.tag_name),
                  let asset = release.assets.first(where: { $0.name == assetName }) else { return nil }
            return ReleaseInfo(version: version, pageURL: release.html_url, dmgURL: asset.browser_download_url)
        }
        .max { $0.version < $1.version }
    }
}

/// 下载安装包并报告进度。
final class UpdateDownloader: NSObject, URLSessionDownloadDelegate {
    private let destination: URL
    private var session: URLSession?
    private var onProgress: ((Double) -> Void)?
    private var onFinish: ((Result<URL, Error>) -> Void)?

    init(destination: URL) {
        self.destination = destination
    }

    func start(_ url: URL, progress: @escaping (Double) -> Void, finish: @escaping (Result<URL, Error>) -> Void) {
        onProgress = progress
        onFinish = finish
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: .main)
        self.session = session
        session.downloadTask(with: url).resume()
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64,
                    totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard totalBytesExpectedToWrite > 0 else { return }
        onProgress?(Double(totalBytesWritten) / Double(totalBytesExpectedToWrite))
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        if let http = downloadTask.response as? HTTPURLResponse, http.statusCode != 200 {
            finish(.failure(UpdateError.message("下载失败：服务器返回 \(http.statusCode)")))
            return
        }
        // location 在这个方法返回后就会被系统删除，必须在这里移走。
        do {
            let fileManager = FileManager.default
            try fileManager.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? fileManager.removeItem(at: destination)
            try fileManager.moveItem(at: location, to: destination)
            finish(.success(destination))
        } catch {
            finish(.failure(error))
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error { finish(.failure(error)) }
    }

    private func finish(_ result: Result<URL, Error>) {
        guard let callback = onFinish else { return }
        onFinish = nil
        onProgress = nil
        session?.finishTasksAndInvalidate()
        session = nil
        callback(result)
    }
}

/// 把下载好的安装包换到当前 App 的位置，再重新打开。
enum UpdateInstaller {
    /// 只替换「应用程序」文件夹里的 App；从 build 目录等位置运行时不自动替换，避免覆盖开发目录。
    static var canReplaceInPlace: Bool {
        let app = Bundle.main.bundleURL
        let parent = app.deletingLastPathComponent().path
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        guard parent == "/Applications" || parent == home + "/Applications" else { return false }
        return FileManager.default.isWritableFile(atPath: parent)
            && FileManager.default.isWritableFile(atPath: app.path)
    }

    /// 挂载安装包、检查里面的 App，再复制到安装包旁边的 staged 目录，返回复制出来的 App。
    static func stage(dmg: URL, expected: AppVersion,
                      bundleID: String = Bundle.main.bundleIdentifier ?? "") throws -> URL {
        let fileManager = FileManager.default
        let work = dmg.deletingLastPathComponent()
        let mount = work.appendingPathComponent("mount")
        let staged = work.appendingPathComponent("staged/VoiceInput.app")
        try? fileManager.removeItem(at: staged.deletingLastPathComponent())
        try fileManager.createDirectory(at: mount, withIntermediateDirectories: true)

        try run("/usr/bin/hdiutil", ["attach", dmg.path, "-nobrowse", "-readonly", "-noautoopen", "-mountpoint", mount.path])
        defer { _ = try? run("/usr/bin/hdiutil", ["detach", mount.path, "-force"]) }

        let app = try findApp(in: mount)
        try verify(app, expected: expected, bundleID: bundleID)
        try fileManager.createDirectory(at: staged.deletingLastPathComponent(), withIntermediateDirectories: true)
        try run("/usr/bin/ditto", [app.path, staged.path])
        _ = try? run("/usr/bin/xattr", ["-dr", "com.apple.quarantine", staged.path])
        return staged
    }

    /// 启动一个后台脚本：等当前进程退出后替换 App 并重新打开；复制失败时恢复旧版本。
    static func replaceAndRelaunch(with staged: URL, destination: URL = Bundle.main.bundleURL,
                                   waitingFor pid: Int32 = getpid(), relaunch: Bool = true) throws {
        let script = """
        while kill -0 "$1" 2>/dev/null; do sleep 0.2; done
        rm -rf "$3.old"
        if mv "$3" "$3.old"; then
          if /usr/bin/ditto "$2" "$3"; then
            rm -rf "$3.old"
          else
            rm -rf "$3"
            mv "$3.old" "$3"
          fi
        fi
        if [ "$4" = 1 ]; then /usr/bin/open "$3"; fi
        """
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", script, "voiceinput-update", String(pid), staged.path, destination.path,
                             relaunch ? "1" : "0"]
        try process.run()
    }

    private static func findApp(in folder: URL) throws -> URL {
        let items = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
        guard let app = items.first(where: { $0.pathExtension == "app" }) else {
            throw UpdateError.message("安装包里没有找到 App")
        }
        return app
    }

    private static func verify(_ app: URL, expected: AppVersion, bundleID: String) throws {
        guard let bundle = Bundle(url: app), bundle.bundleIdentifier == bundleID else {
            throw UpdateError.message("安装包里的 App 不是 VoiceInput")
        }
        let text = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        guard let version = AppVersion(text), version == expected else {
            throw UpdateError.message("安装包版本（\(text)）和发布版本 v\(expected) 不一致")
        }
    }

    @discardableResult
    static func run(_ path: String, _ arguments: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let name = (path as NSString).lastPathComponent
            throw UpdateError.message("\(name) 失败：\(output.trimmingCharacters(in: .whitespacesAndNewlines))")
        }
        return output
    }
}
