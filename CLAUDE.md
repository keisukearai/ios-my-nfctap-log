# MyNfcTapLog

NFC タグにかざして行動を記録する iPhone アプリ。

## 技術構成

- SwiftUI + SwiftData / **最低 iOS 17.0** / iPhone 専用（`TARGETED_DEVICE_FAMILY = 1`）
- サーバー不要・課金なし
- Bundle ID: `com.keisukearai.MyNfcTapLog` / Team: `HFZSU3MJLR`
- Xcode 26 の **file system synchronized group** 構成。`MyNfcTapLog/` 配下にファイルを置けば自動でターゲットに入る（pbxproj の編集は不要）

リポジトリ: `git@github.com:keisukearai/ios-my-nfctap-log.git`

## ビルド・実行

```bash
# テスト（53件）
xcodebuild test -project MyNfcTapLog.xcodeproj -scheme MyNfcTapLog \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'

# ビルド
xcodebuild -project MyNfcTapLog.xcodeproj -scheme MyNfcTapLog \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -configuration Debug build CODE_SIGNING_ALLOWED=NO

# シミュレータで起動（サンプルデータ付き）
xcrun simctl launch booted com.keisukearai.MyNfcTapLog -seedSampleData

# 英語で起動（UserDefaults の NSArgumentDomain を利用）
xcrun simctl launch booted com.keisukearai.MyNfcTapLog -seedSampleData -appLanguage en
```

## NFC

- `NFCTagReaderSession`（`pollingOption: .iso14443`）で **UID のみ** 読む。タグへの書き込みはしない
- `NFCNDEFReaderSession` では UID が取れないため使わない
- **Core NFC はシミュレータで一切動作しない。検証は実機（arai13 = iPhone 13）のみ**
- Capability「Near Field Communication Tag Reading」が必要。`MyNfcTapLog/MyNfcTapLog.entitlements` に `com.apple.developer.nfc.readersession.formats = [TAG]` を設定済み
- 利用目的文言は `INFOPLIST_KEY_NFCReaderUsageDescription`（Info.plist ファイルは無く、ビルド設定で生成）
- FeliCa（Suica 等）は別 entitlement が必要で対象外
- UID をランダム化するカード（一部の入館証）はタグとして使えない
- 金属面には耐金属（アンチメタル）タグが必要。厚いケースでは反応しないことがある

## 設計判断

- **登録と記録を分離**。ホームのスキャンで未登録タグを読んだ場合は結果シートで明示的に「このタグを登録」を押させる
- **登録時に名前は付けない**。無名（`label = ""`）で登録し、設定画面で後から変更する。無名タグは「新規タグ」と表示
- **記録の削除のみ実装、手動追加はしない**。手動追加を入れると NFC が主役でなくなるため
- ホームの並び順は「最後のタップが古い順」、未記録は最上位。派生値のため `@Query` ではなく Swift 側でソート
- 経過の警告はタグごとの閾値（`thresholdHours`、0 = なし。選択肢は 12時間/1日/3日/1週間）
- 履歴は日付セクションを作らず、10件ごとのページングにする

## 多言語対応

- `MyNfcTapLog/Localizable.xcstrings`（String Catalog）に ja / en を持つ。**言語を足すときは `AppLanguage` に case を足して xcstrings に訳を追加するだけ**
- アプリ内での即時切り替えのため、`Localizer` が選択言語の `.lproj` Bundle を直接引いている（`Text(LocalizedStringKey)` は端末設定を見るため使えない）
- 文言は `loc.t("key")` で取得する。`Text("...")` に日本語を直書きしない

## 見た目

- 配色は `Support/Theme.swift` に集約（Claude Design の oklch 値を sRGB hex に変換したもの）
- **デザインに暗色パレットが無いためライト固定**（`RootView` の `.preferredColorScheme(.light)`）
- 日本語混じりの数値は `Theme.monoDigit`（数字だけ等幅）、ASCII のみの UID・時刻は `Theme.mono`

## デザイン

Claude Design のキャンバスが唯一の UI 仕様。読むには `/design-login` が必要。

- projectId: `237ce546-40e9-4ff7-aeda-be60e8a4e74a`
- ファイル: `MyNfcTapLog レイアウト.dc.html`（7画面）
- 要件定義書: `/Users/keisukearai/workspace/ios/MyNfcTapLog-req1.md`
  - **req1.md より後にデザインで決まったことが優先**（多言語対応・経過の警告・登録フロー・履歴のページングは req1.md と食い違う）

## 未確認

- [ ] 実機での NFC 読み取り（未実施。シミュレータでは検証不可）
- [ ] 読み取り失敗時に、システムの NFC シートと自前の結果シートが二重表示にならないか
- [ ] タグ詳細・設定への遷移時、戻るボタンが「‹ タップ記録」と表示されるか（ホームはナビゲーションバーを隠しているため）
- [ ] 実機 arai13 の iOS バージョン

## テスト

- Swift Testing（`import Testing`）。ターゲット `MyNfcTapLogTests`（テストホスト = アプリ本体）
- SwiftData は `isStoredInMemoryOnly: true` のコンテナをテストごとに作り直す（`TestSupport.makeContext()`）
- **NFC 読み取りそのものはテストできない**。`ScanCoordinator.applyLog(uid:)` / `applyRegister(uid:)` に
  UID を受け取った後の分岐を切り出してあるので、そこをテストする
- ビューのロジックは `Pagination` / `TagOrdering`（`Support/Ordering.swift`）に出してある。
  ページングや並び順を変えるときはビューではなくこちらを直す
- `LocalizerTests.noMissingTranslations` が画面で使うキーの訳漏れを検出する。
  **文言キーを増やしたらこの配列にも足すこと**

## 注意

- `MyNfcTapLog/Support/SampleData.swift` は `#if DEBUG` かつ起動引数 `-seedSampleData` 指定時のみ動く。Release には入らない
