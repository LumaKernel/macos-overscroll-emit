import AppKit
import ApplicationServices
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
            let frames = screens.map(\.frame)
            let windowScreen = (focusedWindowRect() ?? frontmostAppWindowRect())
                .map { Geometry.cocoaRect(fromTopLeft: $0, primaryScreenHeight: primary.frame.height) }
                .flatMap { Geometry.bestScreenIndex(for: $0, screens: frames) }
                .map { screens[$0] }
            return .success(windowScreen ?? mouseScreen(screens) ?? primary)
        }
    }

    private static func mouseScreen(_ screens: [NSScreen]) -> NSScreen? {
        Geometry.screenIndex(containing: NSEvent.mouseLocation, screens: screens.map(\.frame)).map { screens[$0] }
    }

    /// Focused window of the frontmost app via Accessibility (top-left global coords). Needs AX trust.
    private static func focusedWindowRect() -> CGRect? {
        guard AXIsProcessTrusted(), let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier else { return nil }
        let app = AXUIElementCreateApplication(pid)
        guard let window = copyAttribute(app, kAXFocusedWindowAttribute).flatMap(asAXUIElement),
            let position = copyAttribute(window, kAXPositionAttribute).flatMap({ axValue($0, CGPoint.zero, .cgPoint) }),
            let size = copyAttribute(window, kAXSizeAttribute).flatMap({ axValue($0, CGSize.zero, .cgSize) })
        else { return nil }
        return CGRect(origin: position, size: size)
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

    private static func copyAttribute(_ element: AXUIElement, _ attribute: String) -> CFTypeRef? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        return result == .success ? value : nil
    }

    private static func asAXUIElement(_ value: CFTypeRef) -> AXUIElement? {
        CFGetTypeID(value) == AXUIElementGetTypeID() ? unsafeDowncast(value, to: AXUIElement.self) : nil
    }

    private static func axValue<T: BitwiseCopyable>(_ value: CFTypeRef, _ initial: T, _ type: AXValueType) -> T? {
        guard CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        var result = initial
        return AXValueGetValue(unsafeDowncast(value, to: AXValue.self), type, &result) ? result : nil
    }
}
