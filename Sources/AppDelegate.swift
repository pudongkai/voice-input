import AVFoundation
import Cocoa
import ServiceManagement
import Speech

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private enum State {
        case idle
        case recording
        case processing
    }

    private var statusItem: NSStatusItem!
    private let menu = NSMenu()
    private let hud = HUD()
    private let hotkey = HotkeyMonitor()

    private var config = Config.load()
    private var session: SpeechSession?
    private var state: State = .idle
    private var openedDictationSettings = false
    private var lastTranscript = ""
    private var accessTimer: Timer?
    private var accessibilityWasTrusted = false

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
    }

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setupHotkey()
        hud.setOpacity(config.hudOpacity)
        enableLaunchAtLoginIfNeeded()
        rebuildMenu()
        requestInitialPermissions()
        startAccessibilityWatcher()
        Log.write("app launched, config at \(Config.fileURL.path)")

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            guard let self, self.config.showHUD else { return }
            self.hud.showInfo(
                title: "语音输入已就绪",
                body: "按住右 Option 说话，松开自动输入到当前窗口",
                autoHide: 3.0
            )
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    // MARK: - Setup

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: "语音输入")
            button.image?.isTemplate = true
            button.toolTip = "VoiceInput \(appVersion)：按住右 Option 说话"
        }
        menu.delegate = self
        statusItem.menu = menu
    }

    private func setupHotkey() {
        hotkey.onPress = { [weak self] in
            self?.startRecording()
        }
        hotkey.onRelease = { [weak self] duration in
            self?.finishRecording(duration: duration)
        }
        hotkey.onCancel = { [weak self] in
            self?.cancelRecording()
        }
        hotkey.start()
    }

    /// 用户可能在 App 运行期间才去系统设置里打开辅助功能，检测到变化后重启按键监听。
    private func startAccessibilityWatcher() {
        accessibilityWasTrusted = Permissions.accessibilityGranted
        Log.write("accessibility initial=\(accessibilityWasTrusted)")
        accessTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            let trusted = Permissions.accessibilityGranted
            guard trusted != self.accessibilityWasTrusted else { return }
            self.accessibilityWasTrusted = trusted
            Log.write("accessibility trusted=\(trusted)")
            self.hotkey.stop()
            self.hotkey.start()
            if trusted {
                self.showNotice("辅助功能已授权", "现在可以按住右 Option 说话了")
            }
        }
    }

    private func requestInitialPermissions() {
        Permissions.requestMicrophone()
        Permissions.requestSpeech()

        let defaults = UserDefaults.standard
        if !Permissions.accessibilityGranted, !defaults.bool(forKey: "didPromptAccessibility") {
            defaults.set(true, forKey: "didPromptAccessibility")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                Permissions.promptAccessibility()
            }
        }
    }

    // MARK: - Recording flow

    private func startRecording() {
        guard state == .idle else { return }

        guard Permissions.microphoneGranted else {
            Permissions.requestMicrophone()
            showNotice("需要麦克风权限", "请在系统设置中允许「VoiceInput」使用麦克风，然后重试")
            return
        }
        guard Permissions.speechGranted else {
            Permissions.requestSpeech()
            showNotice("需要语音识别权限", "请在系统设置中允许「VoiceInput」使用语音识别，然后重试")
            return
        }
        guard Permissions.accessibilityGranted else {
            Permissions.promptAccessibility()
            showNotice("需要辅助功能权限", "请在系统设置中授权，否则无法监听快捷键和输入文字")
            return
        }

        let session = SpeechSession(config: config)
        session.onPartial = { [weak self] text in
            guard let self else { return }
            if self.config.showHUD {
                self.hud.updatePartial(text)
            }
        }
        session.onFinish = { [weak self] result in
            self?.handleFinish(result)
        }

        do {
            try session.start()
        } catch {
            Log.write("start failed: \(error.localizedDescription)")
            notify(error.localizedDescription)
            return
        }

        self.session = session
        state = .recording
        setRecordingIcon(true)

        if config.playFeedbackSound {
            NSSound(named: "Tink")?.play()
        }
        if config.showHUD {
            hud.showListening()
        }
    }

    private func finishRecording(duration: TimeInterval) {
        guard state == .recording, let session else { return }

        if duration < config.minHoldSeconds {
            session.cancel()
            self.session = nil
            state = .idle
            setRecordingIcon(false)
            if config.showHUD {
                hud.hide(after: 0.1)
            }
            return
        }

        state = .processing
        setRecordingIcon(false)
        if config.playFeedbackSound {
            NSSound(named: "Pop")?.play()
        }
        if config.showHUD {
            hud.showProcessing()
        }
        session.stop()
    }

    private func cancelRecording() {
        guard state == .recording || state == .processing else { return }
        session?.cancel()
        session = nil
        state = .idle
        setRecordingIcon(false)
        if config.showHUD {
            hud.hide(after: 0.1)
        }
    }

    private func handleFinish(_ result: Result<String, Error>) {
        session = nil
        state = .idle
        setRecordingIcon(false)

        switch result {
        case .success(let raw):
            let text = raw
                .replacingOccurrences(of: "\r", with: " ")
                .replacingOccurrences(of: "\n", with: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else {
                Log.write("session empty")
                if config.showHUD {
                    hud.showInfo(
                        title: "没听清",
                        body: "没有识别到内容，请靠近麦克风再说一次",
                        autoHide: 2.2
                    )
                }
                return
            }
            lastTranscript = text
            TextInjector.insert(
                text,
                method: config.insertMethod,
                restoreClipboard: config.restoreClipboard
            )
            if config.showHUD {
                hud.showInjected(text)
            }
            Log.write("injected chars=\(text.count) method=\(config.insertMethod)")

        case .failure(let error):
            let message = error.localizedDescription
            let nsError = error as NSError
            Log.write("recognition failed: \(nsError.domain) \(nsError.code) \(message)")
            if Permissions.isDictationDisabledError(error) {
                handleDictationDisabled()
                return
            }
            notify("识别失败：\(message)")
        }
    }

    // MARK: - UI helpers

    /// 录音时图标变红，并在背后淡入一块浅红色圆角底，与官网演示的效果一致。
    private func setRecordingIcon(_ recording: Bool) {
        guard let button = statusItem.button else { return }
        button.contentTintColor = recording ? .systemRed : nil

        button.wantsLayer = true
        guard let layer = button.layer else { return }
        layer.cornerRadius = 5
        layer.cornerCurve = .continuous

        // 视图自带的 layer 默认不做隐式动画，这里显式加一个颜色渐变。
        let target = recording ? NSColor.systemRed.withAlphaComponent(0.18).cgColor : NSColor.clear.cgColor
        let fade = CABasicAnimation(keyPath: "backgroundColor")
        fade.fromValue = layer.presentation()?.backgroundColor ?? layer.backgroundColor
        fade.toValue = target
        fade.duration = 0.2
        fade.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        layer.backgroundColor = target
        layer.add(fade, forKey: "recordingBackdrop")
    }

    /// 设置页每次运行只自动打开一次，避免用户每按一次快捷键就被弹一次窗口。
    private func handleDictationDisabled() {
        notify("请先打开系统「听写」：系统设置 → 键盘 → 听写")
        guard !openedDictationSettings else { return }
        openedDictationSettings = true
        Permissions.openDictationSettings()
    }

    private func showNotice(_ title: String, _ body: String, duration: TimeInterval = 2.6) {
        Log.write("notice: \(title) - \(body)")
        if config.showHUD {
            hud.showInfo(title: title, body: body, autoHide: duration)
        }
    }

    private func notify(_ message: String) {
        if config.showHUD {
            hud.showError(message)
        } else {
            Log.write("notify: \(message)")
        }
    }

    private func showAlert(_ title: String, _ message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    // MARK: - Menu

    func menuWillOpen(_ menu: NSMenu) {
        rebuildMenu()
    }

    private func rebuildMenu() {
        menu.removeAllItems()

        let statusText: String
        switch state {
        case .idle: statusText = "就绪 · 按住右 Option 说话"
        case .recording: statusText = "录音中…"
        case .processing: statusText = "识别中…"
        }
        let status = NSMenuItem(title: statusText, action: nil, keyEquivalent: "")
        status.isEnabled = false
        menu.addItem(status)

        if !lastTranscript.isEmpty {
            let item = NSMenuItem(title: "最近：\(lastTranscript.prefix(24))", action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
        }

        menu.addItem(.separator())
        menu.addItem(permissionItem(title: "麦克风", granted: Permissions.microphoneGranted,
                                    action: #selector(openMicrophoneSettings)))
        menu.addItem(permissionItem(title: "语音识别", granted: Permissions.speechGranted,
                                    action: #selector(openSpeechSettings)))
        menu.addItem(permissionItem(title: "辅助功能", granted: Permissions.accessibilityGranted,
                                    action: #selector(openAccessibilitySettings)))
        menu.addItem(permissionItem(title: "听写", granted: Permissions.dictationEnabled,
                                    action: #selector(openDictationSettings),
                                    grantedText: "已开启", deniedText: "未开启"))

        menu.addItem(.separator())

        let insertItem = NSMenuItem(title: "输入方式", action: nil, keyEquivalent: "")
        let insertMenu = NSMenu()
        insertMenu.addItem(methodItem(title: "模拟键盘输入", value: "type"))
        insertMenu.addItem(methodItem(title: "粘贴（同时复制到剪贴板）", value: "paste"))
        insertItem.submenu = insertMenu
        menu.addItem(insertItem)

        let onDeviceTitle: String
        if config.onDeviceRecognition && !onDeviceAvailable {
            onDeviceTitle = "设备端识别（语言包未下载）"
        } else {
            onDeviceTitle = "设备端识别"
        }
        menu.addItem(toggleItem(title: onDeviceTitle, on: config.onDeviceRecognition,
                                action: #selector(toggleOnDevice)))
        menu.addItem(toggleItem(title: "播放提示音", on: config.playFeedbackSound,
                                action: #selector(toggleSound)))
        menu.addItem(toggleItem(title: "显示悬浮提示", on: config.showHUD,
                                action: #selector(toggleHUD)))

        let opacityItem = NSMenuItem(title: "悬浮窗透明度", action: nil, keyEquivalent: "")
        let rowWidth: CGFloat = 300
        let opacityView = NSView(frame: NSRect(x: 0, y: 0, width: rowWidth, height: 24))
        opacityView.autoresizingMask = [.width]

        let percent = Int((config.hudOpacity * 100).rounded())
        let opacityLabel = NSTextField(labelWithString: "悬浮窗透明度")
        opacityLabel.font = .menuFont(ofSize: 0)
        opacityLabel.textColor = .labelColor
        opacityLabel.frame = NSRect(x: 22, y: 4, width: 85, height: 16)
        opacityView.addSubview(opacityLabel)

        let percentLabel = NSTextField(labelWithString: "\(percent)%")
        percentLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        percentLabel.textColor = .secondaryLabelColor
        percentLabel.alignment = .right
        percentLabel.frame = NSRect(x: rowWidth - 34, y: 4, width: 34, height: 16)
        percentLabel.tag = 102
        opacityView.addSubview(percentLabel)

        let slider = NSSlider(
            value: min(max(config.hudOpacity, 0.30), 1.0),
            minValue: 0.30,
            maxValue: 1.0,
            target: self,
            action: #selector(hudOpacityChanged(_:))
        )
        slider.isContinuous = true
        slider.controlSize = .small
        slider.frame = NSRect(x: 114, y: 2, width: rowWidth - 104 - 40, height: 20)
        opacityView.addSubview(slider)

        opacityItem.view = opacityView
        menu.addItem(opacityItem)

        menu.addItem(.separator())
        menu.addItem(actionItem(title: "打开配置文件", action: #selector(openConfig)))
        menu.addItem(actionItem(title: "重新加载配置", action: #selector(reloadConfig)))

        let loginStatus = SMAppService.mainApp.status
        let loginTitle: String
        switch loginStatus {
        case .requiresApproval: loginTitle = "开机启动（需在系统设置中批准）"
        default: loginTitle = "开机启动"
        }
        menu.addItem(toggleItem(title: loginTitle, on: loginStatus == .enabled,
                                action: #selector(toggleLaunchAtLogin)))

        menu.addItem(.separator())
        let versionItem = NSMenuItem(title: "VoiceInput v\(appVersion)", action: nil, keyEquivalent: "")
        versionItem.isEnabled = false
        menu.addItem(versionItem)

        let quit = NSMenuItem(title: "退出 VoiceInput", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quit.target = NSApp
        menu.addItem(quit)
    }

    private func permissionItem(
        title: String,
        granted: Bool,
        action: Selector,
        grantedText: String = "已授权",
        deniedText: String = "未授权"
    ) -> NSMenuItem {
        let item = NSMenuItem(
            title: "\(title)：\(granted ? grantedText : deniedText)",
            action: action,
            keyEquivalent: ""
        )
        item.target = self
        // 用彩色圆点代替对勾，和下面的开关项区分开：绿色已授权，橙色未授权。
        item.state = .on
        item.onStateImage = statusDot(granted ? .systemGreen : .systemOrange)
        return item
    }

    private func statusDot(_ color: NSColor) -> NSImage {
        let size = NSSize(width: 8, height: 8)
        let image = NSImage(size: size, flipped: false) { rect in
            color.setFill()
            NSBezierPath(ovalIn: rect).fill()
            return true
        }
        image.isTemplate = false
        return image
    }

    private func methodItem(title: String, value: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: #selector(setInsertMethod(_:)), keyEquivalent: "")
        item.target = self
        item.representedObject = value
        item.state = config.insertMethod == value ? .on : .off
        return item
    }

    private func toggleItem(title: String, on: Bool, action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        item.state = on ? .on : .off
        return item
    }

    private func actionItem(title: String, action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    // MARK: - Actions

    private var onDeviceAvailable: Bool {
        SFSpeechRecognizer(locale: Locale(identifier: config.locale))?.supportsOnDeviceRecognition ?? false
    }

    @objc private func openMicrophoneSettings() {
        if AVCaptureDevice.authorizationStatus(for: .audio) == .notDetermined {
            Permissions.requestMicrophone()
        } else {
            Permissions.openMicrophoneSettings()
        }
    }

    @objc private func openSpeechSettings() {
        if SFSpeechRecognizer.authorizationStatus() == .notDetermined {
            Permissions.requestSpeech()
        } else {
            Permissions.openSpeechSettings()
        }
    }

    @objc private func openDictationSettings() {
        Permissions.openDictationSettings()
    }

    @objc private func openAccessibilitySettings() {
        guard !Permissions.accessibilityGranted else {
            Permissions.openAccessibilitySettings()
            return
        }

        // 先在后台删掉旧签名对应的失效条目，再让系统重新登记当前版本。
        // 登记完成后列表里才会出现 VoiceInput，所以设置页要等一会儿再打开。
        resetAccessibilityPermission()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            Permissions.promptAccessibility()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            Permissions.openAccessibilitySettings()
            self?.showNotice("打开 VoiceInput 的开关", "列表里没有的话，点下方「+」从「应用程序」添加 VoiceInput",
                            duration: 10)
        }
    }

    private func resetAccessibilityPermission() {
        let bundleID = Bundle.main.bundleIdentifier ?? "com.pudongkai.voiceinput"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tccutil")
        process.arguments = ["reset", "Accessibility", bundleID]
        do {
            try process.run()
            process.waitUntilExit()
            Log.write("tccutil reset Accessibility status=\(process.terminationStatus) bundle=\(bundleID)")
        } catch {
            Log.write("tccutil reset failed: \(error.localizedDescription)")
        }
    }

    @objc private func setInsertMethod(_ sender: NSMenuItem) {
        guard let value = sender.representedObject as? String else { return }
        config.insertMethod = value
        config.save()
    }

    @objc private func toggleOnDevice() {
        config.onDeviceRecognition.toggle()
        config.save()
        if config.onDeviceRecognition && !onDeviceAvailable {
            showAlert(
                "设备端语言包未下载",
                "当前语言（\(config.locale)）还不能在本机识别，会先使用 Apple 在线识别。\n\n要启用设备端识别：打开 系统设置 → 键盘 → 听写，开启听写并添加中文，等待语言包下载完成后，再重新勾选本项。"
            )
        }
    }

    @objc private func toggleSound() {
        config.playFeedbackSound.toggle()
        config.save()
    }

    @objc private func toggleHUD() {
        config.showHUD.toggle()
        config.save()
    }

    @objc private func hudOpacityChanged(_ sender: NSSlider) {
        let value = (sender.doubleValue * 100).rounded() / 100
        config.hudOpacity = value
        config.save()
        hud.setOpacity(value)

        let percent = Int((value * 100).rounded())
        if let label = sender.superview?.viewWithTag(102) as? NSTextField {
            label.stringValue = "\(percent)%"
        }
        if config.showHUD {
            hud.showInfo(title: "悬浮窗透明度 \(percent)%", body: "拖动滑块查看效果", autoHide: 0.9)
        }
    }

    @objc private func openConfig() {
        _ = Config.load()
        NSWorkspace.shared.open(Config.fileURL)
    }

    @objc private func reloadConfig() {
        config = Config.load()
        hud.setOpacity(config.hudOpacity)
        Log.write("config reloaded")
        if config.showHUD {
            hud.showInfo(title: "配置已重新加载", body: "", autoHide: 1.2)
        }
    }

    /// 首次从“应用程序”目录启动时，默认加入开机启动。之后用户手动关闭不会再强行打开。
    private func enableLaunchAtLoginIfNeeded() {
        let defaults = UserDefaults.standard
        let key = "didSetupLaunchAtLogin"
        guard !defaults.bool(forKey: key) else { return }

        let path = Bundle.main.bundlePath
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        guard path.hasPrefix("/Applications/") || path.hasPrefix(home + "/Applications/") else { return }

        let service = SMAppService.mainApp
        if service.status == .notRegistered {
            do {
                try service.register()
                Log.write("launch at login registered, status=\(service.status.rawValue)")
            } catch {
                Log.write("launch at login register failed: \(error.localizedDescription)")
            }
        }
        defaults.set(true, forKey: key)
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            showAlert("设置开机启动失败", error.localizedDescription)
        }
    }
}
