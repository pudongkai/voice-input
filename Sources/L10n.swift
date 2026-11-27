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
    static var isEnglish: Bool {
        switch language {
        case .zh: return false
        case .en: return true
        case .system:
            let preferred = Locale.preferredLanguages.first ?? "en"
            return !preferred.hasPrefix("zh")
        }
    }
}

/// 按当前界面语言在中英文之间选一个。文案在调用处按需求值，切换语言后下次显示即生效。
func L(_ zh: String, _ en: String) -> String {
    L10n.isEnglish ? en : zh
}
