import Foundation

/// 界面语言：系统首选语言是中文时用中文，其余语言一律用英语。
/// Locale.preferredLanguages 已包含「系统设置 → 通用 → 语言与地区 → App」里的单独设置。
enum L10n {
    static let isChinese: Bool = {
        (Locale.preferredLanguages.first ?? "en").lowercased().hasPrefix("zh")
    }()
}

/// 按当前界面语言返回中文或英文文本。
func L(_ zh: String, _ en: String) -> String {
    L10n.isChinese ? zh : en
}
