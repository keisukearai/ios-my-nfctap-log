import Foundation
import Testing
@testable import MyNfcTapLog

@Suite("経過時間の表示")
struct ElapsedFormatTests {
    private func elapsed(_ language: AppLanguage, hoursAgo: Double) -> String {
        let format = AppFormat(loc: TestSupport.localizer(language))
        let now = TestSupport.date(2026, 9, 4, 9, 41)
        return format.elapsed(since: now.addingTimeInterval(-hoursAgo * 3600), now: now)
    }

    @Test("日と時間の両方があれば2段で出す")
    func dayAndHour() {
        #expect(elapsed(.ja, hoursAgo: 74) == "3日 2時間")
        #expect(elapsed(.en, hoursAgo: 74) == "3d 2h")
        #expect(elapsed(.ja, hoursAgo: 36) == "1日 12時間")
    }

    @Test("時間の端数が無ければ日だけにする")
    func exactDays() {
        #expect(elapsed(.ja, hoursAgo: 48) == "2日")
        #expect(elapsed(.en, hoursAgo: 48) == "2d")
        #expect(elapsed(.ja, hoursAgo: 24) == "1日")
    }

    @Test("24時間未満は時間だけにする")
    func hoursOnly() {
        #expect(elapsed(.ja, hoursAgo: 11) == "11時間")
        #expect(elapsed(.en, hoursAgo: 11) == "11h")
        #expect(elapsed(.ja, hoursAgo: 23.9) == "23時間")
    }

    @Test("1時間未満は分にする")
    func minutes() {
        #expect(elapsed(.ja, hoursAgo: 1.0 / 60 * 30) == "30分")
        #expect(elapsed(.en, hoursAgo: 1.0 / 60 * 30) == "30m")
    }

    @Test("1分未満は「たった今」")
    func justNow() {
        #expect(elapsed(.ja, hoursAgo: 0) == "たった今")
        #expect(elapsed(.ja, hoursAgo: 59.0 / 3600) == "たった今")
        #expect(elapsed(.en, hoursAgo: 0) == "Just now")
    }

    @Test("ちょうど1分・1時間・1日の境界")
    func boundaries() {
        #expect(elapsed(.ja, hoursAgo: 60.0 / 3600) == "1分")
        #expect(elapsed(.ja, hoursAgo: 1) == "1時間")
        #expect(elapsed(.ja, hoursAgo: 24) == "1日")
    }

    @Test("記録が未来でも負の経過時間を出さない")
    func futureTimestampIsClamped() {
        #expect(elapsed(.ja, hoursAgo: -5) == "たった今")
    }
}

@Suite("日時の表示")
struct DateFormatTests {
    private let sample = TestSupport.date(2026, 8, 31, 7, 41)
    private let evening = TestSupport.date(2026, 9, 1, 21, 41)

    @Test("日本語は「yyyy/MM/dd H:mm」")
    func japanese() {
        let format = AppFormat(loc: TestSupport.localizer(.ja))
        #expect(format.dateTime(sample) == "2026/08/31 7:41")
        #expect(format.date(sample) == "2026/08/31")
        #expect(format.time(sample) == "7:41")
    }

    @Test("英語は「MM/dd/yyyy H:mm」")
    func english() {
        let format = AppFormat(loc: TestSupport.localizer(.en))
        #expect(format.dateTime(sample) == "08/31/2026 7:41")
        #expect(format.date(sample) == "08/31/2026")
        #expect(format.time(sample) == "7:41")
    }

    @Test("日本語・英語以外は「dd/MM/yyyy」")
    func others() {
        #expect(AppFormat(loc: TestSupport.localizer(.zhHans)).date(sample) == "2026/08/31")
        #expect(AppFormat(loc: TestSupport.localizer(.es)).date(sample) == "31/08/2026")
        #expect(AppFormat(loc: TestSupport.localizer(.hi)).date(sample) == "31/08/2026")
        #expect(AppFormat(loc: TestSupport.localizer(.ar)).date(sample) == "31/08/2026")
    }

    @Test("午後も24時間表記のまま（端末の12時間設定に引きずられない）")
    func twentyFourHourClock() {
        #expect(AppFormat(loc: TestSupport.localizer(.ja)).time(evening) == "21:41")
        #expect(AppFormat(loc: TestSupport.localizer(.en)).time(evening) == "21:41")
    }

    @Test("言語を切り替えると同じ日付の表記も変わる")
    func switchingLanguageChangesOutput() {
        let loc = TestSupport.localizer(.ja)
        let format = AppFormat(loc: loc)
        #expect(format.dateTime(sample) == "2026/08/31 7:41")

        loc.selection = .en
        #expect(AppFormat(loc: loc).dateTime(sample) == "08/31/2026 7:41")
    }
}
