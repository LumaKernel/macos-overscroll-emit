import AppKit
import OverscrollEmitCore

enum ScreenResolveError: Error {
    case noScreens
    case indexOutOfRange(requested: Int, available: Int)

    var message: String {
        switch self {
        case .noScreens: "no displays available"
        case .indexOutOfRange(let requested, let available):
            "display \(requested) not found (\(available) available; see `overscroll-emit displays`)"
        }
    }
}

/// How `--display active` picked its display, in fallback order.
enum ActiveDisplaySource {
    case menuBar
    case frontmostAppWindow
    case mouse
    case primary

    var description: String {
        switch self {
        case .menuBar: "display with the active menu bar (SkyLight, same as yabai)"
        case .frontmostAppWindow: "frontmost window of the frontmost app (window list)"
        case .mouse: "display under the mouse (no window found)"
        case .primary: "primary display (no window found, mouse off-screen)"
        }
    }
}

@MainActor
enum ScreenResolver {
    static func resolve(_ target: DisplayTarget) -> Result<NSScreen, ScreenResolveError> {
        let screens = NSScreen.screens
        guard let primary = screens.first else { return .failure(.noScreens) }
        switch target {
        case .primary:
            return .success(primary)
        case .mouse:
            return .success(mouseScreen(screens) ?? primary)
        case .index(let n):
            return screens.indices.contains(n - 1)
                ? .success(screens[n - 1])
                : .failure(.indexOutOfRange(requested: n, available: screens.count))
        case .active:
            return .success(resolveActive(screens: screens, primary: primary).screen)
        }
    }

    /// Display list for `overscroll-emit displays`, with the reasoning behind `active`.
    static func describe() -> String {
        let screens = NSScreen.screens
        guard let primary = screens.first else { return "no displays" }
        let active = resolveActive(screens: screens, primary: primary)
        let mouse = mouseScreen(screens)
        let lines = screens.enumerated().map { offset, screen in
            let f = screen.frame
            let marks = [
                screen == primary ? "primary" : nil,
                screen == active.screen ? "active" : nil,
                screen == mouse ? "mouse" : nil,
            ].compactMap { $0 }
            let suffix = marks.isEmpty ? "" : "  [\(marks.joined(separator: ", "))]"
            return "\(offset + 1): \(screen.localizedName)  \(Int(f.width))x\(Int(f.height)) at (\(Int(f.minX)), \(Int(f.minY)))\(suffix)"
        }
        let frontmost = NSWorkspace.shared.frontmostApplication?.localizedName ?? "none"
        return
            (lines + [
                "",
                "active: \(active.source.description)",
                "frontmost app: \(frontmost)",
            ]).joined(separator: "\n")
    }

    private static func resolveActive(screens: [NSScreen], primary: NSScreen) -> (screen: NSScreen, source: ActiveDisplaySource) {
        let frames = screens.map(\.frame)
        func screen(forTopLeft rect: CGRect?) -> NSScreen? {
            rect.map { Geometry.cocoaRect(fromTopLeft: $0, primaryScreenHeight: primary.frame.height) }
                .flatMap { Geometry.bestScreenIndex(for: $0, screens: frames) }
                .map { screens[$0] }
        }
        if let uuid = SkyLight.activeMenuBarDisplayUUID(), let screen = screens.first(where: { $0.displayUUID == uuid }) {
            return (screen, .menuBar)
        }
        if let screen = screen(forTopLeft: frontmostAppWindowRect()) { return (screen, .frontmostAppWindow) }
        if let screen = mouseScreen(screens) { return (screen, .mouse) }
        return (primary, .primary)
    }

    private static func mouseScreen(_ screens: [NSScreen]) -> NSScreen? {
        Geometry.screenIndex(containing: NSEvent.mouseLocation, screens: screens.map(\.frame)).map { screens[$0] }
    }

    /// Front-most normal-layer window of the frontmost app (top-left global coords). No permission needed for bounds.
    private static func frontmostAppWindowRect() -> CGRect? {
        guard let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier,
            let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]]
        else { return nil }
        return list.lazy
            .filter { ($0[kCGWindowOwnerPID as String] as? pid_t) == pid && ($0[kCGWindowLayer as String] as? Int) == 0 }
            .compactMap { ($0[kCGWindowBounds as String] as? NSDictionary).flatMap { CGRect(dictionaryRepresentation: $0) } }
            .first
    }

}
