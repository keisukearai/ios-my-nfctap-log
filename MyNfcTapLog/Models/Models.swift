import Foundation
import SwiftData

@Model
final class TagItem {
    /// タグの UID（`04:8A:2F:1C:63:B7:80` 形式）。同じタグを二重登録させないため一意。
    @Attribute(.unique) var uid: String
    /// 空文字を許容する。登録時は名前を付けず、後から設定画面で変更する設計のため。
    var label: String
    var createdAt: Date
    /// 経過の警告の閾値（時間）。0 = 警告なし。
    var thresholdHours: Int

    @Relationship(deleteRule: .cascade, inverse: \LogEntry.tag)
    var entries: [LogEntry] = []

    init(uid: String, label: String = "", createdAt: Date = .now, thresholdHours: Int = 0) {
        self.uid = uid
        self.label = label
        self.createdAt = createdAt
        self.thresholdHours = thresholdHours
    }

    var lastLoggedAt: Date? {
        entries.max(by: { $0.timestamp < $1.timestamp })?.timestamp
    }

    var isUnnamed: Bool {
        label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// 閾値を超えているか。未記録のタグは警告の対象外（デザインの `over` 判定に合わせる）。
    func isOverdue(now: Date = .now) -> Bool {
        guard thresholdHours > 0, let last = lastLoggedAt else { return false }
        return now.timeIntervalSince(last) >= Double(thresholdHours) * 3600
    }

    /// ホームの並び順（最後のタップが古い順・未記録が最上位）に使うキー。
    var sortKey: Date {
        lastLoggedAt ?? .distantPast
    }
}

@Model
final class LogEntry {
    var timestamp: Date
    var tag: TagItem?

    init(timestamp: Date = .now, tag: TagItem? = nil) {
        self.timestamp = timestamp
        self.tag = tag
    }
}

/// 経過の警告の選択肢。デザインの THRESHOLDS と一致させている。
enum ThresholdOption: Int, CaseIterable, Identifiable {
    case off = 0
    case h12 = 12
    case d1 = 24
    case d3 = 72
    case w1 = 168

    var id: Int { rawValue }

    var key: String {
        switch self {
        case .off: "threshold.off"
        case .h12: "threshold.12h"
        case .d1: "threshold.1d"
        case .d3: "threshold.3d"
        case .w1: "threshold.1w"
        }
    }

    static func matching(_ hours: Int) -> ThresholdOption {
        ThresholdOption(rawValue: hours) ?? .off
    }
}
