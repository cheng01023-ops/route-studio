import Foundation

@MainActor final class MockBridge {
    let model: StudioModel
    let pipe = Pipe()
    var commands: [[String: Any]] = []
    var failures: [String: String] = [:]
    var heldOperations = Set<String>()
    var held: [[String: Any]] = []
    private var buffer = Data()
    init(_ model: StudioModel) {
        self.model = model
        model.input = pipe.fileHandleForWriting; model.backendReady = true
        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let bytes = handle.availableData
            guard !bytes.isEmpty else { handle.readabilityHandler = nil; return }
            Task { @MainActor in self?.receive(bytes) }
        }
    }
    func close() {
        pipe.fileHandleForReading.readabilityHandler = nil
        try? pipe.fileHandleForWriting.close(); try? pipe.fileHandleForReading.close()
        model.input = nil
    }
    func event(_ json: [String: Any]) {
        var data = try! JSONSerialization.data(withJSONObject: json); data.append(10); model.receive(data)
    }
    func status(_ state: String, connected: Bool = true, simulated: Bool = false, uncertain: Bool = false, serial: String? = nil) {
        let target = serial ?? model.connectedDeviceID
        event(["event": "status", "state": state, "mode": "device", "connected": connected,
               "simulated": simulated, "uncertain": uncertain, "serial": connected ? target : "",
               "affectedSerial": simulated || uncertain ? target : "", "message": "mock " + state])
    }
    private func receive(_ data: Data) {
        buffer.append(data)
        while let newline = buffer.firstIndex(of: 10) {
            let line = buffer[..<newline]; buffer.removeSubrange(...newline)
            let command = try! JSONSerialization.jsonObject(with: line) as! [String: Any]
            commands.append(command)
            if heldOperations.contains(command["command"] as! String) { held.append(command) }
            else { respond(command) }
        }
    }
    func releaseHeld() {
        let saved = held; held = []; heldOperations = []
        for command in saved { respond(command) }
    }
    private func respond(_ command: [String: Any]) {
        let op = command["command"] as! String
        if let detail = failures[op] {
            if ["start", "stop", "restore"].contains(op) { status("error", simulated: true, uncertain: true) }
            event(["event": "response", "id": command["id"]!, "ok": false, "message": detail]); return
        }
        switch op {
        case "connect": status("ready", simulated: model.simulated, uncertain: model.uncertain, serial: command["device"] as? String)
        case "start":
            let preview = command["mode"] as? String == "preview"
            status("playing", connected: !preview, simulated: !preview)
        case "pause": status("paused", simulated: true)
        case "resume": status("playing", simulated: true)
        case "stop", "restore": status(model.connected ? "ready" : "idle", connected: model.connected)
        case "disconnect": status("idle", connected: false)
        default: break
        }
        event(["event": "response", "id": command["id"]!, "ok": true])
    }
    var ops: [String] { commands.compactMap { $0["command"] as? String } }
}

@MainActor @main struct DualSessionTests {
    static var checks = 0
    static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        precondition(condition(), message); checks += 1
    }
    static func waitUntil(_ predicate: () -> Bool) async {
        for _ in 0..<200 {
            if predicate() { return }
            try? await Task.sleep(for: .milliseconds(5))
        }
        preconditionFailure("Timed out waiting for mock pipe")
    }
    static func route(_ pace: Double = 360) -> RouteDocument {
        RouteDocument(name: "Mock route", points: [RoutePoint(latitude: 31.2, longitude: 121.4), RoutePoint(latitude: 31.201, longitude: 121.4)], paceSeconds: pace)
    }
    static func make(_ suffix: String = UUID().uuidString, legacy: @escaping () -> Bool = { false }) -> DualStudioModel {
        let dual = DualStudioModel(startServices: false, preferencesPrefix: "RouteStudio.DualTests." + suffix, legacyAppIsRunning: legacy)
        dual.a.route = route(); dual.b.route = route(480)
        let devices = [DeviceInfo(id: "TEST-USB-A", name: "Test A", version: "27"), DeviceInfo(id: "TEST-USB-B", name: "Test B", version: "27")]
        dual.a.devices = devices; dual.b.devices = devices
        return dual
    }
    static func attach(_ dual: DualStudioModel) -> (MockBridge, MockBridge) {
        expect(dual.assignDevice("TEST-USB-A", to: 0), "A assignment")
        expect(dual.assignDevice("TEST-USB-B", to: 1), "B assignment")
        return (MockBridge(dual.a), MockBridge(dual.b))
    }
    static func clearPreferences(_ dual: DualStudioModel) {
        for session in dual.sessions {
            for key in session.preferences.dictionaryRepresentation().keys where key == "routeDraftV1" || key == "mainlandMapV1" {
                session.preferences.removeObject(forKey: key)
            }
        }
    }
    static func main() async {
        do {
            let prefix = UUID().uuidString
            let dual = make(prefix); defer { clearPreferences(dual) }
            expect(dual.a !== dual.b && dual.a.preferences !== dual.b.preferences, "Channels need separate models and preferences")
            dual.a.route.paceSeconds = 411; dual.a.route.points[0].latitude = 32
            expect(dual.b.route.paceSeconds == 480 && dual.b.route.points[0].latitude == 31.2, "Route and pace are independent values")
            let restored = DualStudioModel(startServices: false, preferencesPrefix: "RouteStudio.DualTests." + prefix, legacyAppIsRunning: { false })
            expect(restored.a.route.paceSeconds == 411 && restored.b.route.paceSeconds == 480, "Each channel restores its own draft")
            dual.a.maybeAutoConnect(); dual.b.maybeAutoConnect()
            expect(dual.a.pending.isEmpty && dual.b.pending.isEmpty && dual.a.selectedDevice.isEmpty && dual.b.selectedDevice.isEmpty, "Dual discovery must never auto-select or auto-connect")
            expect(dual.assignDevice("TEST-USB-A", to: 0), "First assignment accepted")
            expect(!dual.assignDevice("TEST-USB-A", to: 1), "Same serial cannot belong to both channels")
            expect(dual.availableDevices(for: 1).allSatisfy { $0.id != "TEST-USB-A" }, "Other channel's device is filtered")
            dual.a.state = "playing"
            expect(!dual.assignDevice("TEST-USB-B", to: 0), "Running channel cannot change device")
            dual.a.state = "holding"
            expect(!dual.assignDevice("TEST-USB-B", to: 0), "Holding channel cannot change device")
            dual.a.state = "ready"; dual.a.uncertain = true
            expect(!dual.assignDevice("TEST-USB-B", to: 0), "Unconfirmed restoration prevents reassignment")
            dual.a.uncertain = false
            dual.activeChannel = 0
            expect(dual.copyCurrentRoute(), "Idle destination accepts copied route")
            dual.a.route.paceSeconds = 501
            expect(dual.b.route.paceSeconds == 411, "Copied route remains independent afterward")
        }
        do {
            let dual = make(); let (left, right) = attach(dual)
            defer { left.close(); right.close(); clearPreferences(dual) }
            await dual.connectBoth()
            expect(left.ops == ["connect"] && right.ops == ["connect"], "Connect both must not start or set a location")
            expect(dual.a.actualDeviceID == "TEST-USB-A" && dual.b.actualDeviceID == "TEST-USB-B", "Each connection targets its assigned serial")
            expect(dual.canStartBoth, "Both ready with valid routes enables combined start")
            await dual.startBoth()
            expect(dual.a.state == "playing" && dual.b.state == "playing", "Two sessions start independently")
            let aPayload = left.commands.first { $0["command"] as? String == "start" }!["route"] as! [String: Any]
            let bPayload = right.commands.first { $0["command"] as? String == "start" }!["route"] as! [String: Any]
            expect(aPayload["paceSeconds"] as! Double == 360 && bPayload["paceSeconds"] as! Double == 480, "Combined start preserves each pace")
            dual.activeChannel = 1
            expect(dual.a.state == "playing" && !dual.copyCurrentRoute(), "Switching views preserves background playback and protects running destination")
            await dual.pauseOrResumeBoth()
            expect(dual.a.state == "paused" && dual.b.state == "paused", "Combined pause affects both")
            await dual.pauseOrResumeBoth()
            expect(dual.a.state == "playing" && dual.b.state == "playing", "Combined resume affects both")
            await dual.stopBoth()
            expect(!dual.a.simulated && !dual.b.simulated && left.ops.last == "stop" && right.ops.last == "stop", "Stop restores both")
            dual.a.selectedDevice = "TEST-USB-B"
            let count = left.commands.count
            dual.a.play(preview: false)
            expect(left.commands.count == count && dual.a.error != nil, "Changed picker cannot secretly start the old connection")
        }
        do {
            let dual = make(); let (left, right) = attach(dual)
            defer { left.close(); right.close(); clearPreferences(dual) }
            await dual.connectBoth()
            dual.b.route.points = []
            await dual.startBoth()
            expect(!left.ops.contains("start") && !right.ops.contains("start"), "Invalid second route prevents either start")
            dual.b.route = route(); dual.b.selectedDevice = dual.a.selectedDevice
            await dual.startBoth()
            expect(!left.ops.contains("start"), "Duplicate IDs prevent both starts even if assignment API was bypassed")
        }
        do {
            let dual = make(); let left = MockBridge(dual.a); let right = MockBridge(dual.b)
            defer { left.close(); right.close(); clearPreferences(dual) }
            dual.a.play(preview: true); dual.b.play(preview: true)
            await waitUntil { left.ops.contains("start") && right.ops.contains("start") && dual.a.pending.isEmpty && dual.b.pending.isEmpty }
            expect(left.commands.first?["mode"] as? String == "preview" && right.commands.first?["mode"] as? String == "preview", "Both unconnected channels can preview locally")
            expect(!left.ops.contains("connect") && !right.ops.contains("connect"), "Offline previews never open a phone connection")
            await dual.stopBoth()
        }
        do {
            let dual = make(); let (left, right) = attach(dual)
            defer { left.close(); right.close(); clearPreferences(dual) }
            await dual.connectBoth(); await dual.startBoth()
            left.status("disconnected", connected: false, simulated: true, uncertain: true, serial: "TEST-USB-A")
            expect(!dual.a.canChangeDevice && dual.a.canConnectAssigned, "Disconnected simulated device can reconnect its original serial without enabling reassignment")
            expect(!dual.assignDevice("TEST-USB-B", to: 0), "Uncertain channel cannot switch to another phone")
            await dual.connectChannel(0)
            expect(dual.a.connected && dual.a.actualDeviceID == "TEST-USB-A" && dual.a.uncertain, "Reconnect preserves uncertainty until explicit restoration")
            let restored = await dual.a.request("restore")
            expect(restored.0 && !dual.a.uncertain && !dual.a.simulated && dual.a.canChangeDevice, "Same-phone reconnection allows restoration and unlocks selection")
            expect(dual.b.state == "playing", "Reconnect and restore in A leave B playing")
            await dual.stopBoth()
        }
        do {
            let dual = make(); defer { clearPreferences(dual) }
            dual.a.mode = "preview"; dual.a.state = "playing"
            dual.a.markUnconfirmedTimeout("start", values: ["mode": "preview"], requiredDeviceRestore: false, target: "")
            dual.a.markUnconfirmedTimeout("stop", values: [:], requiredDeviceRestore: false, target: "")
            expect(!dual.a.uncertain && !dual.a.needsRestore && dual.a.affectedDeviceID.isEmpty, "Preview start or stop timeout never creates device recovery state")
            let exit = await dual.a.restoreForQuit()
            expect(exit.0, "Preview without a backend must not falsely require device restoration on exit")
            dual.a.handleBackendTermination()
            expect(dual.assignDevice("TEST-USB-A", to: 0), "Preview failure leaves device assignment available")
            dual.a.markUnconfirmedTimeout("start", values: ["mode": "device"], requiredDeviceRestore: false, target: "TEST-USB-A")
            expect(dual.a.uncertain && dual.a.affectedDeviceID == "TEST-USB-A", "Physical start timeout preserves its recovery target")
            dual.a.uncertain = false; dual.a.affectedDeviceID = ""
            dual.a.markUnconfirmedTimeout("restore", values: [:], requiredDeviceRestore: true, target: "TEST-USB-A")
            expect(dual.a.uncertain && dual.a.affectedDeviceID == "TEST-USB-A", "Restore timeout retains a device that needed restoration when sent")
        }
        do {
            let dual = make(); let (left, right) = attach(dual)
            defer { left.close(); right.close(); clearPreferences(dual) }
            await dual.connectBoth(); right.failures["start"] = "mock start failed after possible write"
            await dual.startBoth()
            expect(left.ops.suffix(2) == ["start", "stop"] && right.ops.suffix(2) == ["start", "stop"], "Partial start failure cleans up both possibly affected phones")
            expect(!dual.a.simulated && !dual.b.simulated && dual.batchMessage.contains("失败"), "Failed combined start is reported after restoration")
            right.failures["stop"] = "mock restoration failed"
            await dual.startBoth()
            expect(dual.b.uncertain && dual.batchMessage.contains("恢复"), "Cleanup failure preserves uncertainty and reports it")
        }
        do {
            let dual = make(); let (left, right) = attach(dual)
            defer { left.close(); right.close(); clearPreferences(dual) }
            await dual.connectBoth(); await dual.startBoth()
            dual.a.handleBackendTermination()
            expect(dual.a.uncertain && !dual.a.backendReady && dual.a.affectedDeviceID == "TEST-USB-A", "Failed channel retains restoration target")
            expect(dual.b.state == "playing" && dual.b.connected && dual.b.backendReady, "One bridge failure must not stop the other")
            let result = await dual.b.request("stop")
            expect(result.0 && !dual.b.simulated, "Healthy channel remains independently controllable")
        }
        do {
            let dual = make(); let (left, right) = attach(dual)
            defer { left.close(); right.close(); clearPreferences(dual) }
            await dual.connectBoth(); left.heldOperations.insert("start")
            let start = Task { await dual.startBoth() }
            await waitUntil { !left.held.isEmpty && right.ops.contains("start") }
            expect(dual.a.uncertain && dual.a.affectedDeviceID == "TEST-USB-A", "First device write is marked uncertain before any bridge status")
            dual.a.handleBackendTermination()
            await start.value
            expect(dual.a.needsRestore && dual.a.affectedDeviceID == "TEST-USB-A", "Crash after possible first write retains the original restoration target")
            expect(right.ops.last == "stop" && !dual.b.simulated && dual.batchMessage.contains("恢复"), "Partial-start crash cleans healthy peer and reports unresolved recovery")
        }
        do {
            var legacyRunning = false
            let dual = make(legacy: { legacyRunning }); let (left, right) = attach(dual)
            defer { left.close(); right.close(); clearPreferences(dual) }
            legacyRunning = true
            await dual.connectBoth()
            expect(left.commands.isEmpty && right.commands.isEmpty && dual.error?.contains("旧") == true, "Legacy app blocks connections before device requests")
            legacyRunning = false; await dual.connectBoth(); legacyRunning = true
            await dual.startBoth()
            expect(!left.ops.contains("start") && !right.ops.contains("start"), "Legacy process is checked again immediately before start")
        }
        do {
            let dual = make(); let (left, right) = attach(dual)
            defer { left.close(); right.close(); clearPreferences(dual) }
            await dual.connectBoth(); await dual.startBoth()
            right.heldOperations.insert("stop")
            var finished = false
            let exit = Task { let result = await dual.restoreForExit(); finished = true; return result }
            await waitUntil { !right.held.isEmpty && left.ops.last == "stop" }
            expect(!finished && !left.ops.contains("quit") && !right.ops.contains("quit"), "Quit must wait for both restoration responses")
            right.releaseHeld()
            let results = await exit.value
            expect(results.allSatisfy { $0.0 }, "Both restoration results are collected")
            await dual.closeBackends()
            expect(left.ops.last == "quit" && right.ops.last == "quit", "Only after both restores do both bridges quit")
        }
        do {
            let dual = make(); let (left, right) = attach(dual)
            defer { left.close(); right.close(); clearPreferences(dual) }
            await dual.connectBoth(); await dual.startBoth(); right.failures["stop"] = "mock restore failure"
            let results = await dual.restoreForExit()
            expect(results[0].0 && !results[1].0 && !left.ops.contains("quit"), "Failed exit restoration leaves healthy bridge open for cancel")
            dual.cancelExit()
            expect(!dual.batchBusy && dual.b.uncertain && dual.a.backendReady, "Cancel exit resumes coordination and preserves unresolved device state")
        }
        print("Dual-session tests passed: \(checks) checks; mock pipes only, no USB or GPS calls")
    }
}
