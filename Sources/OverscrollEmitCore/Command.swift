import Foundation

public enum DisplayTarget: Equatable, Codable, Sendable {
    /// Display of the focused window (falls back to frontmost app window, then mouse).
    case active
    /// Display with the menu bar.
    case primary
    /// Display under the mouse cursor.
    case mouse
    /// 1-based index in `overscroll-emit displays` order.
    case index(Int)
}

public struct FlashRequest: Equatable, Codable, Sendable {
    public let side: Side
    public let display: DisplayTarget
    public let style: GlowStyle

    public init(side: Side, display: DisplayTarget, style: GlowStyle) {
        self.side = side
        self.display = display
        self.style = style
    }
}

/// Commands executed by the resident app.
public enum AppCommand: Equatable, Codable, Sendable {
    case flash(FlashRequest)
    case settings
    case quit
}

/// Commands handled by the CLI process.
public enum CLICommand: Equatable, Sendable {
    case send(AppCommand)
    case displays
    case version
    case help
}
