import Cocoa

/// 定时检查新版本，提供菜单项，并负责下载、安装和重启。
final class UpdateController: NSObject {
    var isAutoCheckEnabled: () -> Bool = { true }
    var notify: (_ title: String, _ body: String, _ duration: TimeInterval) -> Void = { _, _, _ in }

    private(set) var available: ReleaseInfo?
    private var progress: Double?
    private var downloader: UpdateDownloader?
    private var timer: Timer?

    /// 同一个新版本只自动提示一次。
    private static let notifiedKey = "notifiedUpdateVersion"
    private static let checkInterval: TimeInterval = 24 * 3600

    func start() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 15) { [weak self] in
            self?.autoCheck()
        }
        timer = Timer.scheduledTimer(withTimeInterval: Self.checkInterval, repeats: true) { [weak self] _ in
            self?.autoCheck()
        }
    }

    // MARK: - Menu

    /// 有新版本或正在下载时显示在菜单最上面；否则返回 nil。
    func statusMenuItem() -> NSMenuItem? {
        guard let release = available else { return nil }
        if let progress {
            let item = NSMenuItem(title: L("正在下载 v\(release.version)… \(Int(progress * 100))%", "Downloading v\(release.version)… \(Int(progress * 100))%"), action: nil,
                                  keyEquivalent: "")
            item.isEnabled = false
            return item
        }
        let item = NSMenuItem(title: L("更新到 v\(release.version)", "Update to v\(release.version)"), action: #selector(installUpdate), keyEquivalent: "")
        item.target = self
        item.image = Self.orangeDot()
        return item
    }

    func checkNowMenuItem() -> NSMenuItem {
        let item = NSMenuItem(title: L("检查更新…", "Check for Updates…"), action: #selector(checkNow), keyEquivalent: "")
        item.target = self
        item.isEnabled = progress == nil
        return item
    }

    private static func orangeDot() -> NSImage {
        NSImage(size: NSSize(width: 8, height: 8), flipped: false) { rect in
            NSColor.systemOrange.setFill()
            NSBezierPath(ovalIn: rect).fill()
            return true
        }
    }

    // MARK: - Checking

    private func autoCheck() {
        guard isAutoCheckEnabled(), progress == nil else { return }
        check(manual: false)
    }

    @objc private func checkNow() {
        check(manual: true)
    }

    private func check(manual: Bool) {
        ReleaseChecker.fetchNewest { [weak self] result in
            self?.handle(result, manual: manual)
        }
    }

    private func handle(_ result: Result<ReleaseInfo?, Error>, manual: Bool) {
        switch result {
        case .failure(let error):
            Log.write("update check failed: \(error.localizedDescription)")
            if manual { notify(L("检查更新失败", "Update check failed"), error.localizedDescription, 3) }
        case .success(let release):
            guard let release, release.version > AppVersion.current else {
                available = nil
                if manual { notify(L("已是最新版本", "You're up to date"), L("当前版本 v\(AppVersion.current)", "Current version v\(AppVersion.current)"), 2.4) }
                return
            }
            available = release
            Log.write("update available v\(release.version)")
            announce(release, manual: manual)
        }
    }

    private func announce(_ release: ReleaseInfo, manual: Bool) {
        let defaults = UserDefaults.standard
        let version = release.version.description
        guard manual || defaults.string(forKey: Self.notifiedKey) != version else { return }
        defaults.set(version, forKey: Self.notifiedKey)
        notify(L("发现新版本 v\(version)", "New version v\(version) available"), L("点菜单栏的麦克风图标 →「更新到 v\(version)」", "Click the menu bar mic icon → \"Update to v\(version)\""), 6)
    }

    // MARK: - Installing

    @objc private func installUpdate() {
        guard let release = available, progress == nil else { return }
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let destination = caches.appendingPathComponent("com.pudongkai.voiceinput/update/VoiceInput.dmg")
        let downloader = UpdateDownloader(destination: destination)
        self.downloader = downloader
        progress = 0
        notify(L("正在下载 v\(release.version)", "Downloading v\(release.version)"), L("下载完成后会自动安装并重启", "It will install and restart automatically when done"), 2.4)
        downloader.start(release.dmgURL, progress: { [weak self] value in
            self?.progress = value
        }, finish: { [weak self] result in
            self?.downloadFinished(result, release: release)
        })
    }

    private func downloadFinished(_ result: Result<URL, Error>, release: ReleaseInfo) {
        downloader = nil
        switch result {
        case .failure(let error):
            progress = nil
            Log.write("update download failed: \(error.localizedDescription)")
            notify(L("下载失败", "Download failed"), error.localizedDescription, 3)
        case .success(let dmg):
            if UpdateInstaller.canReplaceInPlace {
                install(dmg, release: release)
            } else {
                openManually(dmg, release: release)
            }
        }
    }

    private func install(_ dmg: URL, release: ReleaseInfo) {
        notify(L("正在安装 v\(release.version)", "Installing v\(release.version)"), L("完成后 VoiceInput 会自动重启", "VoiceInput will restart when done"), 3)
        DispatchQueue.global(qos: .userInitiated).async {
            let result = Result { try UpdateInstaller.stage(dmg: dmg, expected: release.version) }
            DispatchQueue.main.async { [weak self] in
                self?.finishInstall(result, release: release)
            }
        }
    }

    private func finishInstall(_ result: Result<URL, Error>, release: ReleaseInfo) {
        progress = nil
        do {
            let staged = try result.get()
            try UpdateInstaller.replaceAndRelaunch(with: staged)
            Log.write("update v\(release.version) staged, relaunching")
            NSApp.terminate(nil)
        } catch {
            Log.write("update install failed: \(error.localizedDescription)")
            notify(L("更新失败", "Update failed"), error.localizedDescription, 4)
        }
    }

    /// 不在「应用程序」文件夹里运行时不自动替换：把安装包放进「下载」并打开，由用户拖拽安装。
    private func openManually(_ dmg: URL, release: ReleaseInfo) {
        progress = nil
        let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0]
        let target = downloads.appendingPathComponent("VoiceInput-\(release.version).dmg")
        do {
            try? FileManager.default.removeItem(at: target)
            try FileManager.default.moveItem(at: dmg, to: target)
            NSWorkspace.shared.open(target)
            notify(L("安装包已下载", "Update downloaded"), L("当前 App 不在「应用程序」文件夹里，请把新版本拖进去替换", "This app is not in the Applications folder. Drag the new version there to replace it."), 5)
        } catch {
            notify(L("下载失败", "Download failed"), error.localizedDescription, 3)
        }
    }
}
