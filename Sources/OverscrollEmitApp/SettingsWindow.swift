import AppKit
import ApplicationServices
import OverscrollEmitCore
import ServiceManagement
import SwiftUI

@MainActor
final class SettingsWindowController {
    private let presenter: GlowPresenter
    private var window: NSWindow?

    init(presenter: GlowPresenter) {
        self.presenter = presenter
    }

    func show() {
        let window = self.window ?? makeWindow()
        self.window = window
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    private func makeWindow() -> NSWindow {
        let model = SettingsModel(presenter: presenter)
        let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsView(model: model)))
        window.title = "\(AppInfo.titleLabel) Settings"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false
        window.center()
        return window
    }
}

@MainActor
@Observable
final class SettingsModel {
    private let presenter: GlowPresenter

    private(set) var accessibilityTrusted = AXIsProcessTrusted()
    private(set) var loginItemStatus = SMAppService.mainApp.status
    private(set) var loginItemError: String?

    // Sync: one property (and a picker in `SettingsView`) per `GlowStyle` field.
    var size = GlowStyle.standard.size
    var density = GlowStyle.standard.density
    var flair = GlowStyle.standard.flair
    var speed = GlowStyle.standard.speed
    var colorChoice = ColorChoice(GlowStyle.standard.color)
    /// Used when `colorChoice` is `.custom`.
    var customColor = Color(red: 1, green: 0.4, blue: 0.7)

    var commandForm: CommandForm {
        didSet { UserDefaults.standard.set(commandForm.rawValue, forKey: Self.commandFormKey) }
    }

    private static let commandFormKey = "commandForm"

    init(presenter: GlowPresenter) {
        self.presenter = presenter
        commandForm = UserDefaults.standard.string(forKey: Self.commandFormKey).flatMap(CommandForm.init(rawValue:)) ?? .onPath
    }

    var color: GlowColor {
        switch colorChoice {
        case .preset(let preset): .preset(preset)
        case .rainbow: .rainbow
        case .custom: .custom(GlowRGB(NSColor(customColor)))
        }
    }

    var style: GlowStyle { GlowStyle(size: size, density: density, flair: flair, speed: speed, color: color) }

    var cliPath: String { Bundle.main.bundleURL.appendingPathComponent("Contents/Helpers/overscroll-emit").path }

    var symlinkCommand: String { CLIFormatter.shellCommand(["ln", "-sf", cliPath, "/usr/local/bin/overscroll-emit"]) }

    func refresh() {
        accessibilityTrusted = AXIsProcessTrusted()
        loginItemStatus = SMAppService.mainApp.status
    }

    func requestAccessibility() {
        // Literal value of kAXTrustedCheckOptionPrompt (the global is not concurrency-safe in Swift 6).
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        accessibilityTrusted = AXIsProcessTrustedWithOptions(options)
    }

    func openAccessibilitySettings() {
        open("x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
    }

    func openLoginItemsSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            loginItemError = nil
        } catch {
            loginItemError = error.localizedDescription
        }
        refresh()
    }

    func preview(_ side: Side) {
        guard case .success(let screen) = ScreenResolver.resolve(.active) else { return }
        presenter.present(on: screen, side: side, style: style)
    }

    func command(for side: Side) -> String {
        let executable =
            switch commandForm {
            case .onPath: "overscroll-emit"
            case .fullPath: cliPath
            }
        return CLIFormatter.shellCommand(
            [executable] + CLIFormatter.arguments(for: FlashRequest(side: side, display: .active, style: style)))
    }

    func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func open(_ url: String) {
        guard let url = URL(string: url) else { return }
        NSWorkspace.shared.open(url)
    }
}

struct SettingsView: View {
    @Bindable var model: SettingsModel

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section("Permissions") {
                    LabeledContent("Accessibility") {
                        HStack {
                            StatusBadge(ok: model.accessibilityTrusted, okText: "Granted", ngText: "Not granted")
                            if !model.accessibilityTrusted {
                                Button("Request…") { model.requestAccessibility() }
                            }
                            Button("Open Settings") { model.openAccessibilitySettings() }
                        }
                    }
                    Text(
                        "Optional. `--display active` uses the display with the active menu bar; Accessibility is only a fallback for finding the focused window if that lookup fails."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Section("General") {
                    Toggle(
                        "Launch at login",
                        isOn: Binding(
                            get: { model.loginItemStatus == .enabled || model.loginItemStatus == .requiresApproval },
                            set: { model.setLaunchAtLogin($0) }
                        ))
                    if model.loginItemStatus == .requiresApproval {
                        HStack {
                            Text("Needs approval in System Settings › Login Items.").font(.caption)
                            Button("Open") { model.openLoginItemsSettings() }
                        }
                    }
                    if let error = model.loginItemError {
                        Text(error).font(.caption).foregroundStyle(.red)
                    }
                }

                Section("Command line") {
                    LabeledContent("CLI") {
                        Text(model.cliPath).textSelection(.enabled).font(.caption.monospaced())
                    }
                    Picker("Copy commands as", selection: $model.commandForm) {
                        Text("overscroll-emit (symlinked on PATH)").tag(CommandForm.onPath)
                        Text("Full path (no symlink)").tag(CommandForm.fullPath)
                    }
                    HStack {
                        Spacer()
                        Button("Copy symlink command") { model.copy(model.symlinkCommand) }
                    }
                }

                Section("Preview") {
                    StylePicker(title: "Size (大きさ)", selection: $model.size)
                    StylePicker(title: "Density (濃さ)", selection: $model.density)
                    StylePicker(title: "Flair (派手さ)", selection: $model.flair)
                    StylePicker(title: "Speed", selection: $model.speed)
                    HStack {
                        Picker("Color", selection: $model.colorChoice) {
                            ForEach(ColorChoice.all, id: \.self) { Text($0.label).tag($0) }
                        }
                        if model.colorChoice == .custom {
                            ColorPicker("Custom color", selection: $model.customColor, supportsOpacity: false).labelsHidden()
                        }
                    }
                    HStack {
                        Button("◀︎ Left") { model.preview(.left) }
                        Button("Right ▶︎") { model.preview(.right) }
                        Spacer()
                        Button("Copy command") { model.copy(model.command(for: .left)) }
                    }
                    Text(model.command(for: .left))
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)

            Divider()
            HStack {
                Text(AppInfo.footerLabel)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .textSelection(.enabled)
                Spacer()
                Button("Quit Overscroll Emit") { NSApp.terminate(nil) }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
        }
        .frame(width: 520, height: 760)
        .task {
            // Permissions can change in System Settings while the window is open.
            while !Task.isCancelled {
                model.refresh()
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }
}

private struct StatusBadge: View {
    let ok: Bool
    let okText: String
    let ngText: String

    var body: some View {
        Label(ok ? okText : ngText, systemImage: ok ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
            .foregroundStyle(ok ? .green : .orange)
    }
}

private struct StylePicker<Value: RawRepresentable & CaseIterable & Hashable>: View
where Value.RawValue == String, Value.AllCases: RandomAccessCollection {
    let title: String
    @Binding var selection: Value

    var body: some View {
        Picker(title, selection: $selection) {
            ForEach(Value.allCases, id: \.self) { Text($0.rawValue).tag($0) }
        }
        .pickerStyle(.segmented)
    }
}

enum CommandForm: String {
    /// Assumes `overscroll-emit` is symlinked onto PATH.
    case onPath
    /// Absolute path into the app bundle; works without a symlink.
    case fullPath
}

/// `GlowColor` without the custom value, so the picker can select "custom" while the color comes from a ColorPicker.
enum ColorChoice: Hashable {
    case preset(GlowColorPreset)
    case rainbow
    case custom

    static let all: [ColorChoice] = GlowColorPreset.allCases.map(ColorChoice.preset) + [.rainbow, .custom]

    init(_ color: GlowColor) {
        switch color {
        case .preset(let preset): self = .preset(preset)
        case .rainbow: self = .rainbow
        case .custom: self = .custom
        }
    }

    var label: String {
        switch self {
        case .preset(let preset): preset.rawValue
        case .rainbow: "rainbow"
        case .custom: "custom…"
        }
    }
}
