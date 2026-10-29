import CoreGraphics

public enum Geometry {
    /// Converts a top-left-origin global rect (Accessibility / CGWindowList) into
    /// Cocoa's bottom-left-origin global coordinates.
    public static func cocoaRect(fromTopLeft rect: CGRect, primaryScreenHeight: CGFloat) -> CGRect {
        CGRect(x: rect.minX, y: primaryScreenHeight - rect.maxY, width: rect.width, height: rect.height)
    }

    /// Index of the screen sharing the largest area with `rect`, or nil if none overlaps.
    public static func bestScreenIndex(for rect: CGRect, screens: [CGRect]) -> Int? {
        screens.enumerated()
            .map { (index: $0.offset, area: area($0.element.intersection(rect))) }
            .filter { $0.area > 0 }
            .max { $0.area < $1.area }?
            .index
    }

    public static func screenIndex(containing point: CGPoint, screens: [CGRect]) -> Int? {
        // Cocoa screen frames are half-open on maxY for mouse purposes; include the top edge.
        screens.firstIndex { $0.contains(point) || ($0.minX...$0.maxX ~= point.x && point.y == $0.maxY) }
    }

    /// Frame of the overlay window hugging the given side of the screen.
    public static func glowFrame(screen: CGRect, side: Side, width: CGFloat) -> CGRect {
        let clamped = min(width, screen.width)
        let x: CGFloat =
            switch side {
            case .left: screen.minX
            case .right: screen.maxX - clamped
            }
        return CGRect(x: x, y: screen.minY, width: clamped, height: screen.height)
    }

    private static func area(_ rect: CGRect) -> CGFloat {
        rect.isNull ? 0 : rect.width * rect.height
    }
}
