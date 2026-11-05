import Foundation

struct Config: Codable {
    var locale: String
    var hotkey: String
    var insertMethod: String
    var restoreClipboard: Bool
    var onDeviceRecognition: Bool
    var maxRecordingSeconds: Double
    var minHoldSeconds: Double
    var playFeedbackSound: Bool
    var showHUD: Bool
    var hudOpacity: Double
    var contextualStrings: [String]

    init() {
        locale = "zh-CN"
        hotkey = "rightOption"
        insertMethod = "paste"
        restoreClipboard = false
        onDeviceRecognition = true
        maxRecordingSeconds = 60
        minHoldSeconds = 0.35
        playFeedbackSound = true
        showHUD = true
        hudOpacity = 0.45
        contextualStrings = [
            "OpenCode", "Claude Code", "Claude", "GitHub", "API", "CLI",
            "commit", "pull request", "bug", "refactor", "plugin", "terminal",
            "插件", "终端", "代码", "重构", "部署", "测试", "编译", "依赖"
        ]
    }

    enum CodingKeys: String, CodingKey {
        case locale, hotkey, insertMethod, restoreClipboard, onDeviceRecognition
        case maxRecordingSeconds, minHoldSeconds, playFeedbackSound, showHUD
        case hudOpacity, contextualStrings
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = Config()
        locale = try c.decodeIfPresent(String.self, forKey: .locale) ?? d.locale
        hotkey = try c.decodeIfPresent(String.self, forKey: .hotkey) ?? d.hotkey
        insertMethod = try c.decodeIfPresent(String.self, forKey: .insertMethod) ?? d.insertMethod
        restoreClipboard = try c.decodeIfPresent(Bool.self, forKey: .restoreClipboard) ?? d.restoreClipboard
        onDeviceRecognition = try c.decodeIfPresent(Bool.self, forKey: .onDeviceRecognition) ?? d.onDeviceRecognition
        maxRecordingSeconds = try c.decodeIfPresent(Double.self, forKey: .maxRecordingSeconds) ?? d.maxRecordingSeconds
        minHoldSeconds = try c.decodeIfPresent(Double.self, forKey: .minHoldSeconds) ?? d.minHoldSeconds
        playFeedbackSound = try c.decodeIfPresent(Bool.self, forKey: .playFeedbackSound) ?? d.playFeedbackSound
        showHUD = try c.decodeIfPresent(Bool.self, forKey: .showHUD) ?? d.showHUD
        hudOpacity = try c.decodeIfPresent(Double.self, forKey: .hudOpacity) ?? d.hudOpacity
        contextualStrings = try c.decodeIfPresent([String].self, forKey: .contextualStrings) ?? d.contextualStrings
    }

    static var directory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/voice-input", isDirectory: true)
    }

    static var fileURL: URL {
        directory.appendingPathComponent("config.json")
    }

    static func load() -> Config {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        if let data = try? Data(contentsOf: fileURL),
           let config = try? JSONDecoder().decode(Config.self, from: data) {
            return config
        }
        let config = Config()
        config.save()
        return config
    }

    func save() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(self) else { return }
        try? data.write(to: Config.fileURL, options: .atomic)
    }
}
