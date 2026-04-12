import Foundation
import MorphoKit

/// 将 StatusEntry 中的语义键解析为本地化后的展示文本
enum StatusMessageLocalizer {
    static func localizedMessage(for entry: StatusEntry, locale: Locale) -> String {
        AppLocalization.format(entry.messageKey, locale: locale, arguments: entry.messageArguments)
    }
}
