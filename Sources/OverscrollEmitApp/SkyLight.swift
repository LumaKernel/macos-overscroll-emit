import AppKit

/// Private SkyLight calls, resolved at runtime so a missing symbol degrades to the public fallbacks.
/// Same source yabai uses for the focused display (`yabai -m query --displays --display`).
enum SkyLight {
    private typealias MainConnectionID = @convention(c) () -> Int32
    private typealias CopyActiveMenuBarDisplayIdentifier = @convention(c) (Int32) -> Unmanaged<CFString>?

    // Set once at first use and only read afterwards.
    nonisolated(unsafe) private static let handle = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY)

    /// UUID of the display whose menu bar is active, i.e. the display that has keyboard focus
    /// (follows the focused space even when that space has no windows).
    static func activeMenuBarDisplayUUID() -> String? {
        guard let handle,
            let mainConnection = dlsym(handle, "SLSMainConnectionID"),
            let copyIdentifier = dlsym(handle, "SLSCopyActiveMenuBarDisplayIdentifier")
        else { return nil }
        let connection = unsafeBitCast(mainConnection, to: MainConnectionID.self)()
        return unsafeBitCast(copyIdentifier, to: CopyActiveMenuBarDisplayIdentifier.self)(connection)?.takeRetainedValue() as String?
    }
}

extension NSScreen {
    var displayUUID: String? {
        CGDisplayCreateUUIDFromDisplayID(displayID).map { CFUUIDCreateString(nil, $0.takeRetainedValue()) as String }
    }
}
