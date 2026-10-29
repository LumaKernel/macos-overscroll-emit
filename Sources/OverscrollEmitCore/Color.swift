import Foundation

public enum GlowColorPreset: String, CaseIterable, Codable, Sendable {
    case gray, white, black, accent, blue, red, green, orange, purple
}

public struct GlowRGB: Hashable, Codable, Sendable {
    public let red: UInt8
    public let green: UInt8
    public let blue: UInt8

    public init(red: UInt8, green: UInt8, blue: UInt8) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    /// Accepts `#RRGGBB` or `RRGGBB`, case-insensitive.
    public init?(hex: String) {
        let digits = hex.hasPrefix("#") ? hex.dropFirst() : Substring(hex)
        guard digits.count == 6, digits.allSatisfy(\.isHexDigit), let value = UInt32(digits, radix: 16) else { return nil }
        self.init(red: UInt8((value >> 16) & 0xFF), green: UInt8((value >> 8) & 0xFF), blue: UInt8(value & 0xFF))
    }

    /// Lowercase `#rrggbb`.
    public var hex: String { String(format: "#%02x%02x%02x", red, green, blue) }
}

public enum GlowColor: Hashable, Codable, Sendable {
    case preset(GlowColorPreset)
    /// Hue cycles through the spectrum while the glow is visible.
    case rainbow
    case custom(GlowRGB)

    static let rainbowValue = "rainbow"
    static let customValueDescription = "#RRGGBB"

    /// Sync: keep in step with `init(cliValue:)` and `cliValue`.
    public static var cliValueDescriptions: [String] {
        GlowColorPreset.allCases.map(\.rawValue) + [rainbowValue, customValueDescription]
    }

    public init?(cliValue: String) {
        if let preset = GlowColorPreset(rawValue: cliValue) {
            self = .preset(preset)
        } else if cliValue == Self.rainbowValue {
            self = .rainbow
        } else if let rgb = GlowRGB(hex: cliValue) {
            self = .custom(rgb)
        } else {
            return nil
        }
    }

    public var cliValue: String {
        switch self {
        case .preset(let preset): preset.rawValue
        case .rainbow: Self.rainbowValue
        case .custom(let rgb): rgb.hex
        }
    }
}
