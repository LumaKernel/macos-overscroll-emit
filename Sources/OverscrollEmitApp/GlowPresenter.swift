import AppKit
import OverscrollEmitCore
import QuartzCore

/// Shows the edge glow in click-through overlay windows, one per (display, side).
/// Re-triggering an edge while it is still glowing restarts from the current opacity instead of flickering.
@MainActor
final class GlowPresenter {
    private struct Key: Hashable {
        let display: CGDirectDisplayID
        let side: Side
    }

    private var overlays: [Key: GlowOverlay] = [:]

    func present(on screen: NSScreen, side: Side, style: GlowStyle) {
        let key = Key(display: screen.displayID, side: side)
        let overlay = overlays[key] ?? GlowOverlay()
        overlays[key] = overlay
        overlay.play(screen: screen, side: side, parameters: GlowParameters(style: style), color: style.color.nsColor) { [weak self] in
            self?.overlays[key] = nil
        }
    }
}

@MainActor
private final class GlowOverlay {
    private let window: NSWindow
    /// Scaled horizontally from the screen edge.
    private let container = CALayer()
    private let halo = CAGradientLayer()
    private let core = CAGradientLayer()
    private var generation = 0

    init() {
        window = NSWindow(contentRect: .zero, styleMask: .borderless, backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.isReleasedWhenClosed = false
        window.level = .screenSaver
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]

        let view = NSView()
        view.wantsLayer = true
        window.contentView = view
        halo.type = .radial
        core.type = .radial
        container.addSublayer(halo)
        container.addSublayer(core)
        view.layer?.addSublayer(container)
    }

    func play(screen: NSScreen, side: Side, parameters p: GlowParameters, color: NSColor, onFinish: @escaping @MainActor () -> Void) {
        generation += 1
        let current = generation
        let currentOpacity = Double(container.presentation()?.opacity ?? 0)
        let currentScale = (container.presentation()?.value(forKeyPath: "transform.scale.x") as? Double) ?? p.initialScale

        let frame = Geometry.glowFrame(screen: screen.frame, side: side, width: p.width * p.maxScale)
        window.setFrame(frame, display: false)
        layout(side: side, bounds: CGRect(origin: .zero, size: frame.size), parameters: p, color: color)
        window.orderFrontRegardless()

        let total = p.totalDuration
        let inEnd = NSNumber(value: p.fadeIn / total)
        let holdEnd = NSNumber(value: (p.fadeIn + p.hold) / total)

        let opacity = CAKeyframeAnimation(keyPath: "opacity")
        opacity.values = [currentOpacity, p.peakOpacity, p.peakOpacity, 0]
        opacity.keyTimes = [0, inEnd, holdEnd, 1]
        opacity.timingFunctions = [.init(name: .easeOut), .init(name: .linear), .init(name: .easeInEaseOut)]

        let scale = CAKeyframeAnimation(keyPath: "transform.scale.x")
        scale.values = [max(currentScale, p.initialScale), p.peakScale, 1, p.trailingScale]
        scale.keyTimes = [0, inEnd, holdEnd, 1]
        scale.timingFunctions = [.init(name: .easeOut), .init(name: .easeInEaseOut), .init(name: .easeOut)]

        let group = CAAnimationGroup()
        group.animations = [opacity, scale]
        group.duration = total

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        CATransaction.setCompletionBlock { [weak self] in
            MainActor.assumeIsolated {
                // A newer play() replaced this animation; it owns the window now.
                guard let self, self.generation == current else { return }
                self.window.orderOut(nil)
                onFinish()
            }
        }
        container.removeAllAnimations()
        container.opacity = 0
        container.add(group, forKey: "glow")
        CATransaction.commit()
    }

    private func layout(side: Side, bounds: CGRect, parameters p: GlowParameters, color: NSColor) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }

        let width = min(p.width, bounds.width)
        // Anchor on the screen edge so scaling grows into the screen.
        let (anchorX, edgeX, farX): (CGFloat, CGFloat, CGFloat) =
            switch side {
            case .left: (0, 0, 1)
            case .right: (1, 1, 0)
            }
        container.anchorPoint = CGPoint(x: anchorX, y: 0.5)
        container.bounds = CGRect(x: 0, y: 0, width: width, height: bounds.height)
        container.position = CGPoint(x: anchorX == 0 ? 0 : bounds.width, y: bounds.midY)
        container.contentsScale = window.backingScaleFactor

        // Radial gradients: startPoint is the center, endPoint sets the x/y radii.
        halo.frame = container.bounds
        halo.startPoint = CGPoint(x: edgeX, y: 0.5)
        halo.endPoint = CGPoint(x: farX, y: 1)
        halo.colors = [1.0, 0.55, 0.18, 0].map { color.withAlphaComponent($0).cgColor }
        halo.locations = [0, 0.25, 0.6, 1]

        let coreColor = color.blended(withFraction: 0.45, of: .white) ?? color
        core.frame = container.bounds
        core.startPoint = CGPoint(x: edgeX, y: 0.5)
        core.endPoint = CGPoint(x: edgeX + (farX - edgeX) * 0.3, y: 0.85)
        core.colors = [p.coreOpacity, p.coreOpacity * 0.4, 0].map { coreColor.withAlphaComponent($0).cgColor }
        core.locations = [0, 0.4, 1]
        core.isHidden = p.coreOpacity == 0
    }
}

extension NSScreen {
    var displayID: CGDirectDisplayID {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? 0
    }
}

extension GlowColor {
    var nsColor: NSColor {
        switch self {
        case .gray: NSColor(white: 0.55, alpha: 1)
        case .white: .white
        case .black: .black
        case .accent: .controlAccentColor
        case .blue: .systemBlue
        case .red: .systemRed
        case .green: .systemGreen
        case .orange: .systemOrange
        case .purple: .systemPurple
        }
    }
}
