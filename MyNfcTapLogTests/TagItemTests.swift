import Foundation
import SwiftData
import Testing
@testable import MyNfcTapLog

@Suite("TagItem")
@MainActor
struct TagItemTests {
    @Test("名前が空か空白だけなら無名として扱う")
    func unnamedDetection() {
        #expect(TagItem(uid: "A", label: "").isUnnamed)
        #expect(TagItem(uid: "A", label: "   ").isUnnamed)
        #expect(TagItem(uid: "A", label: "\n").isUnnamed)
        #expect(TagItem(uid: "A", label: "薬を飲む").isUnnamed == false)
    }

    @Test("最後の記録は一番新しいものを返す")
    func lastLoggedAtPicksNewest() throws {
        let context = try TestSupport.makeContext()
        let now = TestSupport.date(2026, 9, 4, 9, 41)
        let tag = TestSupport.makeTag(in: context, uid: "A", logOffsetsInHours: [100, 3, 50], now: now)

        #expect(tag.lastLoggedAt == now.addingTimeInterval(-3 * 3600))
    }

    @Test("記録が無ければ nil、並び替えキーは distantPast")
    func unloggedTag() throws {
        let context = try TestSupport.makeContext()
        let tag = TestSupport.makeTag(in: context, uid: "A")

        #expect(tag.lastLoggedAt == nil)
        #expect(tag.sortKey == .distantPast)
    }

    @Test("閾値なし（0）はどれだけ経っても警告しない")
    func thresholdOffNeverWarns() throws {
        let context = try TestSupport.makeContext()
        let now = Date.now
        let tag = TestSupport.makeTag(in: context, uid: "A", thresholdHours: 0, logOffsetsInHours: [10_000], now: now)

        #expect(tag.isOverdue(now: now) == false)
    }

    @Test("未記録のタグは閾値があっても警告しない")
    func unloggedIsNeverOverdue() throws {
        let context = try TestSupport.makeContext()
        let tag = TestSupport.makeTag(in: context, uid: "A", thresholdHours: 12)

        #expect(tag.isOverdue() == false)
    }

    @Test("閾値ちょうどで警告に切り替わる")
    func overdueBoundary() throws {
        let context = try TestSupport.makeContext()
        let now = Date.now

        let justUnder = TestSupport.makeTag(in: context, uid: "A", thresholdHours: 72, logOffsetsInHours: [71.9], now: now)
        let exact = TestSupport.makeTag(in: context, uid: "B", thresholdHours: 72, logOffsetsInHours: [72], now: now)
        let over = TestSupport.makeTag(in: context, uid: "C", thresholdHours: 72, logOffsetsInHours: [74], now: now)

        #expect(justUnder.isOverdue(now: now) == false)
        #expect(exact.isOverdue(now: now) == true)
        #expect(over.isOverdue(now: now) == true)
    }

    @Test("タグを消すと紐づく記録も消える")
    func deletingTagCascadesToEntries() throws {
        let context = try TestSupport.makeContext()
        let tag = TestSupport.makeTag(in: context, uid: "A", logOffsetsInHours: [1, 2, 3])
        TestSupport.makeTag(in: context, uid: "B", logOffsetsInHours: [1])

        #expect(try context.fetchCount(FetchDescriptor<LogEntry>()) == 4)

        context.delete(tag)
        try context.save()

        // 残るのは B の1件だけ
        #expect(try context.fetchCount(FetchDescriptor<TagItem>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<LogEntry>()) == 1)
    }

    @Test("記録を1件消してもタグは残る")
    func deletingEntryKeepsTag() throws {
        let context = try TestSupport.makeContext()
        let tag = TestSupport.makeTag(in: context, uid: "A", logOffsetsInHours: [1, 2])

        context.delete(tag.entries[0])
        try context.save()

        #expect(try context.fetchCount(FetchDescriptor<TagItem>()) == 1)
        #expect(tag.entries.count == 1)
    }
}

@Suite("経過の警告の選択肢")
struct ThresholdOptionTests {
    @Test("デザインの選択肢と一致する")
    func matchesDesign() {
        #expect(ThresholdOption.allCases.map(\.rawValue) == [0, 12, 24, 72, 168])
    }

    @Test("保存値から選択肢を引ける")
    func matchingKnownValue() {
        #expect(ThresholdOption.matching(72) == .d3)
        #expect(ThresholdOption.matching(0) == .off)
    }

    @Test("選択肢に無い値は「なし」に落とす")
    func matchingUnknownValue() {
        #expect(ThresholdOption.matching(999) == .off)
        #expect(ThresholdOption.matching(-1) == .off)
    }
}
