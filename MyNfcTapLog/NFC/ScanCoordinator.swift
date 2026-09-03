import Foundation
import SwiftData

/// スキャンの入口。ホームからの「記録」と、設定からの「登録」の2系統を持つ。
/// 記録と登録を分けているのは、記録するつもりのスキャンで誤登録が起きないようにするため。
@MainActor
@Observable
final class ScanCoordinator {
    enum Outcome: Identifiable {
        case logged(label: String, at: Date, count: Int)
        case unknown(uid: String)
        case registered
        case alreadyRegistered
        case failed
        case unavailable

        var id: String {
            switch self {
            case .logged(_, let at, _): "logged-\(at.timeIntervalSince1970)"
            case .unknown(let uid): "unknown-\(uid)"
            case .registered: "registered"
            case .alreadyRegistered: "already"
            case .failed: "failed"
            case .unavailable: "unavailable"
            }
        }
    }

    var outcome: Outcome?
    private(set) var isScanning = false
    private let reader = NFCReader()

    /// ホームの「タグスキャン」。登録済みなら1件記録し、未登録なら結果シートで登録を促す。
    func scanToLog(context: ModelContext, loc: Localizer) async {
        guard let uid = await read(loc: loc) else { return }
        outcome = applyLog(uid: uid, context: context, loc: loc)
    }

    /// 設定の「タグをスキャンして登録」。名前は付けずに登録し、あとから設定で変更する。
    func scanToRegister(context: ModelContext, loc: Localizer) async {
        guard let uid = await read(loc: loc) else { return }
        outcome = applyRegister(uid: uid, context: context)
    }

    /// UID を読んだ後の処理。NFC に依存しないのでテストから直接呼べる。
    func applyLog(uid: String, context: ModelContext, loc: Localizer) -> Outcome {
        guard let tag = Self.find(uid: uid, in: context) else {
            return .unknown(uid: uid)
        }
        let entry = LogEntry(timestamp: .now, tag: tag)
        context.insert(entry)
        try? context.save()

        let name = tag.isUnnamed ? loc.t("tag.unnamed") : tag.label
        return .logged(label: name, at: entry.timestamp, count: tag.entries.count)
    }

    func applyRegister(uid: String, context: ModelContext) -> Outcome {
        guard Self.find(uid: uid, in: context) == nil else {
            return .alreadyRegistered
        }
        register(uid: uid, context: context)
        return .registered
    }

    func register(uid: String, context: ModelContext) {
        context.insert(TagItem(uid: uid))
        try? context.save()
    }

    /// 読み取り本体。ユーザーが自分でキャンセルしたときは何も出さない。
    private func read(loc: Localizer) async -> String? {
        guard !isScanning else { return nil }
        isScanning = true
        defer { isScanning = false }

        do {
            return try await reader.readUID(alertMessage: loc.t("home.scan"))
        } catch NFCReader.ReadError.canceled {
            return nil
        } catch NFCReader.ReadError.unavailable {
            outcome = .unavailable
            return nil
        } catch {
            outcome = .failed
            return nil
        }
    }

    static func find(uid: String, in context: ModelContext) -> TagItem? {
        let target = uid
        let descriptor = FetchDescriptor<TagItem>(predicate: #Predicate { $0.uid == target })
        return try? context.fetch(descriptor).first
    }
}
