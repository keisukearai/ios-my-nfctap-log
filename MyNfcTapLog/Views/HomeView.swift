import SwiftData
import SwiftUI

struct HomeView: View {
    @Environment(Localizer.self) private var loc
    @Environment(ScanCoordinator.self) private var scan
    @Environment(\.modelContext) private var context

    @Query private var tags: [TagItem]

    private var format: AppFormat { AppFormat(loc: loc) }

    /// 最後のタップが古い順・未記録が最上位。
    /// SwiftData の @Query は「最後の記録日時」のような派生値でソートできないため Swift 側で並べる。
    /// タグは数十件を想定しているのでコストは問題にならない。
    private var sortedTags: [TagItem] { TagOrdering.forHome(tags) }

    var body: some View {
        VStack(spacing: 0) {
            header

            if tags.isEmpty {
                emptyState
            } else {
                subheader
                list
            }

            bottomBar
        }
        .background(Theme.background)
        .navigationTitle(loc.t("nav.backHome"))
        .toolbar(.hidden, for: .navigationBar)
    }

    private var header: some View {
        HStack(alignment: .bottom) {
            Text(loc.t("home.title"))
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(Theme.textPrimary)

            Spacer()

            NavigationLink {
                SettingsView()
            } label: {
                HStack(spacing: 7) {
                    SettingsGlyph()
                    Text(loc.t("settings.title"))
                        .font(.system(size: 15))
                }
                .foregroundStyle(Theme.accent)
                .frame(minHeight: 44)
                .padding(.bottom, 4)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 12)
    }

    private var subheader: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(loc.t("home.registered", tags.count))
            Text("·").foregroundStyle(Theme.pagerDisabled)
            Text(loc.t("home.sortNote"))
            Spacer()
        }
        .font(.system(size: 12))
        .foregroundStyle(Theme.textCaption)
        .padding(.horizontal, 20)
        .padding(.bottom, 10)
    }

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(sortedTags) { tag in
                    NavigationLink {
                        TagDetailView(tag: tag)
                    } label: {
                        TagCard(tag: tag, format: format)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 20)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 18) {
            Spacer()
            TagGlyph(size: 54, fill: Theme.dashedIcon, hole: .clear, dashed: true)
                .padding(.bottom, 10)
            Text(loc.t("home.emptyTitle"))
                .font(.system(size: 19, weight: .medium))
                .foregroundStyle(Theme.textEmptyTitle)
            Text(loc.t("home.emptyBody"))
                .font(.system(size: 14))
                .lineSpacing(6)
                .foregroundStyle(Theme.textEmptyBody)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 268)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 40)
    }

    private var bottomBar: some View {
        VStack(spacing: 12) {
            Divider().overlay(Theme.divider)

            Button {
                Task { await scan.scanToLog(context: context, loc: loc) }
            } label: {
                HStack(spacing: 12) {
                    TagGlyph(size: 19, fill: .white.opacity(0.92), hole: Theme.accent)
                    Text(loc.t(tags.isEmpty ? "home.emptyCta" : "home.scan"))
                        .font(.system(size: 17, weight: .medium))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(Theme.accent, in: Capsule())
            }
            .disabled(scan.isScanning)
            .padding(.horizontal, 16)
            .padding(.top, 12)

            if tags.isEmpty {
                Text(loc.t("home.emptyHint"))
                    .font(.system(size: 11))
                    .lineSpacing(5)
                    .foregroundStyle(Theme.textFaint)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
        }
        .padding(.bottom, 6)
    }
}

private struct TagCard: View {
    let tag: TagItem
    let format: AppFormat

    @Environment(Localizer.self) private var loc

    private var isUnlogged: Bool { tag.lastLoggedAt == nil }

    var body: some View {
        VStack(spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(tag.isUnnamed ? loc.t("tag.unnamed") : tag.label)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(tag.isUnnamed ? Theme.unnamedLabel : Theme.textPrimary)

                Spacer(minLength: 12)

                Text(elapsedText)
                    .font(Theme.monoDigit(isUnlogged ? 15 : 20, .medium))
                    .foregroundStyle(elapsedColor)
            }

            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(tag.uid)
                    .font(Theme.mono(11))
                    .kerning(0.4)
                    .foregroundStyle(Theme.uid)

                Spacer(minLength: 12)

                Text(lastAtText)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textFaint)
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 18)
        .frame(minHeight: 44)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Theme.cardBorder, lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.03), radius: 1, y: 1)
    }

    private var elapsedText: String {
        guard let last = tag.lastLoggedAt else { return loc.t("tag.noTaps") }
        return format.elapsed(since: last)
    }

    private var lastAtText: String {
        guard let last = tag.lastLoggedAt else { return loc.t("tag.registeredOnly") }
        return format.dateTime(last)
    }

    private var elapsedColor: Color {
        if tag.isOverdue() { return Theme.danger }
        return isUnlogged ? Theme.uid : Theme.textElapsed
    }
}
