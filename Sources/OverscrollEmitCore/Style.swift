import Foundation

public enum Side: String, CaseIterable, Codable, Sendable {
    case left, right
}

/// 大きさ: how far the glow reaches into the screen.
public enum GlowSize: String, CaseIterable, Codable, Sendable {
    case small, medium, large, huge
}

/// 濃さ: peak opacity of the glow.
public enum GlowDensity: String, CaseIterable, Codable, Sendable {
    case light, medium, dark
}

/// 派手さ: how energetic the motion is (spread, overshoot, bright core).
public enum GlowFlair: String, CaseIterable, Codable, Sendable {
    case calm, normal, flashy
}

public enum GlowSpeed: String, CaseIterable, Codable, Sendable {
    case slow, normal, fast
}

/// Categorical style.
/// Sync: a new field also needs `GlowParameters.init(style:)`, a `FlashOption` case (+ `CLIParser.parseFlash`),
/// `SettingsModel` / `SettingsView` preview picker, and `CLIParserTests.formatterRoundTrips`.
public struct GlowStyle: Equatable, Codable, Sendable {
    public let size: GlowSize
    public let density: GlowDensity
    public let flair: GlowFlair
    public let speed: GlowSpeed
    public let color: GlowColor

    public init(size: GlowSize, density: GlowDensity, flair: GlowFlair, speed: GlowSpeed, color: GlowColor) {
        self.size = size
        self.density = density
        self.flair = flair
        self.speed = speed
        self.color = color
    }

    public static let standard = GlowStyle(size: .medium, density: .medium, flair: .normal, speed: .normal, color: .preset(.gray))
}

/// Numeric animation parameters resolved from a `GlowStyle`.
public struct GlowParameters: Equatable, Sendable {
    /// Reach into the screen in points at horizontal scale 1.
    public let width: Double
    public let peakOpacity: Double
    public let fadeIn: Double
    public let hold: Double
    public let fadeOut: Double
    /// Horizontal scale at the start of the fade-in.
    public let initialScale: Double
    /// Horizontal scale at the end of the fade-in (> 1 means overshoot).
    public let peakScale: Double
    /// Horizontal scale at the end of the fade-out (slow "じわっ" spread).
    public let trailingScale: Double
    /// Opacity of the bright core near the edge, relative to the halo. 0 disables it.
    public let coreOpacity: Double

    public var totalDuration: Double { fadeIn + hold + fadeOut }
    public var maxScale: Double { max(initialScale, peakScale, 1, trailingScale) }

    public init(style: GlowStyle) {
        let width: Double =
            switch style.size {
            case .small: 28
            case .medium: 56
            case .large: 110
            case .huge: 200
            }
        let peakOpacity: Double =
            switch style.density {
            case .light: 0.3
            case .medium: 0.55
            case .dark: 0.85
            }
        let timeScale: Double =
            switch style.speed {
            case .slow: 1.7
            case .normal: 1.0
            case .fast: 0.6
            }
        let motion: (fadeIn: Double, hold: Double, fadeOut: Double, initial: Double, peak: Double, trailing: Double, core: Double) =
            switch style.flair {
            case .calm: (0.28, 0.05, 0.75, 0.85, 1.0, 1.04, 0)
            case .normal: (0.2, 0.06, 0.6, 0.35, 1.0, 1.08, 0.35)
            case .flashy: (0.14, 0.1, 0.55, 0.15, 1.25, 1.12, 0.8)
            }
        self.width = width
        self.peakOpacity = peakOpacity
        self.fadeIn = motion.fadeIn * timeScale
        self.hold = motion.hold * timeScale
        self.fadeOut = motion.fadeOut * timeScale
        self.initialScale = motion.initial
        self.peakScale = motion.peak
        self.trailingScale = motion.trailing
        self.coreOpacity = motion.core
    }
}
