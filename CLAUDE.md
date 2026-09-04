# MyNfcTapLog

NFC タグにかざして行動を記録する iPhone アプリ。

## 技術構成

- SwiftUI + SwiftData / **最低 iOS 17.0** / iPhone 専用（`TARGETED_DEVICE_FAMILY = 1`）
- サーバー不要・課金なし
- Bundle ID: `com.keisukearai.MyNfcTapLog` / Team: `HFZSU3MJLR`
- Xcode 26 の **file system synchronized group** 構成。`MyNfcTapLog/` 配下にファイルを置けば自動でターゲットに入る（pbxproj の編集は不要）

リポジトリ: `git@github.com:keisukearai/ios-my-nfctap-log.git`

## App Store Connect

新規 App 作成時の入力値。SKU は他プロジェクト（MyGeoWarp = `mygeowarp` / MyCropResize = `mycropresize`）と同じく、Bundle ID 末尾のアプリ名を全部小文字にして区切り文字なしで繋げる形式。

| 項目 | 値 |
|---|---|
| プラットフォーム | iOS |
| 名前 | MyNfcTapLog |
| プライマリ言語 | English |
| バンドル ID | `com.keisukearai.MyNfcTapLog` |
| SKU | `mynfctaplog` |

- **IAP の Product ID には英数字・ピリオド・アンダースコアしか使えない（ハイフン不可）**。過去に `com.keisukearai.my-fami-list.premium` が弾かれた実績あり。このアプリは課金なしなので現状は該当しない
- 2026-09-05 に App Store Connect へアプリ登録済み。メタデータ（テキスト）は fastlane で投入済み

### メタデータの投入（fastlane）

```bash
export PATH="/opt/homebrew/opt/ruby/bin:$PATH"
bundle exec fastlane upload_metadata --env local
```

- **`--env local` が必須**。これが無いと `fastlane/.env.local` が読まれず `No value found for 'key_id'` で落ちる
- `upload_metadata` レーンはテキストのみ。`skip_binary_upload` / `skip_screenshots` でバイナリとスクリーンショットには触らない
- 文言は `fastlane/metadata/{en-US,ja}/*.txt`。カテゴリは `fastlane/metadata/primary_category.txt`（`PRODUCTIVITY`）
- `fastlane/.env.local`（ASC API キー・審査連絡先）は **git 管理外**。MyCropResize から流用した。ASC の .p8 は `/Users/keisukearai/Downloads/AuthKey_6W3CF67B68.p8`
- 初回バージョンでは `release_notes` はスキップされる（「このバージョンの新機能」欄が存在しないため）。仕様どおり
- **審査連絡先の書き込みは `Error fetching app store review detail - No data` で失敗する**。App Store Connect 側に審査情報のレコードが未生成のため。バイナリを1本上げてから再実行するか、画面から手入力する（未検証）
- **サポートURL・プライバシーURLは空のまま**。審査提出前に埋める必要がある（他プロジェクトは `https://kotoragk.com/<sku>` 形式）
- Fastfile のレーンは `upload_metadata` のみ。ビルド・TestFlight・審査提出のレーンは未移植（MyGeoWarp の Fastfile に一式あるので必要になったら移植する）

## ビルド・実行

```bash
# テスト（65件）
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
- **登録時に名前を入力する（任意）**。読み取り成功の直後に名前入力アラート（`RootView` の `register.*`）を出す。空のまま登録すれば無名（`label = ""`）で、無名タグは「新規タグ」と表示。名前は設定画面で後から変更できる
- 名前入力アラートは設定の「タグをスキャンして登録」と、ホームのスキャン結果シートの「このタグを登録」の**両方**が通る。`ScanCoordinator.pendingRegistration` に UID を置き、アラートは `RootView` に1つだけ持つ
- SwiftUI の `.alert` はメッセージを入力欄の上に1つしか置けないため、本文・UID・注記の3行をまとめてメッセージにしている（デザインは注記が入力欄の下。合わせるなら自作シートが必要）
- **記録の削除のみ実装、手動追加はしない**。手動追加を入れると NFC が主役でなくなるため
- ホームの並び順は「最後のタップが古い順」、未記録は最上位。派生値のため `@Query` ではなく Swift 側でソート
- 経過の警告はタグごとの閾値（`thresholdHours`、0 = なし。選択肢は 12時間/1日/3日/1週間）
- 履歴は日付セクションを作らず、10件ごとのページングにする

## 多言語対応

- `MyNfcTapLog/Localizable.xcstrings`（String Catalog）に ja / en / zh-Hans / es / hi / ar の6言語を持つ
- **言語を足すときの手順**：`AppLanguage` に case を足す → xcstrings に訳を追加 → **pbxproj の `knownRegions` にも言語コードを足す**（これが無いと `.lproj` がビルドされず、文言がキーのまま出る）
- `AppLanguage.rawValue` が `.lproj` のディレクトリ名になる（簡体中文は `zh-Hans`）。`LocalizerTests.rawValuesMatchLprojNames` が実際に `.lproj` の存在を確かめている
- アラビア語は RTL。`layoutDirection` は端末の言語設定を見るため、`RootView` で `AppLanguage.isRightToLeft` を `.environment(\.layoutDirection, ...)` に流し込んで切り替えている
- アラビア語のロケールは `ar_SA@calendar=gregorian;numbers=latn`。素の `ar_SA` はヒジュラ暦・アラビア数字（٥٤٣）になり、等幅数字前提の表示と噛み合わないため明示的に固定している
- 日付パターンは `AppLanguage.datePattern`。区切りとゼロ埋めは全言語共通で、年月日の順だけ慣習に合わせる（ja / zh-Hans = `yyyy/MM/dd`、en = `MM/dd/yyyy`、es / hi / ar = `dd/MM/yyyy`）。`AppFormat` の日時は `datePattern + " H:mm"`
- 訳文に `\n` を入れると `Text` がそのまま改行する（`home.emptyBody` は1文目の後で改行する指定）
- アプリ内での即時切り替えのため、`Localizer` が選択言語の `.lproj` Bundle を直接引いている（`Text(LocalizedStringKey)` は端末設定を見るため使えない）
- **`Localizer.selection`（`AppLanguage?`）が選択、`Localizer.language` が解決結果**。`selection == nil` は端末の言語設定に追従する状態で、`language` は読み取り専用（`selection` に代入する）
- 保存キーは `appLanguage`。追従状態は `"system"` として保存する（`AppLanguage.rawValue` のどれとも衝突しない）。未保存も追従扱い
- `Localizer(defaults:)` で `UserDefaults` を差し替えられる。保存の往復を標準の保存領域を汚さずにテストするため
- 複数形は非対応。`Localizer` が `String(format:)` を使う構造上、String Catalog の複数形バリエーションが展開されない（`1 etiquetas` / `3 ساعة` のようになる。en の `1 tags` も同じ）
- 文言は `loc.t("key")` で取得する。`Text("...")` に日本語を直書きしない

## 見た目

- 配色は `Support/Theme.swift` に集約（Claude Design の oklch 値を sRGB hex に変換したもの）
- **デザインに暗色パレットが無いためライト固定**（`RootView` の `.preferredColorScheme(.light)`）
- 日本語混じりの数値は `Theme.monoDigit`（数字だけ等幅）、ASCII のみの UID・時刻は `Theme.mono`

## アプリアイコン

- `Tools/GenerateAppIcon.swift` で CoreGraphics から生成する。色や形を変えるときはこれを直す

```bash
swift Tools/GenerateAppIcon.swift MyNfcTapLog/Assets.xcassets/AppIcon.appiconset
```

- ライト / ダーク / ティントの3種を出力（Xcode 26 の AppIcon は3スロット構成）
- ティントは iOS が輝度に色を乗せるため、黒地に白のグレースケールで作っている
- 図案はアプリ内の `TagGlyph` と同じ「45度傾けたタグ＋吊り穴」に NFC の電波を足したもの

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
- **NFC 読み取りそのものはテストできない**。`ScanCoordinator.applyLog(uid:)` / `applyRegister(uid:)` /
  `commitRegistration(label:)` に UID を受け取った後の分岐を切り出してあるので、そこをテストする
- ビューのロジックは `Pagination` / `TagOrdering`（`Support/Ordering.swift`）に出してある。
  ページングや並び順を変えるときはビューではなくこちらを直す
- `LocalizerTests.noMissingTranslations` が画面で使うキーの訳漏れを検出する。
  **文言キーを増やしたらこの配列にも足すこと**

## 注意

- `MyNfcTapLog/Support/SampleData.swift` は `#if DEBUG` かつ起動引数 `-seedSampleData` 指定時のみ動く。Release には入らない
