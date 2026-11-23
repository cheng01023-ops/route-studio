import Foundation

@MainActor @main struct StartupTests {
    static var checks = 0

    static func expect(_ condition: @autoclosure () -> Bool, _ detail: String) {
        precondition(condition(), detail)
        checks += 1
    }

    static func withPreferences(_ body: (UserDefaults) throws -> Void) rethrows {
        let suite = "RouteStudio.StartupTests." + UUID().uuidString
        let preferences = UserDefaults(suiteName: suite)!
        preferences.removePersistentDomain(forName: suite)
        defer { preferences.removePersistentDomain(forName: suite) }
        try body(preferences)
    }

    static func capture(_ model: StudioModel, _ body: (StudioModel) throws -> Void) throws -> [[String: Any]] {
        let pipe = Pipe()
        model.input = pipe.fileHandleForWriting
        model.backendReady = true
        defer {
            try? pipe.fileHandleForReading.close()
            model.input = nil
        }
        do { try body(model) }
        catch { try? pipe.fileHandleForWriting.close(); throw error }
        try pipe.fileHandleForWriting.close()
        let bytes = pipe.fileHandleForReading.readDataToEndOfFile()
        return try String(decoding: bytes, as: UTF8.self).split(separator: "\n").map {
            try JSONSerialization.jsonObject(with: Data($0.utf8)) as! [String: Any]
        }
    }

    static func acceptConnection(_ model: StudioModel) throws {
        let id = model.pending.keys.first!
        let events: [[String: Any]] = [
            ["event": "status", "state": "ready", "connected": true, "simulated": false,
             "uncertain": false, "message": "test connection"],
            ["event": "response", "id": id, "ok": true]
        ]
        for event in events {
            var data = try JSONSerialization.data(withJSONObject: event)
            data.append(10)
            model.receive(data)
        }
    }

    static func main() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("RouteStudio-StartupTests-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let defaultURL = directory.appendingPathComponent("DefaultRoute.json")
        let initial = RouteDocument(name: "南区田径场 · 1000米默认路线", points: [
            RoutePoint(latitude: 31.292596, longitude: 121.498779),
            RoutePoint(latitude: 31.2928, longitude: 121.4989)
        ], paceSeconds: 360)
        try RouteFiles.json(initial).write(to: defaultURL)

        withPreferences { preferences in
            let model = StudioModel(startServices: false, preferences: preferences, defaultRouteURL: defaultURL)
            expect(model.route.name == initial.name && model.route.points.count == 2, "First launch must load the bundled default route")
            expect(model.route.paceSeconds == 360 && model.fitRevision == 1, "Default pace and initial map fit must be ready")
            expect(model.process == nil && model.input == nil && model.pending.isEmpty && !model.backendReady,
                   "Startup without services must not start a backend or send any command")
            expect(!model.active && !model.simulated && model.elapsed == 0, "Restoring a route must never restore playback")

            var edited = model.route
            edited.name = "我的上次路线"
            edited.paceSeconds = 425
            edited.points.append(RoutePoint(latitude: 31.2931, longitude: 121.4988))
            model.route = edited
            model.route.paceSeconds = 430
            let restored = StudioModel(startServices: false, preferences: preferences, defaultRouteURL: defaultURL)
            expect(restored.route.name == edited.name && restored.route.points.count == 3, "Saved draft must take precedence over default")
            expect(restored.route.paceSeconds == 430, "Direct UI-style pace changes must survive relaunch")
            expect(!restored.active && restored.pending.isEmpty && !restored.simulated, "Saved data must not include a running session")
        }

        try withPreferences { preferences in
            let empty = RouteDocument(name: "有意清空的路线", points: [], paceSeconds: 480)
            preferences.set(try RouteFiles.json(empty), forKey: "routeDraftV1")
            let model = StudioModel(startServices: false, preferences: preferences, defaultRouteURL: defaultURL)
            expect(model.route.points.isEmpty && model.route.name == empty.name, "An intentionally empty draft must not be replaced by default")
            expect(model.route.paceSeconds == 480 && model.fitRevision == 0, "Empty draft settings must be preserved")
        }

        withPreferences { preferences in
            preferences.set(Data("broken JSON".utf8), forKey: "routeDraftV1")
            let model = StudioModel(startServices: false, preferences: preferences, defaultRouteURL: defaultURL)
            expect(model.route.name == initial.name && model.route.points.count == 2, "Corrupt draft must fall back to default")
            expect(model.error == nil && model.pending.isEmpty, "Corrupt draft recovery must remain local and usable")
        }

        withPreferences { preferences in
            preferences.set(false, forKey: "mainlandMapV1")
            let model = StudioModel(startServices: false, preferences: preferences, defaultRouteURL: defaultURL)
            expect(!model.mainlandMap, "Saved international-map setting must restore")
            model.mainlandMap = true
            let restored = StudioModel(startServices: false, preferences: preferences, defaultRouteURL: defaultURL)
            expect(restored.mainlandMap, "Changed mainland-map setting must persist")
        }

        try withPreferences { preferences in
            let model = StudioModel(startServices: false, preferences: preferences, defaultRouteURL: defaultURL)
            let commands = try capture(model) { model in
                model.devices = [DeviceInfo(id: "TEST-USB-A", name: "Test iPhone", version: "27.0.1")]
                model.maybeAutoConnect()
                model.maybeAutoConnect()
                expect(model.pending.count == 1, "Repeated discovery during connection must not duplicate requests")
                try acceptConnection(model)
                expect(model.connected && !model.commandBusy, "Connection completion must mark the device ready")
                model.maybeAutoConnect()
                // Even another discovery after a failed/reset connection must not auto-retry endlessly.
                model.connected = false
                model.maybeAutoConnect()
            }
            expect(commands.count == 1 && commands.first?["command"] as? String == "connect", "Single-device startup may send connect once, never start/set")
            expect(commands.first?["device"] as? String == "TEST-USB-A", "Automatic connection must target the discovered device")
            expect(!model.active && !model.simulated, "Successful automatic connection must never start a route")
        }

        try withPreferences { preferences in
            let model = StudioModel(startServices: false, preferences: preferences, defaultRouteURL: defaultURL)
            let commands = try capture(model) { model in
                model.devices = [DeviceInfo(id: "TEST-USB-A", name: "A", version: "27"), DeviceInfo(id: "TEST-USB-B", name: "B", version: "27")]
                model.selectedDevice = "TEST-USB-A"
                model.maybeAutoConnect()
            }
            expect(commands.isEmpty && model.pending.isEmpty, "Multiple devices must require explicit device selection/connection")
        }

        try withPreferences { preferences in
            let model = StudioModel(startServices: false, preferences: preferences, defaultRouteURL: defaultURL)
            let commands = try capture(model) { model in
                model.devices = [DeviceInfo(id: "TEST-USB-A", name: "A", version: "27")]
                model.uncertain = true
                model.maybeAutoConnect()
                model.uncertain = false
                model.simulated = true
                model.maybeAutoConnect()
            }
            expect(commands.isEmpty && model.pending.isEmpty, "Unknown or active simulated location must block automatic connection")
        }

        print("Startup tests passed: \(checks) checks; no backend process or device location command was started")
    }
}
