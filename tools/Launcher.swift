import AppKit
import Foundation

/// A local Finder entry point. It only opens the adjacent application; it never
/// sends device, route, location, or playback commands to Route Studio.
@MainActor
final class LauncherDelegate: NSObject, NSApplicationDelegate {
    private let targetIdentifier = "local.codex.RouteStudio"

    func applicationDidFinishLaunching(_ notification: Notification) {
        let applicationURL = Bundle.main.bundleURL
            .deletingLastPathComponent()
            .appendingPathComponent("Route Studio.app", isDirectory: true)
            .standardizedFileURL
            .resolvingSymlinksInPath()

        guard let bundle = Bundle(url: applicationURL),
              bundle.bundleIdentifier == targetIdentifier,
              let executable = bundle.executableURL,
              FileManager.default.isExecutableFile(atPath: executable.path) else {
            showError("未找到定位工具", detail: "请完整解压安装包，并把本入口和 Route Studio.app 放在同一文件夹。")
            return
        }

        let existing = NSWorkspace.shared.runningApplications.first { application in
            guard application.bundleIdentifier == targetIdentifier,
                  let url = application.bundleURL else { return false }
            return url.standardizedFileURL.resolvingSymlinksInPath().path == applicationURL.path
        }
        if let existing {
            existing.activate(options: [.activateAllWindows])
            NSApp.terminate(nil)
            return
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        configuration.createsNewApplicationInstance = false
        NSWorkspace.shared.openApplication(at: applicationURL, configuration: configuration) { _, error in
            Task { @MainActor in
                if let error {
                    self.showError("无法打开定位工具", detail: error.localizedDescription)
                } else {
                    NSApp.terminate(nil)
                }
            }
        }
    }

    private func showError(_ title: String, detail: String) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = detail
        alert.alertStyle = .warning
        alert.addButton(withTitle: "知道了")
        alert.runModal()
        NSApp.terminate(nil)
    }
}

@main
struct RouteStudioLauncher {
    @MainActor static func main() {
        let application = NSApplication.shared
        let delegate = LauncherDelegate()
        application.delegate = delegate
        application.setActivationPolicy(.accessory)
        withExtendedLifetime(delegate) {
            application.run()
        }
    }
}
