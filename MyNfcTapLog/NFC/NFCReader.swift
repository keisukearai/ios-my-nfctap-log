import CoreNFC
import Foundation

/// `NFCTagReaderSession` でタグの UID だけを読む。タグへの書き込みは一切しない。
///
/// `NFCNDEFReaderSession` では UID が取れないため `NFCTagReaderSession` を使っている。
/// pollingOption は `.iso14443`（NTAG213/215 などの Type A）。FeliCa は別 entitlement が要るので対象外。
/// シミュレータでは `readingAvailable` が false になり、必ず `.unavailable` を返す。
final class NFCReader: NSObject {
    enum ReadError: Error {
        case unavailable
        case canceled
        case failed
    }

    private var session: NFCTagReaderSession?
    private var continuation: CheckedContinuation<String, Error>?

    func readUID(alertMessage: String) async throws -> String {
        guard NFCTagReaderSession.readingAvailable else { throw ReadError.unavailable }

        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            guard let session = NFCTagReaderSession(pollingOption: .iso14443, delegate: self, queue: nil) else {
                finish(.failure(ReadError.unavailable))
                return
            }
            session.alertMessage = alertMessage
            self.session = session
            session.begin()
        }
    }

    /// continuation は必ず1回だけ再開する。`invalidate()` を呼ぶと
    /// `didInvalidateWithError` が userCanceled で追って来るため、ここで握りつぶす。
    private func finish(_ result: Result<String, Error>) {
        guard let continuation else { return }
        self.continuation = nil
        continuation.resume(with: result)
    }

    static func identifier(of tag: NFCTag) -> Data? {
        switch tag {
        case .miFare(let tag): tag.identifier
        case .iso7816(let tag): tag.identifier
        case .iso15693(let tag): tag.identifier
        case .feliCa(let tag): tag.currentIDm
        @unknown default: nil
        }
    }

    /// `04:8A:2F:...` 形式。UID の表示とタグの同一判定の両方に使う。
    static func hex(_ data: Data) -> String {
        data.map { String(format: "%02X", $0) }.joined(separator: ":")
    }
}

extension NFCReader: NFCTagReaderSessionDelegate {
    func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {}

    func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: Error) {
        self.session = nil
        let code = (error as? NFCReaderError)?.code
        let isCancel = code == .readerSessionInvalidationErrorUserCanceled
        finish(.failure(isCancel ? ReadError.canceled : ReadError.failed))
    }

    func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
        guard let tag = tags.first else {
            session.invalidate(errorMessage: "")
            return
        }
        session.connect(to: tag) { [weak self] error in
            guard let self else { return }
            guard error == nil, let identifier = Self.identifier(of: tag), !identifier.isEmpty else {
                session.invalidate(errorMessage: "")
                return
            }
            // 成功のフィードバックは自前のシートで出すので、システム側のシートは黙って閉じる。
            finish(.success(Self.hex(identifier)))
            session.invalidate()
        }
    }
}
