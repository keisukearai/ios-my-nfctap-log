import SwiftUI

/// デザインで使われているタグ形のアイコン（45度回転した角丸四角＋穴）。
struct TagGlyph: View {
    var size: CGFloat
    var fill: Color
    var hole: Color
    var dashed: Bool = false

    var body: some View {
        Group {
            if dashed {
                RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                    .strokeBorder(fill, style: StrokeStyle(lineWidth: 2, dash: [4, 3]))
            } else {
                RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                    .fill(fill)
            }
        }
        .frame(width: size, height: size)
        .overlay(alignment: .topLeading) {
            Group {
                if dashed {
                    Circle().strokeBorder(fill, style: StrokeStyle(lineWidth: 2, dash: [2, 2]))
                } else {
                    Circle().fill(hole)
                }
            }
            .frame(width: size * 0.26, height: size * 0.26)
            .padding(size * 0.17)
        }
        .rotationEffect(.degrees(45))
    }
}

/// 設定への導線に付いている、輪郭の円＋中心の点。
struct SettingsGlyph: View {
    var size: CGFloat = 15

    var body: some View {
        Circle()
            .strokeBorder(Theme.accent, lineWidth: 1.5)
            .frame(width: size, height: size)
            .overlay {
                Circle()
                    .fill(Theme.accent)
                    .frame(width: size * 0.27, height: size * 0.27)
            }
    }
}
