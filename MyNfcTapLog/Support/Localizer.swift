import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case ja
    case en
    case zhHans = "zh-Hans"
    case es
    case hi
    case ar

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .ja: "日本語"
        case .en: "English"
        case .zhHans: "简体中文"
        case .es: "Español"
        case .hi: "हिन्दी"
        case .ar: "العربية"
        }
    }

    /// 日付フォーマットに使うロケール。端末の 12/24 時間設定に引きずられないよう固定 ID を使う。
    /// アラビア語は既定がヒジュラ暦・アラビア数字なので、他言語と同じ見た目になるよう
    /// グレゴリオ暦と算用数字を明示して固定する（UID や経過時間の等幅数字表示と揃えるため）。
    var locale: Locale {
        switch self {
        case .ja: Locale(identifier: "ja_JP")
        case .en: Locale(identifier: "en_US")
        case .zhHans: Locale(identifier: "zh_CN")
        case .es: Locale(identifier: "es_ES")
        case .hi: Locale(identifier: "hi_IN")
        case .ar: Locale(identifier: "ar_SA@calendar=gregorian;numbers=latn")
        }
    }

    /// 右から左に組む言語か。SwiftUI の `layoutDirection` は端末の言語設定を見るため、
    /// アプリ内での切り替えを反映させるにはこの値を環境に流し込む必要がある。
    var isRightToLeft: Bool { self == .ar }

    /// 日付の並び順。年・月・日の順序だけを言語の慣習に合わせ、区切りとゼロ埋めは全言語で揃える
    /// （デザインの `2026/09/03` / `09/03/2026` の表記に合わせたもの）。
    var datePattern: String {
        switch self {
        case .ja, .zhHans: "yyyy/MM/dd"
        case .en: "MM/dd/yyyy"
        case .es, .hi, .ar: "dd/MM/yyyy"
        }
    }

    /// `Locale.preferredLanguages` の先頭と突き合わせるための言語コード。
    private var languageCode: String {
        switch self {
        case .ja: "ja"
        case .en: "en"
        case .zhHans: "zh"
        case .es: "es"
        case .hi: "hi"
        case .ar: "ar"
        }
    }

    static var systemDefault: AppLanguage {
        let preferred = Locale.preferredLanguages.first ?? "en"
        return allCases.first { preferred.hasPrefix($0.languageCode) } ?? .en
    }
}

/// アプリ内で言語を切り替えるための文言解決。
///
/// SwiftUI の `Text(LocalizedStringKey)` は端末の言語設定を見るため、設定画面での切り替えを
/// 即座に反映させるには参照する Bundle を自分で差し替える必要がある。String Catalog
/// (`Localizable.xcstrings`) はビルド時に `ja.lproj` / `en.lproj` の .strings に展開されるので、
/// 該当 lproj の Bundle を直接引くことで実現している。
/// 言語を増やすときは `AppLanguage` に case を足し、xcstrings に訳を足したうえで、
/// pbxproj の `knownRegions` にも言語コードを足す（無いと .lproj がビルドされない）。
@Observable
final class Localizer {
    private static let storageKey = "appLanguage"
    /// 端末の言語設定に追従することを表す保存値。`AppLanguage.rawValue` のどれとも衝突しない。
    private static let systemValue = "system"

    @ObservationIgnored private let defaults: UserDefaults

    /// 設定画面で選んだ言語。nil は端末の言語設定に追従している状態。
    var selection: AppLanguage? {
        didSet { defaults.set(selection?.rawValue ?? Self.systemValue, forKey: Self.storageKey) }
    }

    /// 実際に文言と日付の解決に使う言語。
    var language: AppLanguage { selection ?? .systemDefault }

    /// `defaults` を差し替えられるのはテストのため。保存の往復を標準の UserDefaults を汚さずに確かめる。
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        // 未保存も "system" も追従として扱う。init 中の代入では didSet が走らないので保存もされない。
        selection = defaults.string(forKey: Self.storageKey).flatMap(AppLanguage.init(rawValue:))
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
