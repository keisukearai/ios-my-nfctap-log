import SwiftUI

/// スキャン後のフィードバック。成功・未登録・失敗をひとつのボトムシートで扱う。
struct ScanResultSheet: View {
    let outcome: ScanCoordinator.Outcome
    let onRegister: (String) -> Void
    let onRetry: () -> Void
    let onClose: () -> Void

    @Environment(Localizer.self) private var loc

    @State private var contentHeight: CGFloat = 320

    private var format: AppFormat { AppFormat(loc: loc) }

    var body: some View {
        VStack(spacing: 14) {
            Text(mark)
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 46, height: 46)
                .background(accent, in: Circle())

            Text(title)
                .font(.system(size: 21, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.center)

            Text(message)
                .font(.system(size: 14))
                .lineSpacing(7)
                .foregroundStyle(Theme.textSheetBody)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 292)

            if let note {
                Text(note)
                    .font(Theme.mono(12))
                    .kerning(0.4)
                    .foregroundStyle(Theme.textCaption)
            }

            VStack(spacing: 6) {
                if let cta {
                    Button(action: cta.action) {
                        Text(cta.title)
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .background(Theme.accent, in: Capsule())
                    }
                }

                Button(action: onClose) {
                    Text(loc.t("scan.close"))
                        .font(.system(size: 16))
                        .foregroundStyle(Theme.accent)
                        .frame(maxWidth: .infinity, minHeight: 48)
                }
            }
            .padding(.top, 8)
        }
        .padding(.horizontal, 24)
        .padding(.top, 26)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity)
        .background(Theme.card)
        // 文言の行数が言語と状態で変わるため、実際の高さを測ってシートを合わせる。
        // ホームインジケータぶん（34pt）は detent の内側に入るので足しておく。
        .background(
            GeometryReader { proxy in
                Color.clear.preference(key: SheetHeightKey.self, value: proxy.size.height)
            }
        )
        .onPreferenceChange(SheetHeightKey.self) { contentHeight = $0 }
        .presentationDetents([.height(contentHeight + 34)])
        .presentationBackground(Theme.card)
        .presentationCornerRadius(22)
        .presentationDragIndicator(.hidden)
    }

    // MARK: - 状態ごとの中身

    private var accent: Color {
        switch outcome {
        case .logged, .registered: Theme.success
        case .unknown, .alreadyRegistered: Theme.warning
        case .failed, .unavailable: Theme.danger
        }
    }

    private var mark: String {
        switch outcome {
        case .logged, .registered: "✓"
        case .unknown, .alreadyRegistered: "?"
        case .failed, .unavailable: "!"
        }
    }

    private var title: String {
        switch outcome {
        case .logged: loc.t("scan.ok.title")
        case .registered: loc.t("scan.registered.title")
        case .unknown: loc.t("scan.unknown.title")
        case .alreadyRegistered: loc.t("scan.already.title")
        case .failed: loc.t("scan.fail.title")
        case .unavailable: loc.t("scan.unavailable.title")
        }
    }

    private var message: String {
        switch outcome {
        case .logged(let label, let at, _): loc.t("scan.ok.body", label, format.dateTime(at))
        case .registered: loc.t("scan.registered.body")
        case .unknown: loc.t("scan.unknown.body")
        case .alreadyRegistered: loc.t("scan.already.body")
        case .failed: loc.t("scan.fail.body")
        case .unavailable: loc.t("scan.unavailable.body")
        }
    }

    private var note: String? {
        switch outcome {
        case .logged(_, _, let count): loc.t("scan.ok.note", count)
        case .unknown(let uid): uid
        default: nil
        }
    }

    private var cta: (title: String, action: () -> Void)? {
        switch outcome {
        case .unknown(let uid): (loc.t("scan.unknown.cta"), { onRegister(uid) })
        case .failed: (loc.t("scan.fail.cta"), onRetry)
        default: nil
        }
    }
}

private struct SheetHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 320
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
