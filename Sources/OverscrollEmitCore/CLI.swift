import Foundation

public enum CLIParseError: Error, Equatable, Sendable {
    case missingCommand
    case unknownCommand(String)
    case unknownOption(String)
    case missingValue(option: String)
    case invalidValue(option: String, value: String, allowed: [String])
    case duplicateOption(String)
    case unexpectedArgument(String)

    public var message: String {
        switch self {
        case .missingCommand: "missing command"
        case .unknownCommand(let name): "unknown command: \(name)"
        case .unknownOption(let name): "unknown option: --\(name)"
        case .missingValue(let option): "missing value for --\(option)"
        case .invalidValue(let option, let value, let allowed):
            "invalid value for --\(option): \(value) (allowed: \(allowed.joined(separator: ", ")))"
        case .duplicateOption(let name): "duplicate option: --\(name)"
        case .unexpectedArgument(let arg): "unexpected argument: \(arg)"
        }
    }
}

/// Sync: one case per `GlowStyle` field, plus `display`.
public enum FlashOption: String, CaseIterable, Sendable {
    case display, size, density, flair, speed, color
}

public enum CLIParser {
    public static func parse(_ args: [String]) -> Result<CLICommand, CLIParseError> {
        guard let head = args.first else { return .failure(.missingCommand) }
        let rest = args.dropFirst()
        switch head {
        case Side.left.rawValue: return parseFlash(side: .left, rest)
        case Side.right.rawValue: return parseFlash(side: .right, rest)
        case "settings": return noArguments(rest, .send(.settings))
        case "quit": return noArguments(rest, .send(.quit))
        case "displays": return noArguments(rest, .displays)
        case "version", "--version": return noArguments(rest, .version)
        case "help", "--help", "-h": return noArguments(rest, .help)
        default: return .failure(.unknownCommand(head))
        }
    }

    static func parseFlash(side: Side, _ args: ArraySlice<String>) -> Result<CLICommand, CLIParseError> {
        Result { () throws(CLIParseError) in
            let options = try collectOptions(args, [:]).get()
            let base = GlowStyle.standard
            let style = GlowStyle(
                size: try decode(.size, options, default: base.size).get(),
                density: try decode(.density, options, default: base.density).get(),
                flair: try decode(.flair, options, default: base.flair).get(),
                speed: try decode(.speed, options, default: base.speed).get(),
                color: try decodeColor(options[.color], default: base.color).get()
            )
            let display = try decodeDisplay(options[.display]).get()
            return .send(.flash(FlashRequest(side: side, display: display, style: style)))
        }
    }

    private static func noArguments(_ args: ArraySlice<String>, _ command: CLICommand) -> Result<CLICommand, CLIParseError> {
        args.first.map { .failure(.unexpectedArgument($0)) } ?? .success(command)
    }

    private static func collectOptions(
        _ args: ArraySlice<String>,
        _ acc: [FlashOption: String]
    ) -> Result<[FlashOption: String], CLIParseError> {
        guard let first = args.first else { return .success(acc) }
        guard first.hasPrefix("--") else { return .failure(.unexpectedArgument(first)) }
        let body = first.dropFirst(2)
        let split: (name: Substring, value: String?, rest: ArraySlice<String>) =
            if let eq = body.firstIndex(of: "=") {
                (body[..<eq], String(body[body.index(after: eq)...]), args.dropFirst())
            } else {
                (body, args.dropFirst().first.flatMap { $0.hasPrefix("--") ? nil : $0 }, args.dropFirst(2))
            }
        guard let option = FlashOption(rawValue: String(split.name)) else {
            return .failure(.unknownOption(String(split.name)))
        }
        guard let value = split.value, !value.isEmpty else { return .failure(.missingValue(option: option.rawValue)) }
        guard acc[option] == nil else { return .failure(.duplicateOption(option.rawValue)) }
        return collectOptions(split.rest, acc.merging([option: value]) { _, new in new })
    }

    private static func decode<T: RawRepresentable & CaseIterable>(
        _ option: FlashOption,
        _ options: [FlashOption: String],
        default fallback: T
    ) -> Result<T, CLIParseError> where T.RawValue == String {
        guard let raw = options[option] else { return .success(fallback) }
        return T(rawValue: raw).map { .success($0) }
            ?? .failure(.invalidValue(option: option.rawValue, value: raw, allowed: T.allCases.map(\.rawValue)))
    }

    private static func decodeColor(_ raw: String?, default fallback: GlowColor) -> Result<GlowColor, CLIParseError> {
        guard let raw else { return .success(fallback) }
        return GlowColor(cliValue: raw).map { .success($0) }
            ?? .failure(.invalidValue(option: FlashOption.color.rawValue, value: raw, allowed: GlowColor.cliValueDescriptions))
    }

    private static func decodeDisplay(_ raw: String?) -> Result<DisplayTarget, CLIParseError> {
        switch raw {
        case nil, "active": return .success(.active)
        case "primary": return .success(.primary)
        case "mouse": return .success(.mouse)
        case .some(let value):
            if let n = Int(value), n >= 1 { return .success(.index(n)) }
            return .failure(.invalidValue(option: FlashOption.display.rawValue, value: value, allowed: CLIUsage.displayValues))
        }
    }
}

/// Builds the CLI arguments equivalent to a request (used by the settings preview).
public enum CLIFormatter {
    public static func arguments(for request: FlashRequest) -> [String] {
        let standard = GlowStyle.standard
        let style = request.style
        let display: String? =
            switch request.display {
            case .active: nil
            case .primary: "primary"
            case .mouse: "mouse"
            case .index(let n): String(n)
            }
        let pairs: [(FlashOption, String?)] = FlashOption.allCases.map { option in
            switch option {
            case .display: (option, display)
            case .size: (option, style.size == standard.size ? nil : style.size.rawValue)
            case .density: (option, style.density == standard.density ? nil : style.density.rawValue)
            case .flair: (option, style.flair == standard.flair ? nil : style.flair.rawValue)
            case .speed: (option, style.speed == standard.speed ? nil : style.speed.rawValue)
            case .color: (option, style.color == standard.color ? nil : style.color.cliValue)
            }
        }
        return [request.side.rawValue] + pairs.compactMap { option, value in value.map { "--\(option.rawValue)=\($0)" } }
    }

    /// Joins words into a shell command line, single-quoting words that need it.
    public static func shellCommand(_ words: [String]) -> String {
        words.map(shellQuote).joined(separator: " ")
    }

    static func shellQuote(_ word: String) -> String {
        // `#` and `^` stay quoted: they are comment/glob characters in zsh with some options.
        let safe = Set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-./=:,+@%")
        return !word.isEmpty && word.allSatisfy(safe.contains)
            ? word
            : "'" + word.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}

public enum CLIUsage {
    static let displayValues = ["active", "primary", "mouse", "<n>"]

    public static var text: String {
        func values<T: RawRepresentable & CaseIterable>(_: T.Type, _ standard: T) -> String where T.RawValue == String {
            T.allCases.map { $0 == standard ? "\($0.rawValue)*" : $0.rawValue }.joined(separator: "|")
        }
        let s = GlowStyle.standard
        let optionLines: [String] = FlashOption.allCases.map { option in
            switch option {
            case .display: "  --display  \(displayValues.map { $0 == "active" ? "active*" : $0 }.joined(separator: "|"))"
            case .size: "  --size     \(values(GlowSize.self, s.size))     (大きさ)"
            case .density: "  --density  \(values(GlowDensity.self, s.density))     (濃さ)"
            case .flair: "  --flair    \(values(GlowFlair.self, s.flair))     (派手さ)"
            case .speed: "  --speed    \(values(GlowSpeed.self, s.speed))"
            case .color:
                "  --color    \(GlowColor.cliValueDescriptions.map { $0 == s.color.cliValue ? "\($0)*" : $0 }.joined(separator: "|"))"
            }
        }
        return """
            Usage:
              overscroll-emit left|right [options]   Show the edge glow on the left/right side
              overscroll-emit settings               Open the settings window
              overscroll-emit displays               List displays (indices for --display)
              overscroll-emit quit                   Quit the resident app
              overscroll-emit version
              overscroll-emit help

            Options (* = default):
            \(optionLines.joined(separator: "\n"))

            --display active: display of the focused window (needs Accessibility permission),
              falling back to the frontmost app's window, then the display under the mouse.
            """
    }
}
