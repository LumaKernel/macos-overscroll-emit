import CoreGraphics
import Testing

@testable import OverscrollEmitCore

@Suite struct GeometryTests {
    // Primary 1440x900 at origin, secondary 1920x1080 to the right, bottom-aligned.
    let screens = [CGRect(x: 0, y: 0, width: 1440, height: 900), CGRect(x: 1440, y: 0, width: 1920, height: 1080)]

    @Test func convertsTopLeftToCocoa() {
        let rect = Geometry.cocoaRect(fromTopLeft: CGRect(x: 10, y: 100, width: 200, height: 300), primaryScreenHeight: 900)
        #expect(rect == CGRect(x: 10, y: 500, width: 200, height: 300))
    }

    @Test func picksScreenWithLargestOverlap() {
        #expect(Geometry.bestScreenIndex(for: CGRect(x: 1300, y: 100, width: 400, height: 300), screens: screens) == 1)
        #expect(Geometry.bestScreenIndex(for: CGRect(x: 1000, y: 100, width: 400, height: 300), screens: screens) == 0)
        #expect(Geometry.bestScreenIndex(for: CGRect(x: -500, y: 0, width: 100, height: 100), screens: screens) == nil)
    }

    @Test func screenContainingPointIncludesTopEdge() {
        #expect(Geometry.screenIndex(containing: CGPoint(x: 2000, y: 1080), screens: screens) == 1)
        #expect(Geometry.screenIndex(containing: CGPoint(x: 100, y: 100), screens: screens) == 0)
        #expect(Geometry.screenIndex(containing: CGPoint(x: -1, y: 100), screens: screens) == nil)
    }

    @Test func glowFrameHugsSide() {
        #expect(Geometry.glowFrame(screen: screens[1], side: .left, width: 100) == CGRect(x: 1440, y: 0, width: 100, height: 1080))
        #expect(Geometry.glowFrame(screen: screens[1], side: .right, width: 100) == CGRect(x: 3260, y: 0, width: 100, height: 1080))
        #expect(Geometry.glowFrame(screen: screens[0], side: .right, width: 5000) == screens[0])
    }
}

@Suite struct GlowParametersTests {
    @Test func monotonicInSizeAndDensity() {
        let widths = GlowSize.allCases.map { GlowParameters(style: style(size: $0)).width }
        #expect(widths == widths.sorted() && Set(widths).count == widths.count)
        let opacities = GlowDensity.allCases.map { GlowParameters(style: style(density: $0)).peakOpacity }
        #expect(opacities == opacities.sorted() && Set(opacities).count == opacities.count)
    }

    @Test func speedScalesDuration() {
        let durations = GlowSpeed.allCases.map { GlowParameters(style: style(speed: $0)).totalDuration }
        #expect(durations == durations.sorted(by: >))
    }

    @Test func flairIncreasesEnergy() {
        let params = GlowFlair.allCases.map { GlowParameters(style: style(flair: $0)) }
        #expect(params.map(\.initialScale) == params.map(\.initialScale).sorted(by: >))
        #expect(params.map(\.coreOpacity) == params.map(\.coreOpacity).sorted())
        #expect(params.allSatisfy { $0.maxScale >= $0.peakScale && $0.maxScale >= $0.trailingScale })
    }

    private func style(
        size: GlowSize = .medium, density: GlowDensity = .medium, flair: GlowFlair = .normal, speed: GlowSpeed = .normal
    ) -> GlowStyle {
        GlowStyle(size: size, density: density, flair: flair, speed: speed, color: .preset(.gray))
    }
}

@Suite struct IPCTests {
    @Test func envelopeRoundTrips() {
        let envelope = RequestEnvelope(id: "abc", command: .flash(FlashRequest(side: .right, display: .index(2), style: .standard)))
        #expect(IPCCodec.encode(envelope).flatMap { IPCCodec.decode(RequestEnvelope.self, from: $0) } == envelope)
        let ack = AckEnvelope(id: "abc", error: "nope", output: "text")
        #expect(IPCCodec.encode(ack).flatMap { IPCCodec.decode(AckEnvelope.self, from: $0) } == ack)
    }
}
