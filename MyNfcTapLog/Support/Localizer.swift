import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case ja
    case en

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .ja: "日本語"
        case .en: "English"
        }
    }

    /// 日付フォーマットに使うロケール。端末の 12/24 時間設定に引きずられないよう固定 ID を使う。
    var locale: Locale {
        switch self {
        case .ja: Locale(identifier: "ja_JP")
        case .en: Locale(identifier: "en_US")
        }
    }

    static var systemDefault: AppLanguage {
        (Locale.preferredLanguages.first ?? "en").hasPrefix("ja") ? .ja : .en
    }
}

/// アプリ内で言語を切り替えるための文言解決。
///
/// SwiftUI の `Text(LocalizedStringKey)` は端末の言語設定を見るため、設定画面での切り替えを
/// 即座に反映させるには参照する Bundle を自分で差し替える必要がある。String Catalog
/// (`Localizable.xcstrings`) はビルド時に `ja.lproj` / `en.lproj` の .strings に展開されるので、
/// 該当 lproj の Bundle を直接引くことで実現している。
/// 言語を増やすときは `AppLanguage` に case を足し、xcstrings に訳を足すだけでよい。
@Observable
final class Localizer {
    private static let storageKey = "appLanguage"

    var language: AppLanguage {
        didSet { UserDefaults.standard.set(language.rawValue, forKey: Self.storageKey) }
    }

    init() {
        let saved = UserDefaults.standard.string(forKey: Self.storageKey)
        language = saved.flatMap(AppLanguage.init(rawValue:)) ?? .systemDefault
    }

    private var bundle: Bundle {
        guard let path = Bundle.main.path(forResource: language.rawValue, ofType: "lproj"),
              let bundle = Bundle(path: path)
        else { return .main }
        return bundle
    }

    /// 引数なしのときは String(format:) を通さない。文言に含まれる `%` を壊さないため。
    func t(_ key: String, _ args: CVarArg...) -> String {
        let raw = bundle.localizedString(forKey: key, value: key, table: nil)
        guard !args.isEmpty else { return raw }
        return String(format: raw, locale: language.locale, arguments: args)
    }
}
