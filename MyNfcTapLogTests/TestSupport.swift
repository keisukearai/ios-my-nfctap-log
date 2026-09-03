import Foundation
import SwiftData
@testable import MyNfcTapLog

enum TestSupport {
    /// ディスクに書かないコンテナ。テストごとに作り直して状態を持ち越さない。
    @MainActor
    static func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: TagItem.self, LogEntry.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    static func localizer(_ language: AppLanguage) -> Localizer {
        let loc = Localizer()
        loc.language = language
        return loc
    }

    /// テスト内の日時はカレンダー経由で作る。DateFormatter と同じタイムゾーンで解釈させるため。
    static func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        return Calendar.current.date(from: components)!
    }

    @discardableResult
    static func makeTag(
        in context: ModelContext,
        uid: String,
        label: String = "",
        thresholdHours: Int = 0,
        createdAt: Date = .now,
        logOffsetsInHours: [Double] = [],
        now: Date = .now
    ) -> TagItem {
        let tag = TagItem(uid: uid, label: label, createdAt: createdAt, thresholdHours: thresholdHours)
        context.insert(tag)
        for hours in logOffsetsInHours {
            context.insert(LogEntry(timestamp: now.addingTimeInterval(-hours * 3600), tag: tag))
        }
        try? context.save()
        return tag
    }
}
