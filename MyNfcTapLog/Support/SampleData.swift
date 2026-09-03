#if DEBUG
import Foundation
import SwiftData

/// シミュレータでは Core NFC が動かず、タグを1件も登録できない。
/// レイアウト確認のためだけに、起動引数 `-seedSampleData` を付けたときだけダミーを入れる。
/// Release ビルドには含まれない。
enum SampleData {
    static var isRequested: Bool {
        ProcessInfo.processInfo.arguments.contains("-seedSampleData")
    }

    static func seed(into context: ModelContext) {
        guard let existing = try? context.fetchCount(FetchDescriptor<TagItem>()), existing == 0 else { return }

        let now = Date.now
        // (uid, ラベル, 閾値, 最終記録からの経過時間, 記録件数, 記録の間隔)
        let specs: [(String, String, Int, Double, Int, Double)] = [
            ("04:2D:B1:48:F0:A2:80", "", 0, 0, 0, 0),
            ("04:8A:2F:1C:63:B7:80", "体重を測る", 72, 74, 42, 24),
            ("04:1B:77:D0:2A:5C:81", "水をやる", 168, 36, 18, 72),
            ("04:C4:09:65:81:3E:80", "薬を飲む", 24, 11, 120, 14),
            ("04:5E:33:A7:14:96:81", "ゴミを出す", 0, 3, 31, 48),
        ]

        for (index, spec) in specs.enumerated() {
            let (uid, label, threshold, back, count, step) = spec
            let tag = TagItem(
                uid: uid,
                label: label,
                createdAt: now.addingTimeInterval(-Double(specs.count - index) * 86_400),
                thresholdHours: threshold
            )
            context.insert(tag)

            for i in 0..<count {
                let at = now.addingTimeInterval(-(back + step * Double(i)) * 3600)
                context.insert(LogEntry(timestamp: at, tag: tag))
            }
        }
        try? context.save()
    }
}
#endif
