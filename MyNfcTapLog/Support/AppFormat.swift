import Foundation

/// デザインの表記に合わせた整形。
/// - 経過: `3日 2時間` / `11時間` / `3d 2h`（日と時間の2段階まで。分未満は「たった今」）
/// - 日時: `2026/08/31 7:41` / `08/31/2026 7:41`（今日・昨日という相対表記は使わない）
struct AppFormat {
    let loc: Localizer

    private static var cache: [String: DateFormatter] = [:]

    private func formatter(_ pattern: String) -> DateFormatter {
        let key = "\(loc.language.rawValue)|\(pattern)"
        if let cached = Self.cache[key] { return cached }
        let df = DateFormatter()
        df.locale = loc.language.locale
        df.dateFormat = pattern
        Self.cache[key] = df
        return df
    }

    private var dateTimePattern: String { "\(datePattern) H:mm" }

    private var datePattern: String { loc.language.datePattern }

    func dateTime(_ date: Date) -> String { formatter(dateTimePattern).string(from: date) }
    func date(_ date: Date) -> String { formatter(datePattern).string(from: date) }
    func time(_ date: Date) -> String { formatter("H:mm").string(from: date) }

    func elapsed(since date: Date, now: Date = .now) -> String {
        let seconds = max(0, Int(now.timeIntervalSince(date)))
        let minutes = seconds / 60
        let hours = minutes / 60
        let days = hours / 24

        if days >= 1 {
            let remainder = hours % 24
            return remainder > 0
                ? loc.t("elapsed.dayHour", days, remainder)
                : loc.t("elapsed.day", days)
        }
        if hours >= 1 { return loc.t("elapsed.hour", hours) }
        if minutes >= 1 { return loc.t("elapsed.minute", minutes) }
        return loc.t("elapsed.now")
    }
}
