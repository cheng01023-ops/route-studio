import Foundation
import CoreLocation
import MapKit

struct RoutePoint: Codable, Identifiable, Equatable {
    var id = UUID()
    var latitude: Double
    var longitude: Double
    var coordinate: CLLocationCoordinate2D { .init(latitude: latitude, longitude: longitude) }
    var valid: Bool { latitude.isFinite && longitude.isFinite && (-90...90).contains(latitude) && (-180...180).contains(longitude) }
    enum CodingKeys: String, CodingKey { case latitude, longitude }
    init(latitude: Double, longitude: Double) { self.latitude = latitude; self.longitude = longitude }
    init(_ coordinate: CLLocationCoordinate2D) { self.init(latitude: coordinate.latitude, longitude: coordinate.longitude) }
    func distance(to other: RoutePoint) -> Double {
        let a = latitude * .pi / 180, b = other.latitude * .pi / 180
        let dlat = b - a, dlon = (other.longitude - longitude) * .pi / 180
        let h = pow(sin(dlat / 2), 2) + cos(a) * cos(b) * pow(sin(dlon / 2), 2)
        return 2 * 6_371_008.8 * asin(sqrt(min(1, max(0, h))))
    }
}

struct RouteDocument: Codable {
    var formatVersion = 1
    var coordinateSystem = "WGS84"
    var name = "我的路线"
    var points: [RoutePoint] = []
    var closed = false
    var loops = 1
    var paceSeconds = 360.0
    var lapDistance: Double {
        var path = points
        if closed, let first = points.first, let last = points.last, first.distance(to: last) > 0.001 { path.append(first) }
        return zip(path, path.dropFirst()).reduce(0) { $0 + $1.0.distance(to: $1.1) }
    }
    var totalDistance: Double { lapDistance * Double(loops) }
    var duration: Double { totalDistance * paceSeconds / 1000 }
    func validated() throws -> RouteDocument {
        guard formatVersion == 1, coordinateSystem == "WGS84" else { throw StudioError.message("文件版本或坐标系不支持；请使用 WGS84 路线。") }
        guard points.count <= 10000, points.allSatisfy(\.valid), (1...1000).contains(loops), paceSeconds.isFinite, (30...3600).contains(paceSeconds), closed || loops == 1 else { throw StudioError.message("路线文件包含无效的坐标、配速或循环设置。") }
        return self
    }
    var payload: [String: Any] {
        ["points": points.map { ["latitude": $0.latitude, "longitude": $0.longitude] },
         "coordinateSystem": coordinateSystem, "closed": closed, "loops": loops, "paceSeconds": paceSeconds]
    }
}

struct DeviceInfo: Identifiable {
    var id: String
    var name: String
    var version: String
}

enum StudioError: LocalizedError {
    case message(String)
    var errorDescription: String? { if case let .message(message) = self { return message }; return nil }
}

enum RouteFiles {
    static func load(_ url: URL) throws -> RouteDocument {
        let data = try Data(contentsOf: url)
        guard data.count <= 10_000_000 else { throw StudioError.message("路线文件超过 10 MB，请缩小后再导入。") }
        if url.pathExtension.lowercased() == "gpx" {
            let delegate = GPXReader()
            let parser = XMLParser(data: data)
            parser.shouldResolveExternalEntities = false
            parser.delegate = delegate
            guard parser.parse(), delegate.error == nil else { throw StudioError.message(delegate.error ?? "GPX 文件无法解析。") }
            let groups = !delegate.tracks.isEmpty ? delegate.tracks : (!delegate.routes.isEmpty ? delegate.routes : [delegate.waypoints])
            guard groups.filter({ !$0.isEmpty }).count == 1, let points = groups.first(where: { !$0.isEmpty }), points.count >= 2 else {
                throw StudioError.message("请导入仅含一条连续轨迹的 GPX 文件，至少包含两个点。多段轨迹请先拆分，避免跨段跳点。")
            }
            return try RouteDocument(name: url.deletingPathExtension().lastPathComponent, points: points).validated()
        }
        return try JSONDecoder().decode(RouteDocument.self, from: data).validated()
    }
    static func json(_ route: RouteDocument) throws -> Data {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(route)
    }
    static func gpx(_ route: RouteDocument) throws -> Data {
        guard route.points.count >= 2, route.lapDistance >= 1 else { throw StudioError.message("请先添加至少两个不同的途经点。") }
        guard route.points.count * route.loops <= 100000 else { throw StudioError.message("导出点数过多，请减少循环次数。") }
        var lap = route.points
        if route.closed, let first = lap.first, let last = lap.last, first.distance(to: last) > 0.001 { lap.append(first) }
        let start = Date(); let formatter = ISO8601DateFormatter(); formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var elapsed = 0.0, previous: RoutePoint?
        var lines = ["<?xml version=\"1.0\" encoding=\"UTF-8\"?>", "<gpx version=\"1.1\" creator=\"Route Studio\" xmlns=\"http://www.topografix.com/GPX/1/1\"><trk><name>\(escape(route.name))</name><trkseg>"]
        for loop in 0..<route.loops {
            for (index, point) in lap.enumerated() {
                if loop > 0 && index == 0 { continue }
                if let p = previous { elapsed += p.distance(to: point) * route.paceSeconds / 1000 }
                let date = formatter.string(from: start.addingTimeInterval(elapsed))
                lines.append("<trkpt lat=\"\(point.latitude)\" lon=\"\(point.longitude)\"><time>\(date)</time></trkpt>")
                previous = point
            }
        }
        lines.append("</trkseg></trk></gpx>")
        return Data(lines.joined(separator: "\n").utf8)
    }
    static func escape(_ value: String) -> String {
        value.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;").replacingOccurrences(of: "\"", with: "&quot;").replacingOccurrences(of: "'", with: "&apos;")
    }
}

private final class GPXReader: NSObject, XMLParserDelegate {
    var tracks: [[RoutePoint]] = [], routes: [[RoutePoint]] = [], waypoints: [RoutePoint] = []
    var error: String?
    var count = 0
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes: [String: String]) {
        let name = elementName.components(separatedBy: ":").last ?? elementName
        if name == "trkseg" { tracks.append([]) }
        if name == "rte" { routes.append([]) }
        if ["trkpt", "rtept", "wpt"].contains(name) {
            guard let lat = attributes["lat"].flatMap(Double.init), let lon = attributes["lon"].flatMap(Double.init) else { error = "GPX 点缺少经纬度。"; parser.abortParsing(); return }
            let point = RoutePoint(latitude: lat, longitude: lon)
            count += 1
            guard point.valid, count <= 10000 else { error = "GPX 坐标无效或超过 10000 个点。"; parser.abortParsing(); return }
            if name == "trkpt" {
                guard !tracks.isEmpty else { error = "GPX 轨迹缺少 trkseg。"; parser.abortParsing(); return }
                tracks[tracks.count - 1].append(point)
            } else if name == "rtept" {
                guard !routes.isEmpty else { error = "GPX 路线结构无效。"; parser.abortParsing(); return }
                routes[routes.count - 1].append(point)
            } else { waypoints.append(point) }
        }
    }
}

func durationText(_ seconds: Double) -> String {
    guard seconds.isFinite else { return "—" }
    let s = max(0, Int(seconds.rounded()))
    return s >= 3600 ? String(format: "%d:%02d:%02d", s / 3600, s / 60 % 60, s % 60) : String(format: "%02d:%02d", s / 60, s % 60)
}
