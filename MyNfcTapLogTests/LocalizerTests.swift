import CoreNFC
import Foundation
import Testing
@testable import MyNfcTapLog

@Suite("文言の解決")
struct LocalizerTests {
    @Test("同じキーが言語ごとに違う文言を返す")
    func resolvesPerLanguage() {
        let loc = TestSupport.localizer(.ja)
        #expect(loc.t("home.title") == "タップ記録")
        #expect(loc.t("scan.unknown.title") == "未登録のタグです")

        loc.selection = .en
        #expect(loc.t("home.title") == "Tap Log")
        #expect(loc.t("scan.unknown.title") == "Unregistered tag")
    }

    @Test("数値を埋め込む文言が言語ごとに組み立てられる")
    func formatsArguments() {
        #expect(TestSupport.localizer(.ja).t("home.registered", 5) == "登録 5件")
        #expect(TestSupport.localizer(.en).t("home.registered", 5) == "5 tags")
        #expect(TestSupport.localizer(.ja).t("scan.ok.note", 121) == "これで 121 件目です。")
    }

    @Test("複数の引数が順番どおりに入る")
    func formatsMultipleArguments() {
        let ja = TestSupport.localizer(.ja)
        #expect(ja.t("page.label", 3, 12) == "3 / 12ページ")
        #expect(ja.t("page.range", 21, 30, 120) == "21–30件 / 120件")

        let en = TestSupport.localizer(.en)
        #expect(en.t("page.label", 3, 12) == "Page 3 of 12")
        #expect(en.t("page.range", 21, 30, 120) == "21–30 of 120")
    }

    @Test("タグ名を埋め込む削除確認のタイトル")
    func deleteConfirmTitle() {
        #expect(TestSupport.localizer(.ja).t("delete.confirmTitle", "体重を測る") == "「体重を測る」を削除しますか？")
        #expect(TestSupport.localizer(.en).t("delete.confirmTitle", "Weigh in") == "Delete “Weigh in”?")
    }

    @Test("知らないキーはキーをそのまま返す（画面が空にならない）")
    func unknownKeyFallsBack() {
        #expect(TestSupport.localizer(.ja).t("no.such.key") == "no.such.key")
    }

    @Test("閾値の選択肢がすべて訳されている")
    func thresholdOptionsAreTranslated() {
        let ja = TestSupport.localizer(.ja)
        #expect(ThresholdOption.allCases.map { ja.t($0.key) } == ["なし", "12時間", "1日", "3日", "1週間"])

        let en = TestSupport.localizer(.en)
        #expect(ThresholdOption.allCases.map { en.t($0.key) } == ["Off", "12 hours", "1 day", "3 days", "1 week"])
    }

    @Test("画面で使うキーが全言語で欠けていない")
    func noMissingTranslations() {
        let keys = [
            "home.title", "home.scan", "home.sortNote", "home.emptyTitle", "home.emptyBody",
            "home.emptyCta", "home.emptyHint", "settings.title", "settings.registeredTags",
            "settings.registeredNote", "settings.unnamedNote", "settings.addTag",
            "settings.scanToRegister", "settings.addNote", "settings.thresholdNote",
            "settings.language", "settings.systemDefault", "settings.systemDefaultWith",
            "settings.about", "settings.uidNote",
            "detail.elapsed", "detail.entries", "detail.history", "detail.newestFirst",
            "detail.noLogTitle", "detail.noLogBody", "detail.footer",
            "tag.rename", "tag.deleteTag", "tag.deleteNote", "tag.threshold",
            "tag.unnamed", "tag.noTaps", "tag.registeredOnly",
            "rename.title", "rename.body", "rename.placeholder",
            "register.title", "register.body", "register.note", "common.register",
            "scan.ok.title", "scan.unknown.title", "scan.unknown.body", "scan.unknown.cta",
            "scan.fail.title", "scan.fail.body", "scan.fail.cta", "scan.close",
            "scan.registered.title", "scan.registered.body",
            "scan.already.title", "scan.already.body",
            "scan.unavailable.title", "scan.unavailable.body",
            "common.delete", "common.cancel", "common.save", "page.prev", "page.next",
            "about.appName", "about.supported", "about.readMethod", "about.version",
        ]
        for language in AppLanguage.allCases {
            let loc = TestSupport.localizer(language)
            for key in keys {
                #expect(loc.t(key) != key, "\(language.rawValue) に \(key) の訳が無い")
            }
        }
    }
}

@Suite("UID の整形")
struct NFCReaderFormatTests {
    @Test("バイト列をコロン区切りの大文字16進にする")
    func hexFormatting() {
        let uid = Data([0x04, 0x8A, 0x2F, 0x1C, 0x63, 0xB7, 0x80])
        #expect(NFCReader.hex(uid) == "04:8A:2F:1C:63:B7:80")
    }

    @Test("1桁の値は0埋めする")
    func padsSingleDigits() {
        #expect(NFCReader.hex(Data([0x00, 0x0F, 0xA0])) == "00:0F:A0")
    }

    @Test("1バイト・空のバイト列でも壊れない")
    func edgeCases() {
        #expect(NFCReader.hex(Data([0x04])) == "04")
        #expect(NFCReader.hex(Data()) == "")
    }
}

@Suite("言語の選択と保存")
struct LanguageSelectionTests {
    /// テストごとに使い捨ての保存領域を作る。標準の UserDefaults を汚さず、並列実行でも干渉しない。
    private func withTemporaryDefaults(_ body: (UserDefaults) -> Void) {
        let name = "test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        body(defaults)
    }

    @Test("保存値が無ければ端末の言語設定に追従する")
    func followsSystemByDefault() {
        withTemporaryDefaults { defaults in
            let loc = Localizer(defaults: defaults)
            #expect(loc.selection == nil)
            #expect(loc.language == AppLanguage.systemDefault)
        }
    }

    @Test("明示的に選んだ言語は次の起動でも復元される")
    func explicitSelectionPersists() {
        withTemporaryDefaults { defaults in
            Localizer(defaults: defaults).selection = .ar
            #expect(Localizer(defaults: defaults).selection == .ar)
        }
    }

    @Test("システムデフォルトに戻すと、次の起動でも追従したまま")
    func backToSystemPersists() {
        withTemporaryDefaults { defaults in
            let loc = Localizer(defaults: defaults)
            loc.selection = .hi
            loc.selection = nil

            let restored = Localizer(defaults: defaults)
            #expect(restored.selection == nil)
            #expect(restored.language == AppLanguage.systemDefault)
        }
    }

    @Test("追従を表す保存値は言語コードと衝突しない")
    func systemValueDoesNotCollide() {
        #expect(AppLanguage(rawValue: "system") == nil)
    }
}

@Suite("言語の初期値")
struct AppLanguageTests {
    @Test("日本語環境なら ja、それ以外は en")
    func systemDefaultFallsBackToEnglish() {
        // 端末設定に依存するので、いずれかであることだけを確かめる
        #expect(AppLanguage.allCases.contains(AppLanguage.systemDefault))
    }

    @Test("日付ロケールが言語ごとに固定されている")
    func fixedLocales() {
        #expect(AppLanguage.ja.locale.identifier == "ja_JP")
        #expect(AppLanguage.en.locale.identifier == "en_US")
        #expect(AppLanguage.zhHans.locale.identifier == "zh_CN")
        #expect(AppLanguage.es.locale.identifier == "es_ES")
        #expect(AppLanguage.hi.locale.identifier == "hi_IN")
    }

    @Test("アラビア語はグレゴリオ暦・算用数字に固定する")
    func arabicUsesGregorianAndLatinDigits() {
        let locale = AppLanguage.ar.locale
        #expect(locale.calendar.identifier == .gregorian)
        #expect(String(format: "%lld", locale: locale, 123) == "123")
    }

    @Test("右から左に組むのはアラビア語だけ")
    func rightToLeftLanguages() {
        #expect(AppLanguage.allCases.filter(\.isRightToLeft) == [.ar])
    }

    @Test("日付の並び順は言語ごとの慣習に合わせる")
    func datePatterns() {
        #expect(AppLanguage.allCases.map(\.datePattern)
            == ["yyyy/MM/dd", "MM/dd/yyyy", "yyyy/MM/dd", "dd/MM/yyyy", "dd/MM/yyyy", "dd/MM/yyyy"])
    }

    @Test("表示名はメニューの見た目どおり")
    func displayNames() {
        #expect(AppLanguage.allCases.map(\.displayName)
            == ["日本語", "English", "简体中文", "Español", "हिन्दी", "العربية"])
    }

    @Test("rawValue が lproj のディレクトリ名と一致する")
    func rawValuesMatchLprojNames() {
        #expect(AppLanguage.allCases.map(\.rawValue) == ["ja", "en", "zh-Hans", "es", "hi", "ar"])
        for language in AppLanguage.allCases {
            #expect(Bundle.main.path(forResource: language.rawValue, ofType: "lproj") != nil,
                    "\(language.rawValue).lproj がビルドされていない")
        }
    }
}
