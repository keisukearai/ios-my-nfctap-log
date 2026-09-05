#if DEBUG
import Foundation
import SwiftData

/// App Store 用のスクリーンショットを simctl だけで撮るための起動引数。
/// ホーム以外の画面はタップ遷移が必要で simctl からは触れないため、
/// `-screen detail` のように渡された画面を起動直後に表示する。Release ビルドには含まれない。
enum ScreenshotMode {
    enum Screen: String {
        /// タグ詳細（履歴）を push する
        case detail
        /// 設定を push する
        case settings
        /// 「記録しました」の結果シートを出す
        case scan
    }

    static var screen: Screen? {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-screen"), i + 1 < args.count else { return nil }
        return Screen(rawValue: args[i + 1])
    }

    /// 詳細・結果シートで使うタグ。記録が一番多いものを選ぶ。
    static func featuredTag(in context: ModelContext) -> TagItem? {
        let tags = (try? context.fetch(FetchDescriptor<TagItem>())) ?? []
        return tags.max { $0.entries.count < $1.entries.count }
    }
}
#endif
