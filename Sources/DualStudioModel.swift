import AppKit
import Combine
import Foundation

@MainActor final class DualStudioModel: ObservableObject {
    let a: StudioModel
    let b: StudioModel
    @Published var activeChannel = 0
    @Published private(set) var batchBusy = false
    @Published var batchMessage = "分配两台不同的 iPhone，再分别连接；连接不会开始回放。"
    @Published var error: String?
    private var observations: [AnyCancellable] = []
    private let legacyAppIsRunning: () -> Bool
    private var quitting = false

    var sessions: [StudioModel] { [a, b] }
    var current: StudioModel { sessions[activeChannel] }
    var other: StudioModel { sessions[1 - activeChannel] }
    var allDevices: [DeviceInfo] {
        var result: [String: DeviceInfo] = [:]
        for device in a.devices + b.devices { result[device.id] = device }
        return result.values.sorted { $0.id < $1.id }
    }
    var selectionsAreDistinct: Bool {
        !a.selectedDevice.isEmpty && !b.selectedDevice.isEmpty && a.selectedDevice != b.selectedDevice
    }
    var canConnectBoth: Bool {
        !batchBusy && !quitting && selectionsAreDistinct && sessions.allSatisfy { $0.canConnectAssigned }
    }
    var canStartBoth: Bool { !batchBusy && !quitting && startPreflight() == nil }
    var canPauseOrResumeBoth: Bool { !batchBusy && sessions.contains { $0.active } && !sessions.contains { $0.commandBusy } }
    var batchPauseTitle: String { sessions.contains { $0.state == "playing" } ? "一起暂停" : "一起继续" }
    var canCopyRoute: Bool { !batchBusy && !other.locked && !other.simulated && !other.uncertain }

    init(startServices: Bool = true, preferencesPrefix: String = "local.codex.RouteStudioDual", defaultRouteURL: URL? = nil,
         legacyAppIsRunning: @escaping () -> Bool = {
             NSWorkspace.shared.runningApplications.contains { $0.bundleIdentifier == "local.codex.RouteStudio" }
         }) {
        self.legacyAppIsRunning = legacyAppIsRunning
        a = StudioModel(startServices: startServices, preferences: UserDefaults(suiteName: preferencesPrefix + ".channel.A")!,
                        defaultRouteURL: defaultRouteURL, automaticConnectionEnabled: false, managedDeviceSelection: true)
        b = StudioModel(startServices: startServices, preferences: UserDefaults(suiteName: preferencesPrefix + ".channel.B")!,
                        defaultRouteURL: defaultRouteURL, automaticConnectionEnabled: false, managedDeviceSelection: true)
        for (index, session) in sessions.enumerated() {
            observations.append(session.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() })
            session.operationGuard = { [weak self] command, values in self?.guardOperation(command, values: values, channel: index) }
        }
    }
    func name(_ channel: Int) -> String { channel == 0 ? "A" : "B" }
    func deviceLabel(_ id: String) -> String {
        guard !id.isEmpty else { return "未连接" }
        let label = allDevices.first { $0.id == id }?.name ?? "iPhone"
        return "\(label) · \(id.suffix(6))"
    }
    private func reservations(_ session: StudioModel) -> Set<String> {
        Set([session.selectedDevice, session.connectedDeviceID, session.affectedDeviceID].filter { !$0.isEmpty })
    }
    func availableDevices(for channel: Int) -> [DeviceInfo] {
        let unavailable = reservations(sessions[1 - channel])
        return allDevices.filter { !unavailable.contains($0.id) }
    }
    @discardableResult func assignDevice(_ id: String, to channel: Int) -> Bool {
        guard !batchBusy, !quitting, sessions[channel].canChangeDevice else {
            error = "请先结束通道 \(name(channel)) 的回放并恢复真实定位，再更换设备。"; return false
        }
        guard id.isEmpty || !reservations(sessions[1 - channel]).contains(id) else {
            error = "这台 iPhone 已分配给另一通道，请选择另一台设备。"; return false
        }
        sessions[channel].selectedDevice = id
        return true
    }
    private func legacyConflict() -> String? {
        legacyAppIsRunning() ? "检测到旧版 Route Studio 正在运行。请先退出旧单机版，再连接或开始双设备回放。" : nil
    }
    private func guardOperation(_ command: String, values: [String: Any], channel: Int) -> String? {
        if command == "start" && values["mode"] as? String == "preview" { return nil }
        guard ["connect", "start", "set"].contains(command) else { return nil }
        if let detail = legacyConflict() { return detail }
        let session = sessions[channel]
        let target = command == "connect" ? session.selectedDevice : session.actualDeviceID
        if target.isEmpty { return "请先选择并连接通道 \(name(channel)) 的 iPhone。" }
        if reservations(sessions[1 - channel]).contains(target) { return "设备已被另一通道占用，不能由两个通道同时控制。" }
        if command != "connect" && target != session.selectedDevice {
            return "所选设备与实际连接目标不同，请先点击连接所选设备。"
        }
        return nil
    }
    func startPreflight() -> String? {
        if let detail = legacyConflict() { return detail }
        guard selectionsAreDistinct else { return "请为 A、B 分配两台不同的 iPhone。" }
        for (index, session) in sessions.enumerated() {
            guard session.backendReady, session.connected, session.actualDeviceID == session.selectedDevice,
                  session.canPlay, !session.simulated, !session.uncertain, session.state != "holding" else {
                return "通道 \(name(index)) 尚未就绪：请确认实际连接设备、有效路线，并结束之前的回放。"
            }
        }
        return nil
    }
    func refreshDevices() {
        guard !batchBusy else { return }
        for session in sessions where !session.locked { session.scan() }
    }
    func connectChannel(_ channel: Int) async {
        guard !batchBusy, !quitting else { return }
        let result = await sessions[channel].connectAssigned()
        if !result.0 { error = "通道 \(name(channel))：\(result.1 ?? "连接失败")" }
    }
    func disconnectChannel(_ channel: Int) async {
        let session = sessions[channel]
        guard !batchBusy, !quitting, session.canChangeDevice else { return }
        let result = await session.request("disconnect")
        if result.0 { session.connectedDeviceID = ""; session.connected = false }
        else { error = "通道 \(name(channel))：\(result.1 ?? "断开失败")" }
    }
    func connectBoth() async {
        guard canConnectBoth else { error = "请为两个空闲通道分配不同的设备。"; return }
        if let detail = legacyConflict() { error = detail; return }
        batchBusy = true; defer { batchBusy = false }
        batchMessage = "正在分别连接 A、B；连接完成后不会自动开始。"
        let left = Task { await self.a.connectAssigned() }
        let right = Task { await self.b.connectAssigned() }
        let results = [await left.value, await right.value]
        report(results, success: "两台设备已连接。检查各自路线和配速，然后点“一起开始”。", failure: "部分设备连接失败")
    }
    func startBoth() async {
        guard !batchBusy, !quitting else { return }
        if let detail = startPreflight() { error = detail; batchMessage = detail; return }
        batchBusy = true; defer { batchBusy = false }
        batchMessage = "正在启动两条独立路线…"
        let left = Task { await self.a.startAssigned() }
        let right = Task { await self.b.startAssigned() }
        let results = [await left.value, await right.value]
        guard results.allSatisfy({ $0.0 }) else {
            // Both requests may have reached a phone, including the one reporting an error.
            let cleanup = await stopSessions()
            let details = failures(results) + failures(cleanup).map { "恢复：" + $0 }
            batchMessage = "一起开始失败，已尝试停止并恢复两个通道。" + details.joined(separator: "；")
            error = batchMessage
            return
        }
        batchMessage = "两台正在按各自路线与配速回放；可以切换通道查看，后台会继续。"
    }
    func pauseOrResumeBoth() async {
        guard canPauseOrResumeBoth, !quitting else { return }
        batchBusy = true; defer { batchBusy = false }
        let pause = sessions.contains { $0.state == "playing" }
        var results: [(Bool, String?)] = [(true, nil), (true, nil)]
        let tasks = sessions.enumerated().compactMap { index, session -> (Int, Task<(Bool, String?), Never>)? in
            guard session.state == (pause ? "playing" : "paused") else { return nil }
            return (index, Task { await session.request(pause ? "pause" : "resume") })
        }
        for (index, task) in tasks { results[index] = await task.value }
        report(results, success: pause ? "两个通道已暂停；位置保持，各自计时冻结。" : "已继续各通道回放。", failure: "部分通道操作失败")
    }
    private func stopSessions() async -> [(Bool, String?)] {
        let tasks = sessions.map { session in Task { @MainActor in await session.restoreForQuit() } }
        var results: [(Bool, String?)] = []
        for task in tasks { results.append(await task.value) }
        return results
    }
    func stopBoth() async {
        guard !batchBusy, !quitting else { return }
        batchBusy = true; defer { batchBusy = false }
        let results = await stopSessions()
        report(results, success: "已结束两个通道并发送恢复指令，请在两台手机地图中确认。", failure: "部分通道恢复未确认")
    }
    @discardableResult func copyCurrentRoute() -> Bool {
        guard canCopyRoute else { error = "目标通道正在运行或恢复未确认，请先结束并恢复定位。"; return false }
        other.remember(); other.route = current.route
        other.selectedPoint = nil; other.currentPoint = nil; other.fitRevision += 1
        batchMessage = "已将通道 \(name(activeChannel)) 的路线与配速复制到通道 \(name(1 - activeChannel))。"
        return true
    }
    private func failures(_ results: [(Bool, String?)]) -> [String] {
        results.enumerated().compactMap { index, result in result.0 ? nil : "\(name(index))：\(result.1 ?? "操作失败")" }
    }
    private func report(_ results: [(Bool, String?)], success: String, failure: String) {
        let details = failures(results)
        batchMessage = details.isEmpty ? success : failure + "：" + details.joined(separator: "；")
        if !details.isEmpty { error = batchMessage }
    }
    // Returns only after both sessions have attempted restoration. It never replies to NSApp itself.
    func restoreForExit() async -> [(Bool, String?)] {
        quitting = true; batchBusy = true
        sessions.forEach { $0.quiesceForQuit() }
        return await stopSessions()
    }
    func cancelExit() {
        quitting = false; batchBusy = false
        sessions.forEach { $0.resumeAfterCancelledQuit() }
    }
    func closeBackends(force: Bool = false) async {
        if force { sessions.forEach { $0.forceTerminateBackend() }; return }
        let tasks = sessions.map { session in Task { @MainActor in await session.quitBackend() } }
        for task in tasks {
            let result = await task.value
            if !result.0 { sessions.forEach { $0.forceTerminateBackend() } }
        }
    }
    func prepareQuit(_ finish: @escaping (Bool) -> Void) {
        guard !quitting, !batchBusy else { finish(false); return }
        Task { @MainActor in
            let results = await restoreForExit()
            if results.contains(where: { !$0.0 }) {
                let alert = NSAlert(); alert.messageText = "部分通道尚未确认恢复定位"
                alert.informativeText = failures(results).joined(separator: "\n") + "\n请重新连接并恢复，或重启对应 iPhone。"
                alert.addButton(withTitle: "返回应用"); alert.addButton(withTitle: "退出并手动处理")
                if alert.runModal() != .alertSecondButtonReturn { cancelExit(); finish(false); return }
                await closeBackends(force: true)
            } else { await closeBackends() }
            finish(true)
        }
    }
}
