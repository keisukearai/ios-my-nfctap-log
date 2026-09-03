import SwiftUI

/// デザイン（Claude Design の .dc.html）で使われている oklch 値を sRGB hex に変換したもの。
/// デザイン側に暗色パレットが無いため、アプリはライト固定で表示する（RootView で .preferredColorScheme(.light)）。
enum Theme {
    // アクセント・状態色
    static let accent = Color(hex: 0x007781)
    static let accentPressed = Color(hex: 0x006670)
    static let danger = Color(hex: 0xBC4945)
    static let success = Color(hex: 0x258343)
    static let warning = Color(hex: 0xB67700)

    // 背景
    static let background = Color(hex: 0xFAF8F5)       // ホーム・タグ詳細
    static let groupedBackground = Color(hex: 0xF5F3EF) // 設定
    static let card = Color.white
    static let accordion = Color(hex: 0xF9F7F4)

    // 文字
    static let textPrimary = Color(hex: 0x211F1A)
    static let textBody = Color(hex: 0x26241F)
    static let textElapsed = Color(hex: 0x302D28)
    static let textEmptyTitle = Color(hex: 0x3A3832)
    static let textSecondary = Color(hex: 0x4A4742)
    static let textCaption = Color(hex: 0x7D7A74)
    static let textFaint = Color(hex: 0x83807A)
    static let textEmptyBody = Color(hex: 0x77746E)
    static let textSheetBody = Color(hex: 0x5B5852)
    static let uid = Color(hex: 0x95928B)
    static let unnamedLabel = Color(hex: 0x8F8C85)
    static let thresholdOff = Color(hex: 0xAEAAA4)
    static let chevron = Color(hex: 0xA7A49E)
    static let pagerDisabled = Color(hex: 0xC7C4BD)
    static let dashedIcon = Color(hex: 0xA9BBBD)

    // 罫線
    static let cardBorder = Color(hex: 0xE0DED8)
    static let divider = Color(hex: 0xE7E4DF)
    static let dividerLight = Color(hex: 0xF1EEE9)

    /// デザインの IBM Plex Mono に相当する等幅表示。数値の桁がそろうことが目的なので
    /// フォントを同梱せず、システムフォントの monospaced デザインで代替する。
    static func mono(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}

extension Theme {
    /// 日本語混じりの数値表示用。IBM Plex Mono は日本語グリフを持たないため、
    /// デザイン上も等幅になるのは数字だけ。漢字まで等幅にすると間延びするので桁揃えだけを行う。
    static func monoDigit(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight).monospacedDigit()
    }
}
