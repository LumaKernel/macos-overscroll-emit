import AppKit
import OverscrollEmitCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let launchedByCLI: Bool
    private let presenter = GlowPresenter()
    private lazy var settings = SettingsWindowController(presenter: presenter)
    private var server: RequestServer?

    init(launchedByCLI: Bool) {
        self.launchedByCLI = launchedByCLI
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        server = RequestServer { [weak self] command in
            guard let self else { return .failure(CommandFailure(message: "app is shutting down")) }
            return self.handle(command)
        }
        // Manual launch (Finder / open) shows settings; CLI-triggered and login launches stay silent.
        if !launchedByCLI && !Self.launchedAsLoginItem() {
            settings.show()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        settings.show()
        return false
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    /// Success carries optional text for the CLI to print.
    private func handle(_ command: AppCommand) -> Result<String?, CommandFailure> {
        switch command {
        case .flash(let request):
            return ScreenResolver.resolve(request.display)
                .map { screen in
                    presenter.present(on: screen, side: request.side, style: request.style)
                    return nil
                }
                .mapError { CommandFailure(message: $0.message) }
        case .settings:
            settings.show()
            return .success(nil)
        case .quit:
            // Let the ack go out before terminating.
            DispatchQueue.main.async { NSApp.terminate(nil) }
            return .success(nil)
        case .describeDisplays:
            return .success(ScreenResolver.describe())
        }
    }

    private static func launchedAsLoginItem() -> Bool {
        guard let event = NSAppleEventManager.shared().currentAppleEvent else { return false }
        return event.eventID == kAEOpenApplication
            && event.paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue == keyAELaunchedAsLogInItem
    }
}
