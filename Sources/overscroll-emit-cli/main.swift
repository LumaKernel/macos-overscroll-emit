import AppKit
import OverscrollEmitCore

// Lives at OverscrollEmit.app/Contents/Helpers/overscroll-emit (usually symlinked onto PATH).
// Effects are rendered by the resident app (it owns the overlay windows);
// this process only forwards requests to it, launching it in the background if needed.

func fail(_ message: String, code: Int32 = 1) -> Never {
    FileHandle.standardError.write(Data("overscroll-emit: \(message)\n".utf8))
    exit(code)
}

func appBundleURL() -> URL {
    guard let executable = Bundle.main.executableURL?.resolvingSymlinksInPath() else {
        fail("cannot determine executable path")
    }
    // Contents/Helpers/overscroll-emit -> OverscrollEmit.app
    let bundle = executable.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    guard bundle.pathExtension == "app" else {
        fail("must be run from inside OverscrollEmit.app (Contents/Helpers/overscroll-emit), but found at \(executable.path)")
    }
    return bundle
}

func printVersion() {
    guard let info = Bundle(url: appBundleURL())?.infoDictionary,
        let version = info["CFBundleShortVersionString"] as? String,
        let build = info[buildInfoKey] as? String
    else { fail("cannot read Info.plist of \(appBundleURL().path)") }
    print("overscroll-emit \(version) (build \(build))")
}

@MainActor
final class AckBox {
    var ack: AckEnvelope?
    var launchError: String?
}

@MainActor
func send(_ command: AppCommand) -> Never {
    let id = UUID().uuidString
    guard let payload = IPCCodec.encode(RequestEnvelope(id: id, command: command)) else { fail("cannot encode request") }
    let box = AckBox()
    let center = DistributedNotificationCenter.default()
    let observer = center.addObserver(forName: IPC.ackName, object: nil, queue: .main) { notification in
        let ack = (notification.userInfo?[IPC.payloadKey] as? String).flatMap { IPCCodec.decode(AckEnvelope.self, from: $0) }
        MainActor.assumeIsolated {
            if let ack, ack.id == id { box.ack = ack }
        }
    }
    defer { center.removeObserver(observer) }

    let running = !NSRunningApplication.runningApplications(withBundleIdentifier: IPC.bundleIdentifier).isEmpty
    if !running {
        if command == .quit { exit(0) }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        configuration.addsToRecentItems = false
        configuration.arguments = [IPC.backgroundLaunchArgument]
        NSWorkspace.shared.openApplication(at: appBundleURL(), configuration: configuration) { _, error in
            let message = error?.localizedDescription
            DispatchQueue.main.async { MainActor.assumeIsolated { box.launchError = message } }
        }
    }

    // Re-post until acked: a freshly launched app may not be observing yet.
    let deadline = Date().addingTimeInterval(running ? 2 : 10)
    let repostInterval: TimeInterval = 0.2
    var nextPost = Date.distantPast
    while box.ack == nil && box.launchError == nil && Date() < deadline {
        if Date() >= nextPost {
            center.postNotificationName(IPC.requestName, object: nil, userInfo: [IPC.payloadKey: payload], deliverImmediately: true)
            nextPost = Date().addingTimeInterval(repostInterval)
        }
        RunLoop.main.run(mode: .default, before: Date().addingTimeInterval(0.02))
    }

    if let launchError = box.launchError { fail("failed to launch OverscrollEmit.app: \(launchError)") }
    guard let ack = box.ack else { fail("OverscrollEmit.app did not respond") }
    if let error = ack.error { fail(error) }
    if let output = ack.output { print(output) }
    if command == .quit {
        // Wait for the process to exit so an immediately following command relaunches it instead of
        // posting to an instance that is shutting down.
        let quitDeadline = Date().addingTimeInterval(5)
        while !NSRunningApplication.runningApplications(withBundleIdentifier: IPC.bundleIdentifier).isEmpty {
            guard Date() < quitDeadline else { fail("OverscrollEmit.app acknowledged quit but is still running") }
            RunLoop.main.run(mode: .default, before: Date().addingTimeInterval(0.05))
        }
    }
    exit(0)
}

switch CLIParser.parse(Array(CommandLine.arguments.dropFirst())) {
case .failure(let error):
    FileHandle.standardError.write(Data("overscroll-emit: \(error.message)\n\n\(CLIUsage.text)\n".utf8))
    exit(2)
case .success(.help):
    print(CLIUsage.text)
case .success(.version):
    printVersion()
case .success(.send(let command)):
    send(command)
}
