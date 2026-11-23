import Foundation

@main struct ModelsTests {
    static func main() throws {
        let mapPoint = RoutePoint(latitude: 31.291315, longitude: 121.503115)
        let gps = Coordinates.gcjToWGS(mapPoint)
        precondition((121.498...121.4995).contains(gps.longitude))
        precondition(gps.distance(to: mapPoint) > 400)
        precondition(Coordinates.wgsToGCJ(gps).distance(to: mapPoint) < 0.001)
        let points = [RoutePoint(latitude: 0, longitude: 0), RoutePoint(latitude: 0, longitude: 0.01)]
        let route = RouteDocument(name: "中文 & 路线 <1>", points: points, closed: true, loops: 2, paceSeconds: 360)
        precondition(abs(route.totalDistance - 4447.8032) < 0.01)
        let decoded = try JSONDecoder().decode(RouteDocument.self, from: RouteFiles.json(route)).validated()
        precondition(decoded.points.count == 2 && decoded.loops == 2)
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".gpx")
        defer { try? FileManager.default.removeItem(at: temp) }
        let gpx = try RouteFiles.gpx(route)
        try gpx.write(to: temp)
        let imported = try RouteFiles.load(temp)
        precondition(imported.points.count == 5)
        precondition(abs(imported.totalDistance - route.totalDistance) < 0.01)
        let text = String(decoding: gpx, as: UTF8.self)
        precondition(text.contains("中文 &amp; 路线 &lt;1&gt;"))
        let invalid = "<gpx><trk><trkseg><trkpt lat=\"0\" lon=\"0\"/></trkseg><trkseg><trkpt lat=\"1\" lon=\"1\"/></trkseg></trk></gpx>"
        try Data(invalid.utf8).write(to: temp)
        do { _ = try RouteFiles.load(temp); fatalError("Multi-segment GPX was accepted") } catch {}
        print("Swift coordinates / route JSON / GPX / loop distance tests passed")
    }
}
