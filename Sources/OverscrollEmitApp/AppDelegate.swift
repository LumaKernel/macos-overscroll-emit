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
            guard let self else { return "app is shutting down" }
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

    /// Returns an error message, or nil on success.
    private func handle(_ command: AppCommand) -> String? {
        switch command {
        case .flash(let request):
            switch ScreenResolver.resolve(request.display) {
            case .success(let screen):
                presenter.present(on: screen, side: request.side, style: request.style)
                return nil
            case .failure(let error):
                return error.message
            }
        case .settings:
            settings.show()
            return nil
        case .quit:
            // Let the ack go out before terminating.
            DispatchQueue.main.async { NSApp.terminate(nil) }
            return nil
        }
    }

    private static func launchedAsLoginItem() -> Bool {
        guard let event = NSAppleEventManager.shared().currentAppleEvent else { return false }
        return event.eventID == kAEOpenApplication
            && event.paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue == keyAELaunchedAsLogInItem
    }
}
