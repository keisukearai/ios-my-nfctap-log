#!/bin/bash
# App Store 用スクリーンショットを iOS Simulator から撮る。
# App Store Connect が受け付けるのは 6.5インチ枠の 1284x2778（iPhone 14 Plus）。
# 別の機種で撮るときは DEVICE を渡す:  DEVICE="iPhone 17 Pro Max" bash Tools/CaptureScreenshots.sh
#
#   bash Tools/CaptureScreenshots.sh
#
# 出力: screenshots/{ja,en-US}/*.jpg
set -euo pipefail

cd "$(dirname "$0")/.."
DEVICE="${DEVICE:-Shot-6.5}"
BUNDLE_ID="com.keisukearai.MyNfcTapLog"
DERIVED="$(pwd)/.build/screenshots"
OUT="$(pwd)/screenshots"

find_udid() { xcrun simctl list devices available | awk -F '[()]' "/^ *$DEVICE \(/ {print \$2; exit}"; }

UDID=$(find_udid)
if [ -z "$UDID" ] && [ "$DEVICE" = "Shot-6.5" ]; then
  # 1284x2778 で撮れる機種。Xcode の標準構成には無いので必要なら作る。
  RUNTIME=$(xcrun simctl list runtimes | awk '/iOS/ {print $NF; exit}')
  xcrun simctl create "Shot-6.5" com.apple.CoreSimulator.SimDeviceType.iPhone-14-Plus "$RUNTIME" >/dev/null
  UDID=$(find_udid)
fi
[ -n "$UDID" ] || { echo "simulator not found: $DEVICE" >&2; exit 1; }

echo "==> build"
xcodebuild -project MyNfcTapLog.xcodeproj -scheme MyNfcTapLog \
  -destination "id=$UDID" -configuration Debug \
  -derivedDataPath "$DERIVED" CODE_SIGNING_ALLOWED=NO build >/dev/null

APP="$DERIVED/Build/Products/Debug-iphonesimulator/MyNfcTapLog.app"

echo "==> boot $DEVICE"
xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" -b >/dev/null
xcrun simctl install "$UDID" "$APP"
# ステータスバーを固定（実時間・電池残量が写り込まないように）
xcrun simctl status_bar "$UDID" override --time "9:41" \
  --cellularMode active --cellularBars 4 --wifiMode active --wifiBars 3 \
  --batteryState discharging --batteryLevel 100

shot() { # $1=lang $2=出力名 $3...=追加の起動引数
  local lang="$1" name="$2"; shift 2
  local dir="$OUT/$lang"
  mkdir -p "$dir"
  xcrun simctl terminate "$UDID" "$BUNDLE_ID" 2>/dev/null || true
  xcrun simctl launch "$UDID" "$BUNDLE_ID" -appLanguage "${lang%%-*}" "$@" >/dev/null
  sleep 4
  xcrun simctl io "$UDID" screenshot --type=png "$dir/$name.png" >/dev/null 2>&1
  # App Store はアルファ付き PNG を弾くため JPEG に変換する
  sips -s format jpeg -s formatOptions 95 "$dir/$name.png" --out "$dir/$name.jpg" >/dev/null
  rm -f "$dir/$name.png"
  echo "  $lang/$name.jpg"
}

for lang in ja en-US; do
  echo "==> $lang"
  # 記録済みデータを消してから、空のホーム（使い始めの画面）を撮る
  xcrun simctl uninstall "$UDID" "$BUNDLE_ID" >/dev/null
  xcrun simctl install "$UDID" "$APP"
  shot "$lang" 5_empty
  shot "$lang" 1_home     -seedSampleData
  shot "$lang" 2_scan     -seedSampleData -screen scan
  shot "$lang" 3_detail   -seedSampleData -screen detail
  shot "$lang" 4_settings -seedSampleData -screen settings
done

xcrun simctl terminate "$UDID" "$BUNDLE_ID" 2>/dev/null || true
echo "done: $OUT"
