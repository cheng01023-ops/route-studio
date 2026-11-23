import SwiftUI
import AppKit

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    static var model: StudioModel?
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let model = Self.model else { return .terminateNow }
        model.prepareQuit { NSApp.reply(toApplicationShouldTerminate: true) }
        return .terminateLater
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
    func applicationDidFinishLaunching(_ notification: Notification) { NSApp.activate(ignoringOtherApps: true) }
}

@main struct RouteStudioApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var model = StudioModel()
    var body: some Scene {
        WindowGroup {
            ContentView(model: model).onAppear { AppDelegate.model = model }
        }
        .defaultSize(width: 1210, height: 870)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("导入路线…") { model.importRoute() }.keyboardShortcut("o").disabled(model.locked)
                Button("保存路线…") { model.exportRoute(gpx: false) }.keyboardShortcut("s").disabled(model.route.points.isEmpty)
            }
            CommandGroup(replacing: .undoRedo) { Button("撤销路线修改") { model.undo() }.keyboardShortcut("z").disabled(model.undoStack.isEmpty || model.locked) }
        }
    }
}
