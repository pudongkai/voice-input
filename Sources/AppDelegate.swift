import AVFoundation
import Carbon
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
    private lazy var clipboardHistory = ClipboardHistory(capacity: Self.clampedHistorySize(config.clipboardHistorySize))
    private lazy var clipboardPanel: ClipboardPanel = {
        let panel = ClipboardPanel(history: clipboardHistory)
        panel.onPick = { [weak self] entry in
            self?.pasteFromHistory(entry, delay: 0.05)
        }
        return panel
    }()
    private var clipboardShortcut: GlobalShortcut?
    private let updater = UpdateController()

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
        applyClipboardSettings()
        setupUpdater()
        applyOverlayOpacity(config.hudOpacity)
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
            button.image = Self.idleIcon
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

        // 升级后签名会变，系统设置里旧版本留下的条目开关还开着却不生效，用户也删不掉。
        // 每个构建号第一次启动且辅助功能未生效时，先在后台清掉旧条目，再让系统登记当前版本。
        let defaults = UserDefaults.standard
        let key = "accessibilityPromptedBuild"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
        guard !Permissions.accessibilityGranted, defaults.string(forKey: key) != build else { return }
        defaults.set(build, forKey: key)
        resetAccessibilityPermission()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            Permissions.promptAccessibility()
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

    private static let idleIcon: NSImage? = {
        let image = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: "语音输入")
        image?.isTemplate = true
        return image
    }()

    /// 录音状态与官网演示一致：浅红色圆角底上放红色话筒。
    /// 底色和图标画进同一张图片，尺寸固定，不受状态栏按钮高度影响。
    private static let recordingIcon: NSImage = {
        let size = NSSize(width: 24, height: 20)
        let image = NSImage(size: size, flipped: false) { rect in
            NSColor.systemRed.withAlphaComponent(0.18).setFill()
            NSBezierPath(roundedRect: rect, xRadius: 5, yRadius: 5).fill()

            let config = NSImage.SymbolConfiguration(pointSize: 13, weight: .regular)
                .applying(.init(paletteColors: [.systemRed]))
            guard let mic = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: nil)?
                .withSymbolConfiguration(config) else { return true }
            let origin = NSPoint(x: (rect.width - mic.size.width) / 2, y: (rect.height - mic.size.height) / 2)
            mic.draw(in: NSRect(origin: origin, size: mic.size))
            return true
        }
        image.isTemplate = false
        image.accessibilityDescription = "正在录音"
        return image
    }()

    private func setRecordingIcon(_ recording: Bool) {
        statusItem.button?.image = recording ? Self.recordingIcon : Self.idleIcon
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
        if let updateItem = updater.statusMenuItem() {
            menu.addItem(updateItem)
        }

        if !lastTranscript.isEmpty {
            let item = NSMenuItem(title: "最近：\(lastTranscript.prefix(24))", action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
        }

        // 只列出还没授权或没开启的项，全部就绪时整组不显示。
        let missing: [NSMenuItem] = [
            Permissions.microphoneGranted ? nil
                : missingPermissionItem("麦克风：未授权", action: #selector(openMicrophoneSettings)),
            Permissions.speechGranted ? nil
                : missingPermissionItem("语音识别：未授权", action: #selector(openSpeechSettings)),
            Permissions.accessibilityGranted ? nil
                : missingPermissionItem("辅助功能：未授权", action: #selector(openAccessibilitySettings)),
            Permissions.dictationEnabled ? nil
                : missingPermissionItem("听写：未开启", action: #selector(openDictationSettings)),
        ].compactMap { $0 }
        if !missing.isEmpty {
            menu.addItem(.separator())
            missing.forEach(menu.addItem)
        }

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
        menu.addItem(clipboardMenuItem())

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
        menu.addItem(updater.checkNowMenuItem())
        menu.addItem(toggleItem(title: "自动检查更新", on: config.autoCheckUpdates,
                                action: #selector(toggleAutoCheckUpdates)))

        let quit = NSMenuItem(title: "退出 VoiceInput", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quit.target = NSApp
        menu.addItem(quit)
    }

    private func missingPermissionItem(_ title: String, action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        item.state = .on
        item.onStateImage = statusDot(.systemOrange)
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

    // MARK: - Clipboard history

    private static let historySizeOptions = [10, 20, 50, 100]

    private static func clampedHistorySize(_ size: Int) -> Int {
        min(max(size, 1), 200)
    }

    private func applyClipboardSettings() {
        clipboardHistory.capacity = Self.clampedHistorySize(config.clipboardHistorySize)
        guard config.clipboardHistoryEnabled else {
            clipboardHistory.stop()
            clipboardHistory.clear()
            clipboardShortcut = nil
            return
        }
        clipboardHistory.start()
        if clipboardShortcut == nil {
            clipboardShortcut = GlobalShortcut(keyCode: kVK_ANSI_V, modifiers: cmdKey | shiftKey) { [weak self] in
                self?.showClipboardPicker()
            }
        }
    }

    /// 录音悬浮窗和剪贴板面板共用一个透明度设置。
    private func applyOverlayOpacity(_ value: Double) {
        hud.setOpacity(value)
        clipboardPanel.setOpacity(value)
    }

    private func showClipboardPicker() {
        guard config.clipboardHistoryEnabled else { return }
        clipboardPanel.present()
    }

    /// 写回剪贴板后模拟 ⌘V。从菜单里选时要等菜单收起、焦点回到原来的窗口。
    private func pasteFromHistory(_ entry: ClipboardEntry, delay: TimeInterval) {
        clipboardHistory.restore(entry)
        guard Permissions.accessibilityGranted else {
            showNotice("已复制到剪贴板", "授权辅助功能后可以直接粘贴，现在请按 ⌘V")
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            TextInjector.postCommandV()
        }
    }

    private func clipboardMenuItem() -> NSMenuItem {
        let item = NSMenuItem(title: "剪贴板历史", action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        if config.clipboardHistoryEnabled {
            addHistoryEntries(to: submenu)
            submenu.addItem(.separator())
            let open = actionItem(title: "打开历史列表", action: #selector(openClipboardPicker))
            open.keyEquivalent = "v"
            open.keyEquivalentModifierMask = [.command, .shift]
            submenu.addItem(open)
            submenu.addItem(actionItem(title: "清空历史", action: #selector(clearClipboardHistory)))
            submenu.addItem(historySizeItem())
            submenu.addItem(.separator())
        }
        submenu.addItem(toggleItem(title: "开启剪贴板历史", on: config.clipboardHistoryEnabled,
                                   action: #selector(toggleClipboardHistory)))
        item.submenu = submenu
        return item
    }

    private func addHistoryEntries(to submenu: NSMenu) {
        let entries = clipboardHistory.entries.prefix(10)
        guard !entries.isEmpty else {
            let empty = NSMenuItem(title: "还没有复制过内容", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            submenu.addItem(empty)
            return
        }
        for entry in entries {
            let item = NSMenuItem(title: Self.menuTitle(for: entry), action: #selector(pasteHistoryItem(_:)),
                                  keyEquivalent: "")
            item.target = self
            item.representedObject = entry.id
            if case .image(_, let thumbnail, let pixelSize) = entry.content {
                item.image = Self.menuIcon(from: thumbnail, pixelSize: pixelSize)
            }
            submenu.addItem(item)
        }
    }

    private func historySizeItem() -> NSMenuItem {
        let item = NSMenuItem(title: "记忆条数", action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        let current = clipboardHistory.capacity
        let options = Set(Self.historySizeOptions + [current]).sorted()
        for size in options {
            let option = NSMenuItem(title: "\(size) 条", action: #selector(setClipboardHistorySize(_:)),
                                    keyEquivalent: "")
            option.target = self
            option.representedObject = size
            option.state = size == current ? .on : .off
            submenu.addItem(option)
        }
        item.submenu = submenu
        return item
    }

    private static func menuTitle(for entry: ClipboardEntry) -> String {
        switch entry.content {
        case .text(let text):
            let flat = text.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
            return flat.count > 30 ? String(flat.prefix(30)) + "…" : flat
        case .image(_, _, let pixelSize):
            return "图片 \(Int(pixelSize.width))×\(Int(pixelSize.height))"
        }
    }

    private static func menuIcon(from thumbnail: NSImage, pixelSize: NSSize) -> NSImage? {
        guard let icon = thumbnail.copy() as? NSImage else { return nil }
        let aspect = pixelSize.height > 0 ? pixelSize.width / pixelSize.height : 1
        icon.size = NSSize(width: min(32, 18 * aspect), height: 18)
        return icon
    }

    @objc private func pasteHistoryItem(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? UUID, let entry = clipboardHistory.entry(id: id) else { return }
        pasteFromHistory(entry, delay: 0.25)
    }

    @objc private func openClipboardPicker() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.showClipboardPicker()
        }
    }

    private func setupUpdater() {
        updater.isAutoCheckEnabled = { [weak self] in
            self?.config.autoCheckUpdates ?? false
        }
        updater.notify = { [weak self] title, body, duration in
            self?.showNotice(title, body, duration: duration)
        }
        updater.start()
    }

    @objc private func toggleAutoCheckUpdates() {
        config.autoCheckUpdates.toggle()
        config.save()
    }

    @objc private func clearClipboardHistory() {
        clipboardHistory.clear()
    }

    @objc private func toggleClipboardHistory() {
        config.clipboardHistoryEnabled.toggle()
        config.save()
        applyClipboardSettings()
    }

    @objc private func setClipboardHistorySize(_ sender: NSMenuItem) {
        guard let size = sender.representedObject as? Int else { return }
        config.clipboardHistorySize = size
        config.save()
        applyClipboardSettings()
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
        applyOverlayOpacity(value)

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
        applyOverlayOpacity(config.hudOpacity)
        applyClipboardSettings()
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
