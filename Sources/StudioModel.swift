import Foundation
import AppKit
import MapKit
import Combine
import UniformTypeIdentifiers

@MainActor final class StudioModel: ObservableObject {
    @Published var route = RouteDocument() { didSet { saveDraft() } }
    @Published var selectedPoint: UUID?
    @Published var editMode = true
    @Published var devices: [DeviceInfo] = []
    @Published var selectedDevice = ""
    @Published var connectedDeviceID = ""
    @Published var affectedDeviceID = ""
    @Published var connected = false
    @Published var backendReady = false
    @Published var state = "idle"
    @Published var mode = "preview"
    @Published var message = "先画一条路线，或导入已有 GPX 文件。"
    @Published var simulated = false
    @Published var uncertain = false
    @Published var commandBusy = false
    @Published var scanning = false
    @Published var currentPoint: RoutePoint?
    @Published var elapsed = 0.0
    @Published var travelled = 0.0
    @Published var currentLap = 1
    @Published var playbackDuration = 0.0
    @Published var playbackDistance = 0.0
    @Published var error: String?
    @Published var searchText = ""
    @Published var searchResults: [MKMapItem] = []
    @Published var searching = false
    @Published var focusRequest: CLLocationCoordinate2D?
    @Published var fitRevision = 0
    @Published var mainlandMap = true { didSet { if savesDraft { preferences.set(mainlandMap, forKey: "mainlandMapV1") } } }
    @Published var showSetup = false
    @Published var events: [String] = []
    @Published var undoStack: [RouteDocument] = []
    var process: Process?
    var input: FileHandle?
    var pending: [String: (Bool, String?) -> Void] = [:]
    var readBuffer = Data()
    var search: MKLocalSearch?
    var termination: (() -> Void)?
    var activity: NSObjectProtocol?
    let preferences: UserDefaults
    let automaticConnectionEnabled: Bool
    let managedDeviceSelection: Bool
    var operationGuard: ((String, [String: Any]) -> String?)?
    private var savesDraft = false
    private var deviceWatch: Task<Void, Never>?
    private var attemptedDevices = Set<String>()
    private var isQuitting = false

    var active: Bool { ["playing", "paused"].contains(state) }
    var locked: Bool { active || commandBusy || state == "connecting" }
    var canPlay: Bool { backendReady && !locked && route.points.count >= 2 && route.totalDistance >= 1 && (try? route.validated()) != nil }
    var canChangeDevice: Bool { !locked && !simulated && !uncertain && state != "holding" }
    var actualDeviceID: String { connectedDeviceID.isEmpty && connected && !managedDeviceSelection ? selectedDevice : connectedDeviceID }
    var needsRestore: Bool { simulated || uncertain || (mode == "device" && (active || state == "holding")) }
    var canConnectAssigned: Bool {
        guard backendReady, !selectedDevice.isEmpty, !locked, !isQuitting else { return false }
        if canChangeDevice { return true }
        return !connected && !affectedDeviceID.isEmpty && selectedDevice == affectedDeviceID
    }
    var selected: RoutePoint? { route.points.first { $0.id == selectedPoint } }
    var quickStartTitle: String {
        if state == "connecting" { return "正在连接 iPhone…" }
        if commandBusy { return "正在处理…" }
        if active { return state == "paused" ? "继续" : "暂停" }
        if !backendReady { return "正在启动…" }
        if !connected && devices.isEmpty { return "请用 USB 连接 iPhone" }
        return "开始 · \(Int(route.totalDistance.rounded())) 米"
    }
    var canQuickStart: Bool {
        if active { return !commandBusy }
        return canPlay && !uncertain && ((connected && (!managedDeviceSelection || actualDeviceID == selectedDevice)) || (automaticConnectionEnabled && devices.count == 1 && !selectedDevice.isEmpty))
    }
    var statusTitle: String {
        switch state {
        case "playing": return mode == "preview" ? "预览中" : "设备回放中"
        case "paused": return "已暂停"
        case "connecting": return "正在连接"
        case "holding": return "固定位置中"
        case "completed": return "已完成"
        case "error": return "需要检查"
        case "disconnected": return "连接已断开"
        default: return connected ? "设备就绪" : "离线模式"
        }
    }

    func mapCoordinate(_ point: RoutePoint) -> CLLocationCoordinate2D {
        (mainlandMap ? Coordinates.wgsToGCJ(point) : point).coordinate
    }
    func gpsCoordinate(_ coordinate: CLLocationCoordinate2D) -> CLLocationCoordinate2D {
        (mainlandMap ? Coordinates.gcjToWGS(RoutePoint(coordinate)) : RoutePoint(coordinate)).coordinate
    }
    init(startServices: Bool = true, preferences: UserDefaults = .standard, defaultRouteURL: URL? = nil, automaticConnectionEnabled: Bool = true, managedDeviceSelection: Bool = false) {
        self.preferences = preferences
        self.automaticConnectionEnabled = automaticConnectionEnabled
        self.managedDeviceSelection = managedDeviceSelection
        if let saved = preferences.data(forKey: "routeDraftV1"), let restored = try? JSONDecoder().decode(RouteDocument.self, from: saved).validated() {
            route = restored
            message = "已载入上次路线，连接 iPhone 后点开始。"
        } else if let url = defaultRouteURL ?? Bundle.main.url(forResource: "DefaultRoute", withExtension: "json"), let initial = try? RouteFiles.load(url) {
            route = initial
            message = "已载入南区田径场 1000 米路线，连接 iPhone 后点开始。"
        }
        if preferences.object(forKey: "mainlandMapV1") != nil { mainlandMap = preferences.bool(forKey: "mainlandMapV1") }
        savesDraft = true
        fitRevision = route.points.isEmpty ? 0 : 1
        if startServices { launchBackend() }
    }
    func saveDraft() {
        guard savesDraft, let data = try? RouteFiles.json(route) else { return }
        preferences.set(data, forKey: "routeDraftV1")
    }
    func startDeviceWatch() {
        deviceWatch?.cancel()
        deviceWatch = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3))
                guard !Task.isCancelled, let self, !self.isQuitting else { return }
                if self.backendReady && !self.connected && !self.locked && !self.simulated && !self.uncertain {
                    self.scan(automatic: true)
                }
            }
        }
    }
    func maybeAutoConnect() {
        let present = Set(devices.map(\.id))
        attemptedDevices.formIntersection(present)
        guard automaticConnectionEnabled, backendReady, !isQuitting, !connected, !locked, !simulated, !uncertain,
              devices.count == 1, let device = devices.first, !attemptedDevices.contains(device.id) else { return }
        selectedDevice = device.id
        connect()
    }
    func quickStart() {
        guard canQuickStart else { return }
        if active { send(state == "paused" ? "resume" : "pause"); return }
        if connected { play(preview: false); return }
        connect(startAfterConnecting: true)
    }
    func log(_ text: String) {
        let time = DateFormatter(); time.dateFormat = "HH:mm:ss"
        events.append("\(time.string(from: Date()))  \(text)")
        if events.count > 150 { events.removeFirst(events.count - 150) }
    }
    func launchBackend() {
        guard let resources = Bundle.main.resourceURL else { error = "找不到应用资源。"; return }
        let executable = resources.appendingPathComponent("Bridge/RouteBridge")
        guard FileManager.default.isExecutableFile(atPath: executable.path) else { error = "定位组件缺失，请重新构建应用。"; return }
        let process = Process(), stdin = Pipe(), stdout = Pipe(), stderr = Pipe()
        process.executableURL = executable
        process.standardInput = stdin; process.standardOutput = stdout; process.standardError = stderr
        var environment = ProcessInfo.processInfo.environment
        environment["PYTHONUNBUFFERED"] = "1"
        process.environment = environment
        stdout.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { handle.readabilityHandler = nil; return }
            Task { @MainActor in self?.receive(data) }
        }
        stderr.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { handle.readabilityHandler = nil; return }
            let text = String(decoding: data, as: UTF8.self)
            Task { @MainActor in
                for line in text.split(separator: "\n").suffix(5) { self?.log(String(line.prefix(300))) }
            }
        }
        process.terminationHandler = { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.handleBackendTermination()
            }
        }
        do { try process.run(); self.process = process; input = stdin.fileHandleForWriting }
        catch { self.error = "无法启动定位组件：\(error.localizedDescription)" }
    }
    func receive(_ data: Data) {
        readBuffer.append(data)
        while let newline = readBuffer.firstIndex(of: 10) {
            let line = readBuffer[..<newline]; readBuffer.removeSubrange(...newline)
            guard let json = try? JSONSerialization.jsonObject(with: line) as? [String: Any], let event = json["event"] as? String else { continue }
            switch event {
            case "hello": backendReady = true; log("定位组件就绪"); scan(automatic: true); startDeviceWatch()
            case "devices":
                let previousIDs = devices.map(\.id)
                devices = (json["devices"] as? [[String: Any]] ?? []).compactMap { x in
                    guard let id = x["id"] as? String else { return nil }
                    return DeviceInfo(id: id, name: x["name"] as? String ?? "iPhone", version: x["version"] as? String ?? "")
                }
                if !managedDeviceSelection && !devices.contains(where: { $0.id == selectedDevice }) { selectedDevice = devices.first?.id ?? "" }
                if previousIDs != devices.map(\.id) { log(devices.isEmpty ? "等待 USB 连接" : "发现 \(devices.count) 台 USB 设备") }
                maybeAutoConnect()
            case "status":
                state = json["state"] as? String ?? state; mode = json["mode"] as? String ?? mode
                connected = json["connected"] as? Bool ?? connected
                if let serial = json["serial"] as? String { connectedDeviceID = serial }
                else if !connected { connectedDeviceID = "" }
                if let serial = json["affectedSerial"] as? String { affectedDeviceID = serial }
                simulated = json["simulated"] as? Bool ?? simulated
                uncertain = json["uncertain"] as? Bool ?? uncertain
                if !simulated && !uncertain { affectedDeviceID = "" }
                message = json["message"] as? String ?? message
                if state == "disconnected" { attemptedDevices.remove(selectedDevice) }
                if mode == "device", !simulated, !uncertain { currentPoint = nil }
                if active, activity == nil {
                    activity = ProcessInfo.processInfo.beginActivity(options: [.userInitiated, .idleSystemSleepDisabled], reason: "保持路线回放连接")
                } else if !active, let token = activity {
                    ProcessInfo.processInfo.endActivity(token); activity = nil
                }
                log(message)
            case "position":
                if let lat = json["latitude"] as? Double, let lon = json["longitude"] as? Double { currentPoint = RoutePoint(latitude: lat, longitude: lon) }
                elapsed = json["elapsed"] as? Double ?? 0; travelled = json["distance"] as? Double ?? 0
                currentLap = json["lap"] as? Int ?? 1
                playbackDuration = json["duration"] as? Double ?? 0; playbackDistance = json["totalDistance"] as? Double ?? 0
            case "response":
                if let id = json["id"] as? String, let callback = pending.removeValue(forKey: id) { callback(json["ok"] as? Bool ?? false, json["message"] as? String) }
            case "shutdown_warning": log(json["message"] as? String ?? "请检查手机定位。")
            default: break
            }
        }
    }
    func send(_ command: String, values: [String: Any] = [:], busy: Bool = true, showError: Bool = true, completion: ((Bool, String?) -> Void)? = nil) {
        guard backendReady, let input else {
            let detail = "定位组件尚未就绪。"
            if showError { error = detail }; completion?(false, detail); return
        }
        if let detail = operationGuard?(command, values) {
            if showError { error = detail }; completion?(false, detail); return
        }
        let id = UUID().uuidString
        var object = values; object["id"] = id; object["command"] = command
        guard var data = try? JSONSerialization.data(withJSONObject: object) else {
            let detail = "命令参数无法编码。"; if showError { error = detail }; completion?(false, detail); return
        }
        data.append(10)
        let requiredDeviceRestore = needsRestore
        let timeoutTarget = actualDeviceID
        if command == "set" || (command == "start" && values["mode"] as? String == "device") {
            // The phone may accept the first write before the bridge can publish a status.
            uncertain = true
            affectedDeviceID = actualDeviceID
        }
        if busy { commandBusy = true }
        pending[id] = { [weak self] success, detail in
            if busy { self?.commandBusy = false }
            if !success { if showError { self?.error = detail ?? "操作失败。" }; self?.log(detail ?? "操作失败") }
            completion?(success, detail)
        }
        do { try input.write(contentsOf: data) }
        catch {
            let callback = pending.removeValue(forKey: id)
            if showError { self.error = error.localizedDescription }
            callback?(false, error.localizedDescription)
        }
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(command == "connect" ? 315 : (command == "quit" ? 30 : 20)))
            guard let self, let callback = self.pending.removeValue(forKey: id) else { return }
            self.markUnconfirmedTimeout(command, values: values, requiredDeviceRestore: requiredDeviceRestore, target: timeoutTarget)
            callback(false, "操作等待超时，请检查设备连接；若曾模拟定位，请恢复真实定位。")
        }
    }
    func scan(automatic: Bool = false) {
        guard backendReady, !scanning else { return }
        scanning = true
        send("scan", busy: false, showError: !automatic) { [weak self] _, _ in self?.scanning = false }
    }
    func connect(startAfterConnecting: Bool = false) {
        guard canConnectAssigned else { return }
        let target = selectedDevice
        attemptedDevices.insert(target)
        send("connect", values: ["device": target]) { [weak self] success, _ in
            guard let self, success else { return }
            self.connectedDeviceID = target
            if startAfterConnecting && !self.isQuitting { self.play(preview: false) }
        }
    }
    func play(preview: Bool) {
        guard canPlay else { return }
        if preview && (simulated || uncertain) { error = "请先恢复真实定位，再进行离线预览。"; return }
        elapsed = 0; travelled = 0; playbackDuration = route.duration; playbackDistance = route.totalDistance
        send("start", values: ["mode": preview ? "preview" : "device", "route": route.payload])
    }
    func holdSelected() {
        guard let p = selected else { return }
        send("set", values: ["point": ["latitude": p.latitude, "longitude": p.longitude]])
    }
    func remember() { undoStack.append(route); if undoStack.count > 100 { undoStack.removeFirst() } }
    func add(_ coordinate: CLLocationCoordinate2D) {
        guard !locked, route.points.count < 10000 else { return }
        remember(); let p = RoutePoint(coordinate); route.points.append(p); selectedPoint = p.id
    }
    func move(_ id: UUID, to coordinate: CLLocationCoordinate2D) {
        guard !locked, let index = route.points.firstIndex(where: { $0.id == id }) else { return }
        remember(); route.points[index].latitude = coordinate.latitude; route.points[index].longitude = coordinate.longitude
    }
    func deleteSelected() {
        guard !locked, let id = selectedPoint else { return }
        remember(); route.points.removeAll { $0.id == id }; selectedPoint = nil
    }
    func undo() { guard !locked, let old = undoStack.popLast() else { return }; route = old; selectedPoint = nil }
    func clear() { guard !locked else { return }; remember(); route.points = []; selectedPoint = nil; currentPoint = nil; travelled = 0; elapsed = 0 }
    func reorder(_ id: UUID, by offset: Int) {
        guard !locked, let i = route.points.firstIndex(where: { $0.id == id }), route.points.indices.contains(i + offset) else { return }
        remember(); route.points.swapAt(i, i + offset)
    }
    func searchPlace() {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        search?.cancel(); searching = true
        let request = MKLocalSearch.Request(); request.naturalLanguageQuery = query
        let search = MKLocalSearch(request: request); self.search = search
        search.start { [weak self, weak search] response, error in
            Task { @MainActor in
                guard let self, self.search === search else { return }
                self.searching = false
                if let response { self.searchResults = Array(response.mapItems.prefix(6)) }
                else if let error { self.error = "搜索失败：\(error.localizedDescription)" }
            }
        }
    }
    func importRoute() {
        let panel = NSOpenPanel(); panel.allowedContentTypes = [.json, UTType(filenameExtension: "gpx") ?? .xml]; panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { let document = try RouteFiles.load(url); remember(); route = document; selectedPoint = nil; currentPoint = nil; fitRevision += 1; log("已导入路线：\(document.name)") }
        catch { self.error = error.localizedDescription }
    }
    func exportRoute(gpx: Bool) {
        let panel = NSSavePanel(); panel.allowedContentTypes = [gpx ? (UTType(filenameExtension: "gpx") ?? .xml) : .json]
        panel.nameFieldStringValue = "\(route.name.isEmpty ? "我的路线" : route.name).\(gpx ? "gpx" : "json")"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { try (gpx ? RouteFiles.gpx(route) : RouteFiles.json(route)).write(to: url, options: .atomic); log("已保存路线") }
        catch { self.error = error.localizedDescription }
    }
    func loadExample() {
        guard !locked else { return }; remember()
        route = RouteDocument(name: "示例路线 · 上海", points: [
            RoutePoint(latitude: 31.2300, longitude: 121.4700), RoutePoint(latitude: 31.2300, longitude: 121.4720),
            RoutePoint(latitude: 31.2310, longitude: 121.4720), RoutePoint(latitude: 31.2310, longitude: 121.4700)], closed: true)
        selectedPoint = nil; currentPoint = nil; fitRevision += 1
    }
    func markUnconfirmedTimeout(_ command: String, values: [String: Any], requiredDeviceRestore: Bool, target: String) {
        let mayWriteDevice = command == "set" || (command == "start" && values["mode"] as? String == "device")
        let mayRestoreDevice = ["stop", "restore"].contains(command) && requiredDeviceRestore
        guard mayWriteDevice || mayRestoreDevice else { return }
        uncertain = true
        if affectedDeviceID.isEmpty { affectedDeviceID = target }
    }
    func handleBackendTermination() {
        backendReady = false; connected = false; commandBusy = false
        if (simulated || uncertain) && affectedDeviceID.isEmpty { affectedDeviceID = actualDeviceID }
        connectedDeviceID = ""
        deviceWatch?.cancel()
        if let activity { ProcessInfo.processInfo.endActivity(activity); self.activity = nil }
        uncertain = uncertain || simulated
        let callbacks = Array(pending.values); pending.removeAll()
        for callback in callbacks { callback(false, "定位组件已停止。") }
        if !isQuitting {
            state = "error"; message = "定位组件已停止，请重新打开应用。若曾模拟位置，请检查手机定位。"
        }
    }
    func request(_ command: String, values: [String: Any] = [:]) async -> (Bool, String?) {
        await withCheckedContinuation { continuation in
            send(command, values: values, showError: false) { ok, detail in
                continuation.resume(returning: (ok, detail))
            }
        }
    }
    func connectAssigned() async -> (Bool, String?) {
        guard canConnectAssigned else {
            return (false, "请为通道选择设备，并先结束回放、恢复定位。")
        }
        let target = selectedDevice
        let result = await request("connect", values: ["device": target])
        if result.0 { connectedDeviceID = target }
        return result
    }
    func startAssigned() async -> (Bool, String?) {
        guard canPlay, connected, !uncertain, actualDeviceID == selectedDevice else {
            return (false, "设备、实际连接目标或路线尚未就绪。")
        }
        elapsed = 0; travelled = 0; playbackDuration = route.duration; playbackDistance = route.totalDistance
        return await request("start", values: ["mode": "device", "route": route.payload])
    }
    func quiesceForQuit() {
        isQuitting = true; deviceWatch?.cancel()
    }
    func resumeAfterCancelledQuit() {
        isQuitting = false
        if backendReady { startDeviceWatch() }
    }
    func restoreForQuit() async -> (Bool, String?) {
        guard backendReady && input != nil else {
            return needsRestore ? (false, "定位组件未运行，无法确认恢复定位。") : (true, nil)
        }
        return await request("stop")
    }
    func quitBackend() async -> (Bool, String?) {
        guard backendReady && input != nil else { return (true, nil) }
        return await request("quit")
    }
    func forceTerminateBackend() { process?.terminate() }
}
