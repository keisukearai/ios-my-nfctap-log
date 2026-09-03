import SwiftData
import SwiftUI

struct TagDetailView: View {
    let tag: TagItem

    @Environment(Localizer.self) private var loc
    @Environment(\.modelContext) private var context

    @State private var page = 0

    private var format: AppFormat { AppFormat(loc: loc) }

    private var entries: [LogEntry] {
        tag.entries.sorted { $0.timestamp > $1.timestamp }
    }

    private var pagination: Pagination {
        Pagination(total: entries.count, requestedPage: page)
    }

    private var pageEntries: [LogEntry] {
        Array(entries.dropFirst(pagination.startIndex).prefix(pagination.pageSize))
    }

    var body: some View {
        VStack(spacing: 0) {
            summary

            historyHeader

            if entries.isEmpty {
                emptyHistory
            } else {
                historyList
                pager
            }

            footer
        }
        .background(Theme.background)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(tag.isUnnamed ? loc.t("tag.unnamed") : tag.label)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(tag.isUnnamed ? Theme.unnamedLabel : Theme.textPrimary)

            Text(tag.uid)
                .font(Theme.mono(11))
                .kerning(0.4)
                .foregroundStyle(Theme.textFaint)

            HStack(alignment: .top, spacing: 28) {
                stat(loc.t("detail.elapsed"), elapsedText, color: elapsedColor)
                stat(loc.t("detail.entries"), "\(entries.count)", color: Theme.textPrimary)
            }
            .padding(.top, 6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 18)
        .overlay(alignment: .bottom) { Divider().overlay(Theme.divider) }
    }

    private func stat(_ title: String, _ value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 11))
                .foregroundStyle(Theme.textFaint)
            Text(value)
                .font(Theme.monoDigit(19, .medium))
                .foregroundStyle(color)
        }
    }

    private var historyHeader: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(loc.t("detail.history"))
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
            Spacer()
            Text(loc.t("detail.newestFirst"))
                .font(.system(size: 11))
                .foregroundStyle(Theme.textCaption)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    /// 削除だけを用意し、手動での記録追加はしない。記録は必ず NFC 経由にするため。
    private var historyList: some View {
        List {
            ForEach(pageEntries) { entry in
                HStack(alignment: .firstTextBaseline) {
                    Text(format.time(entry.timestamp))
                        .font(Theme.mono(15))
                        .foregroundStyle(Theme.textBody)
                    Spacer()
                    Text(format.date(entry.timestamp))
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textFaint)
                }
                .listRowInsets(EdgeInsets(top: 15, leading: 20, bottom: 15, trailing: 20))
                .listRowBackground(Theme.card)
                .listRowSeparatorTint(Theme.dividerLight)
                .swipeActions(edge: .trailing) {
                    Button(loc.t("common.delete"), role: .destructive) {
                        delete(entry)
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Theme.background)
    }

    private var pager: some View {
        HStack {
            Button {
                page = pagination.page - 1
            } label: {
                Text("‹ " + loc.t("page.prev"))
                    .font(.system(size: 15))
                    .frame(minHeight: 44)
            }
            .disabled(!pagination.hasPrevious)
            .foregroundStyle(pagination.hasPrevious ? Theme.accent : Theme.pagerDisabled)

            Spacer()

            VStack(spacing: 2) {
                Text(loc.t("page.label", pagination.page + 1, pagination.pageCount))
                    .font(Theme.monoDigit(13))
                    .foregroundStyle(Theme.textSecondary)
                Text(loc.t("page.range", pagination.startIndex + 1, pagination.startIndex + pagination.count, entries.count))
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textCaption)
            }

            Spacer()

            Button {
                page = pagination.page + 1
            } label: {
                Text(loc.t("page.next") + " ›")
                    .font(.system(size: 15))
                    .frame(minHeight: 44)
            }
            .disabled(!pagination.hasNext)
            .foregroundStyle(pagination.hasNext ? Theme.accent : Theme.pagerDisabled)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 10)
    }

    private var emptyHistory: some View {
        VStack(spacing: 8) {
            Spacer()
            Text(loc.t("detail.noLogTitle"))
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(Theme.textEmptyTitle)
            Text(loc.t("detail.noLogBody"))
                .font(.system(size: 13))
                .lineSpacing(5)
                .foregroundStyle(Theme.textEmptyBody)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 268)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 40)
    }

    private var footer: some View {
        Text(loc.t("detail.footer"))
            .font(.system(size: 11))
            .lineSpacing(5)
            .foregroundStyle(Theme.textCaption)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 4)
            .padding(.bottom, 24)
    }

    private var elapsedText: String {
        guard let last = tag.lastLoggedAt else { return loc.t("tag.noTaps") }
        return format.elapsed(since: last)
    }

    private var elapsedColor: Color {
        if tag.isOverdue() { return Theme.danger }
        return tag.lastLoggedAt == nil ? Theme.textFaint : Theme.textPrimary
    }

    private func delete(_ entry: LogEntry) {
        context.delete(entry)
        try? context.save()
        // 最終ページの最後の1件を消したときにページ番号が範囲外にならないようにする。
        page = Pagination(total: entries.count, requestedPage: page).page
    }
}
