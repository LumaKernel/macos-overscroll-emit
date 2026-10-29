import Foundation

/// CLI -> app transport over DistributedNotificationCenter.
/// The CLI re-posts a request until it receives an ack with the same id; the app dedupes by id.
/// Info.plist key holding the build id (commit hash). CFBundleVersion is just `{MAJOR}.0.0`.
public let buildInfoKey = "OverscrollEmitBuild"

public enum IPC {
    public static let bundleIdentifier = "com.lumakernel.overscroll-emit"
    public static let requestName = Notification.Name("com.lumakernel.overscroll-emit.request")
    public static let ackName = Notification.Name("com.lumakernel.overscroll-emit.ack")
    public static let payloadKey = "payload"
    /// Passed when the CLI launches the app, so it starts without showing settings.
    public static let backgroundLaunchArgument = "--background"
}

public struct RequestEnvelope: Equatable, Codable, Sendable {
    public let id: String
    public let command: AppCommand

    public init(id: String, command: AppCommand) {
        self.id = id
        self.command = command
    }
}

public struct AckEnvelope: Equatable, Codable, Sendable {
    public let id: String
    /// nil on success.
    public let error: String?

    public init(id: String, error: String?) {
        self.id = id
        self.error = error
    }
}

public enum IPCCodec {
    public static func encode<T: Encodable>(_ value: T) -> String? {
        (try? JSONEncoder().encode(value)).flatMap { String(data: $0, encoding: .utf8) }
    }

    public static func decode<T: Decodable>(_ type: T.Type, from string: String) -> T? {
        try? JSONDecoder().decode(type, from: Data(string.utf8))
    }
}
