import Foundation
import SwiftData
import Testing
@testable import MyNfcTapLog

@Suite("履歴のページ計算")
struct PaginationTests {
    @Test("120件は10件ずつで12ページ")
    func pageCountForFullPages() {
        let page = Pagination(total: 120, requestedPage: 0)
        #expect(page.pageCount == 12)
        #expect(page.startIndex == 0)
        #expect(page.count == 10)
        #expect(page.hasPrevious == false)
        #expect(page.hasNext == true)
    }

    @Test("端数があると最終ページだけ件数が減る")
    func lastPageIsPartial() {
        let page = Pagination(total: 21, requestedPage: 2)
        #expect(page.pageCount == 3)
        #expect(page.startIndex == 20)
        #expect(page.count == 1)
        #expect(page.hasNext == false)
    }

    @Test("0件でも1ページとして扱う")
    func emptyStillHasOnePage() {
        let page = Pagination(total: 0, requestedPage: 0)
        #expect(page.pageCount == 1)
        #expect(page.count == 0)
        #expect(page.hasPrevious == false)
        #expect(page.hasNext == false)
    }

    @Test("1ページに満たないと前後ともに移動できない")
    func singlePage() {
        let page = Pagination(total: 5, requestedPage: 0)
        #expect(page.pageCount == 1)
        #expect(page.count == 5)
        #expect(page.hasNext == false)
    }

    @Test("範囲外のページ番号は端に丸める")
    func outOfRangeIsClamped() {
        #expect(Pagination(total: 120, requestedPage: 99).page == 11)
        #expect(Pagination(total: 120, requestedPage: -3).page == 0)
    }

    @Test("削除で件数が減ったとき、現在ページが範囲外にならない")
    func clampsAfterDeletion() {
        // 11件のとき2ページ目（index 1）に1件だけある状態
        let before = Pagination(total: 11, requestedPage: 1)
        #expect(before.pageCount == 2)
        #expect(before.count == 1)

        // その1件を消すと1ページになり、ページ番号は0に戻る
        let after = Pagination(total: 10, requestedPage: 1)
        #expect(after.pageCount == 1)
        #expect(after.page == 0)
        #expect(after.count == 10)
    }

    @Test("ちょうど10の倍数でページが増えない")
    func exactMultipleBoundary() {
        #expect(Pagination(total: 10, requestedPage: 0).pageCount == 1)
        #expect(Pagination(total: 11, requestedPage: 0).pageCount == 2)
        #expect(Pagination(total: 20, requestedPage: 0).pageCount == 2)
    }
}

@Suite("ホームの並び順")
@MainActor
struct TagOrderingTests {
    @Test("最後のタップが古い順に並ぶ")
    func oldestTapFirst() throws {
        let context = try TestSupport.makeContext()
        let now = Date.now
        TestSupport.makeTag(in: context, uid: "A", label: "3時間前", logOffsetsInHours: [3], now: now)
        TestSupport.makeTag(in: context, uid: "B", label: "74時間前", logOffsetsInHours: [74], now: now)
        TestSupport.makeTag(in: context, uid: "C", label: "11時間前", logOffsetsInHours: [11], now: now)

        let tags = try context.fetch(FetchDescriptor<TagItem>())
        #expect(TagOrdering.forHome(tags).map(\.uid) == ["B", "C", "A"])
    }

    @Test("未記録のタグが最上位に来る")
    func unloggedComesFirst() throws {
        let context = try TestSupport.makeContext()
        let now = Date.now
        TestSupport.makeTag(in: context, uid: "A", logOffsetsInHours: [500], now: now)
        TestSupport.makeTag(in: context, uid: "B")

        let tags = try context.fetch(FetchDescriptor<TagItem>())
        #expect(TagOrdering.forHome(tags).first?.uid == "B")
    }

    @Test("未記録どうしは登録が早いほうが上（順序が揺れない）")
    func unloggedTagsAreStable() throws {
        let context = try TestSupport.makeContext()
        let base = TestSupport.date(2026, 9, 1)
        TestSupport.makeTag(in: context, uid: "後", createdAt: base.addingTimeInterval(60))
        TestSupport.makeTag(in: context, uid: "先", createdAt: base)

        let tags = try context.fetch(FetchDescriptor<TagItem>())
        #expect(TagOrdering.forHome(tags).map(\.uid) == ["先", "後"])
    }

    @Test("複数の記録があるタグは最新の記録で並ぶ")
    func usesLatestEntry() throws {
        let context = try TestSupport.makeContext()
        let now = Date.now
        // 古い記録も持つが、最新は1時間前なので下に来る
        TestSupport.makeTag(in: context, uid: "A", logOffsetsInHours: [1, 200, 400], now: now)
        TestSupport.makeTag(in: context, uid: "B", logOffsetsInHours: [50], now: now)

        let tags = try context.fetch(FetchDescriptor<TagItem>())
        #expect(TagOrdering.forHome(tags).map(\.uid) == ["B", "A"])
    }
}
