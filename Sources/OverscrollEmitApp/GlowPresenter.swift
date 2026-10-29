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
        overlay.play(screen: screen, side: side, parameters: GlowParameters(style: style), color: style.color) { [weak self] in
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

    func play(screen: NSScreen, side: Side, parameters p: GlowParameters, color: GlowColor, onFinish: @escaping @MainActor () -> Void) {
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
        halo.removeAllAnimations()
        core.removeAllAnimations()
        if case .rainbow = color.paint {
            addRainbowAnimation(duration: total, coreOpacity: p.coreOpacity)
        }
        CATransaction.commit()
    }

    /// Cycles the hue of both gradients; neighbouring gradient stops are offset in hue so several colors show at once.
    private func addRainbowAnimation(duration: Double, coreOpacity: Double) {
        let cycles = max(1, duration / Self.rainbowCyclePeriod)
        let samples = Int((cycles * 12).rounded(.up))
        let hues = (0...samples).map { Double($0) / Double(samples) * cycles }

        let haloAnimation = CAKeyframeAnimation(keyPath: "colors")
        haloAnimation.values = hues.map { hue in Self.haloColors { Self.rainbowColor(hue + Double($0) * 0.08) } }
        haloAnimation.duration = duration
        halo.add(haloAnimation, forKey: "rainbow")

        let coreAnimation = CAKeyframeAnimation(keyPath: "colors")
        coreAnimation.values = hues.map { hue in
            Self.coreColors(strength: coreOpacity) { Self.rainbowColor(hue + 0.15 + Double($0) * 0.08) }
        }
        coreAnimation.duration = duration
        core.add(coreAnimation, forKey: "rainbow")
    }

    private func layout(side: Side, bounds: CGRect, parameters p: GlowParameters, color: GlowColor) {
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
        let colorAt: (Int) -> NSColor =
            switch color.paint {
            case .solid(let solid): { _ in solid }
            // Model value for the first frame; the "rainbow" animation takes over.
            case .rainbow: { Self.rainbowColor(Double($0) * 0.08) }
            }
        halo.colors = Self.haloColors(colorAt)
        halo.locations = [0, 0.25, 0.6, 1]

        core.frame = container.bounds
        core.startPoint = CGPoint(x: edgeX, y: 0.5)
        core.endPoint = CGPoint(x: edgeX + (farX - edgeX) * 0.3, y: 0.85)
        core.colors = Self.coreColors(strength: p.coreOpacity, colorAt)
        core.locations = [0, 0.4, 1]
        core.isHidden = p.coreOpacity == 0
    }

    private static let rainbowCyclePeriod = 1.2

    private static func haloColors(_ colorAt: (Int) -> NSColor) -> [CGColor] {
        let alphas: [CGFloat] = [1, 0.55, 0.18, 0]
        return alphas.enumerated().map { colorAt($0.offset).withAlphaComponent($0.element).cgColor }
    }

    private static func coreColors(strength: Double, _ colorAt: (Int) -> NSColor) -> [CGColor] {
        let alphas: [CGFloat] = [strength, strength * 0.4, 0]
        return alphas.enumerated().map { index, alpha in
            let base = colorAt(index)
            return (base.blended(withFraction: 0.45, of: .white) ?? base).withAlphaComponent(alpha).cgColor
        }
    }

    private static func rainbowColor(_ hue: Double) -> NSColor {
        NSColor(hue: hue.truncatingRemainder(dividingBy: 1), saturation: 0.85, brightness: 1, alpha: 1)
    }
}

extension NSScreen {
    var displayID: CGDirectDisplayID {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? 0
    }
}

enum GlowPaint {
    case solid(NSColor)
    case rainbow
}

extension GlowColor {
    var paint: GlowPaint {
        switch self {
        case .preset(let preset): .solid(preset.nsColor)
        case .rainbow: .rainbow
        case .custom(let rgb): .solid(rgb.nsColor)
        }
    }
}

extension GlowRGB {
    var nsColor: NSColor {
        NSColor(srgbRed: CGFloat(red) / 255, green: CGFloat(green) / 255, blue: CGFloat(blue) / 255, alpha: 1)
    }

    init(_ color: NSColor) {
        let srgb = color.usingColorSpace(.sRGB) ?? color
        func byte(_ component: CGFloat) -> UInt8 { UInt8((min(max(component, 0), 1) * 255).rounded()) }
        self.init(red: byte(srgb.redComponent), green: byte(srgb.greenComponent), blue: byte(srgb.blueComponent))
    }
}

extension GlowColorPreset {
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
