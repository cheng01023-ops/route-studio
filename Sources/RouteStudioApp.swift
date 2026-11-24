import SwiftUI
import AppKit

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    static var model: DualStudioModel?
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let model = Self.model else { return .terminateNow }
        model.prepareQuit { allowed in NSApp.reply(toApplicationShouldTerminate: allowed) }
        return .terminateLater
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
    func applicationDidFinishLaunching(_ notification: Notification) { NSApp.activate(ignoringOtherApps: true) }
}

@main struct RouteStudioApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var model = DualStudioModel()
    var body: some Scene {
        WindowGroup {
            DualContentView(model: model).onAppear { AppDelegate.model = model }
        }
        .defaultSize(width: 1300, height: 930)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("导入当前通道路线…") { model.current.importRoute() }.keyboardShortcut("o").disabled(model.current.locked || model.batchBusy)
                Button("保存当前通道路线…") { model.current.exportRoute(gpx: false) }.keyboardShortcut("s").disabled(model.current.route.points.isEmpty)
            }
            CommandGroup(replacing: .undoRedo) {
                Button("撤销当前通道路线修改") { model.current.undo() }.keyboardShortcut("z").disabled(model.current.undoStack.isEmpty || model.current.locked || model.batchBusy)
            }
        }
    }
}
