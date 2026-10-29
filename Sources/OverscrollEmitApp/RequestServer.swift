import Foundation
import OverscrollEmitCore

/// Receives CLI requests over DistributedNotificationCenter and acks them.
/// The CLI re-posts until acked, so requests are deduped by id.
@MainActor
final class RequestServer {
    private static let rememberedIDCount = 64

    private let handler: @MainActor (AppCommand) -> String?
    private var recentIDs: [String] = []
    private var observer: NSObjectProtocol?

    init(handler: @escaping @MainActor (AppCommand) -> String?) {
        self.handler = handler
        observer = DistributedNotificationCenter.default().addObserver(
            forName: IPC.requestName, object: nil, queue: .main
        ) { [weak self] notification in
            let payload = notification.userInfo?[IPC.payloadKey] as? String
            MainActor.assumeIsolated { self?.receive(payload) }
        }
    }

    private func receive(_ payload: String?) {
        guard let envelope = payload.flatMap({ IPCCodec.decode(RequestEnvelope.self, from: $0) }) else {
            NSLog("overscroll-emit: ignoring malformed request: \(payload ?? "<nil>")")
            return
        }
        guard !recentIDs.contains(envelope.id) else {
            // Duplicate re-post: the previous ack may have been missed, so ack again without re-running.
            ack(AckEnvelope(id: envelope.id, error: nil))
            return
        }
        recentIDs = Array((recentIDs + [envelope.id]).suffix(Self.rememberedIDCount))
        ack(AckEnvelope(id: envelope.id, error: handler(envelope.command)))
    }

    private func ack(_ envelope: AckEnvelope) {
        guard let payload = IPCCodec.encode(envelope) else { return }
        DistributedNotificationCenter.default().postNotificationName(
            IPC.ackName, object: nil, userInfo: [IPC.payloadKey: payload], deliverImmediately: true
        )
    }
}
