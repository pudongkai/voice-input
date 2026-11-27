import Foundation

/// 界面语言设置：跟随系统，或固定为中文 / 英文。
enum UILanguage: String, CaseIterable {
    case system
    case zh
    case en
}

enum L10n {
    static var language: UILanguage = .system

    /// 跟随系统时，系统首选语言是中文就用中文，其余语言一律用英文。
    /// Locale.preferredLanguages 已包含「系统设置 → 通用 → 语言与地区 → App」里的单独设置。
    static var isChinese: Bool {
        switch language {
        case .zh: return true
        case .en: return false
        case .system: return (Locale.preferredLanguages.first ?? "en").lowercased().hasPrefix("zh")
        }
    }
}

/// 按当前界面语言返回中文或英文文本。文案在调用处按需求值，切换语言后下次显示即生效。
func L(_ zh: String, _ en: String) -> String {
    L10n.isChinese ? zh : en
}
