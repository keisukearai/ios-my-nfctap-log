import Foundation
import SwiftData
import Testing
@testable import MyNfcTapLog

/// NFC そのものはシミュレータで動かせないため、UID を読んだ「あと」の分岐をテストする。
@Suite("スキャン後の処理")
@MainActor
struct ScanCoordinatorTests {
    @Test("登録済みタグを読むと1件記録される")
    func logsRegisteredTag() throws {
        let context = try TestSupport.makeContext()
        let loc = TestSupport.localizer(.ja)
        let coordinator = ScanCoordinator()
        let tag = TestSupport.makeTag(in: context, uid: "04:8A", label: "薬を飲む", logOffsetsInHours: [12])

        let outcome = coordinator.applyLog(uid: "04:8A", context: context, loc: loc)

        #expect(tag.entries.count == 2)
        guard case .logged(let label, _, let count) = outcome else {
            Issue.record("記録されるはずが \(outcome) だった")
            return
        }
        #expect(label == "薬を飲む")
        #expect(count == 2)
    }

    @Test("無名タグの記録では「新規タグ」と表示する")
    func unnamedTagUsesPlaceholderLabel() throws {
        let context = try TestSupport.makeContext()
        let coordinator = ScanCoordinator()
        TestSupport.makeTag(in: context, uid: "04:8A")

        let ja = coordinator.applyLog(uid: "04:8A", context: context, loc: TestSupport.localizer(.ja))
        guard case .logged(let jaLabel, _, _) = ja else {
            Issue.record("記録されるはずが \(ja) だった")
            return
        }
        #expect(jaLabel == "新規タグ")

        let en = coordinator.applyLog(uid: "04:8A", context: context, loc: TestSupport.localizer(.en))
        guard case .logged(let enLabel, _, _) = en else {
            Issue.record("記録されるはずが \(en) だった")
            return
        }
        #expect(enLabel == "New tag")
    }

    @Test("未登録タグを読んでも記録は増えない")
    func unknownTagIsNotLogged() throws {
        let context = try TestSupport.makeContext()
        let coordinator = ScanCoordinator()
        TestSupport.makeTag(in: context, uid: "04:8A", label: "薬を飲む")

        let outcome = coordinator.applyLog(uid: "04:FF", context: context, loc: TestSupport.localizer(.ja))

        guard case .unknown(let uid) = outcome else {
            Issue.record("未登録として扱われるはずが \(outcome) だった")
            return
        }
        #expect(uid == "04:FF")
        #expect(try context.fetchCount(FetchDescriptor<LogEntry>()) == 0)
    }

    @Test("読み取っただけでは登録せず、名前入力に回す")
    func registerWaitsForName() throws {
        let context = try TestSupport.makeContext()
        let coordinator = ScanCoordinator()

        let outcome = coordinator.applyRegister(uid: "04:9F", context: context)

        #expect(outcome == nil)
        #expect(coordinator.pendingRegistration == "04:9F")
        #expect(try context.fetchCount(FetchDescriptor<TagItem>()) == 0)
    }

    @Test("名前を入れて登録するとその名前で保存される")
    func commitWithName() throws {
        let context = try TestSupport.makeContext()
        let coordinator = ScanCoordinator()
        _ = coordinator.applyRegister(uid: "04:9F", context: context)

        let outcome = coordinator.commitRegistration(label: "  薬を飲む  ", context: context)

        guard case .registered = outcome else {
            Issue.record("登録されるはずが \(String(describing: outcome)) だった")
            return
        }
        let tags = try context.fetch(FetchDescriptor<TagItem>())
        #expect(tags.count == 1)
        #expect(tags[0].uid == "04:9F")
        #expect(tags[0].label == "薬を飲む")
        #expect(tags[0].thresholdHours == 0)
        #expect(coordinator.pendingRegistration == nil)
    }

    @Test("名前を空のまま登録すると無名タグになる")
    func commitWithoutName() throws {
        let context = try TestSupport.makeContext()
        let coordinator = ScanCoordinator()
        _ = coordinator.applyRegister(uid: "04:9F", context: context)

        _ = coordinator.commitRegistration(label: "   ", context: context)

        let tags = try context.fetch(FetchDescriptor<TagItem>())
        #expect(tags.count == 1)
        #expect(tags[0].isUnnamed)
    }

    @Test("名前入力をキャンセルすると何も登録されない")
    func cancelingRegistrationRegistersNothing() throws {
        let context = try TestSupport.makeContext()
        let coordinator = ScanCoordinator()
        _ = coordinator.applyRegister(uid: "04:9F", context: context)

        coordinator.pendingRegistration = nil

        #expect(coordinator.commitRegistration(label: "薬を飲む", context: context) == nil)
        #expect(try context.fetchCount(FetchDescriptor<TagItem>()) == 0)
    }

    @Test("同じタグを二重登録しない")
    func registeringTwiceIsRejected() throws {
        let context = try TestSupport.makeContext()
        let coordinator = ScanCoordinator()
        TestSupport.makeTag(in: context, uid: "04:9F", label: "水をやる")

        let outcome = coordinator.applyRegister(uid: "04:9F", context: context)

        guard case .alreadyRegistered? = outcome else {
            Issue.record("登録済みとして扱われるはずが \(String(describing: outcome)) だった")
            return
        }
        #expect(coordinator.pendingRegistration == nil)
        #expect(try context.fetchCount(FetchDescriptor<TagItem>()) == 1)
    }

    @Test("未登録タグを登録すると、次のスキャンから記録できる")
    func registerThenLog() throws {
        let context = try TestSupport.makeContext()
        let loc = TestSupport.localizer(.ja)
        let coordinator = ScanCoordinator()

        // 1回目：未登録
        guard case .unknown = coordinator.applyLog(uid: "04:9F", context: context, loc: loc) else {
            Issue.record("最初は未登録のはず")
            return
        }
        // シートの「このタグを登録」→ 名前入力アラートで「登録」を押した相当
        _ = coordinator.applyRegister(uid: "04:9F", context: context)
        _ = coordinator.commitRegistration(label: "", context: context)

        // 2回目：記録できる
        guard case .logged(_, _, let count) = coordinator.applyLog(uid: "04:9F", context: context, loc: loc) else {
            Issue.record("登録後は記録できるはず")
            return
        }
        #expect(count == 1)
    }

    @Test("UID でタグを引ける／無ければ nil")
    func findByUID() throws {
        let context = try TestSupport.makeContext()
        TestSupport.makeTag(in: context, uid: "04:8A:2F:1C:63:B7:80")

        #expect(ScanCoordinator.find(uid: "04:8A:2F:1C:63:B7:80", in: context) != nil)
        #expect(ScanCoordinator.find(uid: "04:8a:2f:1c:63:b7:80", in: context) == nil)
        #expect(ScanCoordinator.find(uid: "", in: context) == nil)
    }
}
