import Testing

@testable import OverscrollEmitCore

@Suite struct CLIParserTests {
    @Test func sideOnlyUsesStandardStyleOnActiveDisplay() {
        #expect(CLIParser.parse(["left"]) == .success(.send(.flash(FlashRequest(side: .left, display: .active, style: .standard)))))
        #expect(CLIParser.parse(["right"]) == .success(.send(.flash(FlashRequest(side: .right, display: .active, style: .standard)))))
    }

    @Test func allOptionsInBothSyntaxes() {
        let result = CLIParser.parse([
            "right", "--display", "2", "--size=huge", "--density", "dark",
            "--flair=flashy", "--speed", "fast", "--color=accent",
        ])
        let expected = FlashRequest(
            side: .right,
            display: .index(2),
            style: GlowStyle(size: .huge, density: .dark, flair: .flashy, speed: .fast, color: .accent)
        )
        #expect(result == .success(.send(.flash(expected))))
    }

    @Test(arguments: [
        ("active", DisplayTarget.active),
        ("primary", .primary),
        ("mouse", .mouse),
        ("1", .index(1)),
    ])
    func displayValues(raw: String, expected: DisplayTarget) {
        #expect(
            CLIParser.parse(["left", "--display", raw])
                == .success(.send(.flash(FlashRequest(side: .left, display: expected, style: .standard)))))
    }

    @Test func errors() {
        #expect(CLIParser.parse([]) == .failure(.missingCommand))
        #expect(CLIParser.parse(["up"]) == .failure(.unknownCommand("up")))
        #expect(CLIParser.parse(["left", "--glow", "x"]) == .failure(.unknownOption("glow")))
        #expect(CLIParser.parse(["left", "--size"]) == .failure(.missingValue(option: "size")))
        #expect(CLIParser.parse(["left", "--size", "--density", "dark"]) == .failure(.missingValue(option: "size")))
        #expect(CLIParser.parse(["left", "--size="]) == .failure(.missingValue(option: "size")))
        #expect(
            CLIParser.parse(["left", "--size", "s"])
                == .failure(.invalidValue(option: "size", value: "s", allowed: ["small", "medium", "large", "huge"])))
        #expect(
            CLIParser.parse(["left", "--display", "0"])
                == .failure(.invalidValue(option: "display", value: "0", allowed: ["active", "primary", "mouse", "<n>"])))
        #expect(CLIParser.parse(["left", "--size=small", "--size=large"]) == .failure(.duplicateOption("size")))
        #expect(CLIParser.parse(["left", "right"]) == .failure(.unexpectedArgument("right")))
        #expect(CLIParser.parse(["settings", "now"]) == .failure(.unexpectedArgument("now")))
    }

    @Test func otherCommands() {
        #expect(CLIParser.parse(["settings"]) == .success(.send(.settings)))
        #expect(CLIParser.parse(["quit"]) == .success(.send(.quit)))
        #expect(CLIParser.parse(["displays"]) == .success(.displays))
        #expect(CLIParser.parse(["--version"]) == .success(.version))
        #expect(CLIParser.parse(["-h"]) == .success(.help))
    }

    // Sync: when `GlowStyle` gains a field, include a non-default value of it here.
    @Test func formatterRoundTrips() {
        let requests = [
            FlashRequest(side: .left, display: .active, style: .standard),
            FlashRequest(
                side: .right, display: .index(3), style: GlowStyle(size: .small, density: .light, flair: .calm, speed: .slow, color: .red)),
            FlashRequest(
                side: .left, display: .mouse, style: GlowStyle(size: .medium, density: .dark, flair: .normal, speed: .normal, color: .gray)),
        ]
        for request in requests {
            #expect(CLIParser.parse(CLIFormatter.arguments(for: request)) == .success(.send(.flash(request))))
        }
        #expect(CLIFormatter.arguments(for: requests[0]) == ["left"])
        #expect(CLIFormatter.arguments(for: requests[2]) == ["left", "--display=mouse", "--density=dark"])
    }

    @Test func usageMentionsEveryOption() {
        for option in FlashOption.allCases {
            #expect(CLIUsage.text.contains("--\(option.rawValue)"))
        }
    }
}
