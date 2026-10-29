import AppKit
import OverscrollEmitCore

let app = NSApplication.shared
let delegate = AppDelegate(launchedByCLI: CommandLine.arguments.contains(IPC.backgroundLaunchArgument))
app.delegate = delegate
app.run()
