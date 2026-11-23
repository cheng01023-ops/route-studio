import Foundation

// GCJ-02 formulas adapted from googollee/eviltransform (BSD-2-Clause).
// See Licenses/eviltransform.txt. Route documents and device writes stay WGS84.
enum Coordinates {
    static func outsideChina(_ p: RoutePoint) -> Bool {
        !(72.004...137.8347).contains(p.longitude) || !(0.8293...55.8271).contains(p.latitude)
    }
    static func wgsToGCJ(_ p: RoutePoint) -> RoutePoint {
        guard !outsideChina(p) else { return p }
        let x = p.longitude - 105, y = p.latitude - 35
        let shared = (20 * sin(6*x * .pi) + 20 * sin(2*x * .pi)) * 2 / 3
        var lat = -100 + 2*x + 3*y + 0.2*y*y + 0.1*x*y + 0.2*sqrt(abs(x))
        lat += shared + (20*sin(y * .pi) + 40*sin(y * .pi / 3)) * 2 / 3
        lat += (160*sin(y * .pi / 12) + 320*sin(y * .pi / 30)) * 2 / 3
        var lon = 300 + x + 2*y + 0.1*x*x + 0.1*x*y + 0.1*sqrt(abs(x))
        lon += shared + (20*sin(x * .pi) + 40*sin(x * .pi / 3)) * 2 / 3
        lon += (150*sin(x * .pi / 12) + 300*sin(x * .pi / 30)) * 2 / 3
        let rad = p.latitude * .pi / 180, ee = 0.00669342162296594323
        let magic = 1 - ee * pow(sin(rad), 2), root = sqrt(magic), a = 6_378_137.0
        let dlat = lat * 180 / ((a * (1-ee)) / (magic * root) * .pi)
        let dlon = lon * 180 / (a / root * cos(rad) * .pi)
        return RoutePoint(latitude: p.latitude + dlat, longitude: p.longitude + dlon)
    }
    static func gcjToWGS(_ p: RoutePoint) -> RoutePoint {
        guard !outsideChina(p) else { return p }
        var guess = p
        for _ in 0..<15 {
            let forward = wgsToGCJ(guess)
            let dlat = forward.latitude - p.latitude, dlon = forward.longitude - p.longitude
            guess.latitude -= dlat; guess.longitude -= dlon
            if max(abs(dlat), abs(dlon)) < 1e-10 { break }
        }
        return guess
    }
}
