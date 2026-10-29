import Foundation
import OverscrollEmitCore

/// Version info from Info.plist (filled by scripts/build.sh from VERSION).
/// Versions are always `{MAJOR}.0.0`; see CLAUDE.md "Versioning".
struct AppInfo: Equatable {
    let version: String
    let build: String

    /// e.g. "v1"
    var majorLabel: String { "v" + (version.split(separator: ".").first.map(String.init) ?? version) }

    /// nil when running outside the app bundle (e.g. `swift run`).
    static let current: AppInfo? = {
        guard let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
            let build = Bundle.main.object(forInfoDictionaryKey: buildInfoKey) as? String
        else { return nil }
        return AppInfo(version: version, build: build)
    }()

    static var titleLabel: String { current.map { "Overscroll Emit \($0.majorLabel)" } ?? "Overscroll Emit (unbundled)" }
    static var footerLabel: String { current.map { "Version \($0.version) (Build \($0.build))" } ?? "Unbundled build" }
}
