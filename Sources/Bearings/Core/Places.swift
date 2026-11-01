import Foundation

/// Naming where you are without the network: the nearest place in the bundled GeoNames list
/// (Resources/Cities.tsv, every place with 15,000+ people), as in web/core.js. The app asks the system's
/// geocoder first and falls back on this; widgets use it when you've moved since the app last named
/// the place.
extension Geo {
    struct City: Equatable {
        let name: String
        let region: String
        let country: String
        let lat: Double
        let lon: Double
    }

    struct NearestPlace: Equatable {
        let name: String
        let region: String
        let country: String
        /// How far the point is from the place.
        let km: Double
        /// The bearing from the place to the point, degrees.
        let from: Double
    }

    /// Resources/Cities.tsv lines: name, ASCII name, region, country code, latitude, longitude.
    static func parseCities(_ text: String) -> [City] {
        var out: [City] = []
        for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let c = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
            if c.count < 6 { continue }
            guard let lat = number(c[4]), let lon = number(c[5]), lat.isFinite, lon.isFinite else { continue }
            out.append(City(name: c[0], region: c[2], country: c[3], lat: lat, lon: lon))
        }
        return out
    }

    /// JavaScript's Number() for the list's fields: blank reads as 0.
    private static func number(_ s: String) -> Double? {
        let t = s.trimmingCharacters(in: .whitespaces)
        return t.isEmpty ? 0 : Double(t)
    }

    /// The listed place nearest a point, within 200 km.
    static func nearestPlace(lat: Double, lon: Double, in list: [City]) -> NearestPlace? {
        let k = cos(lat * .pi / 180)
        var best: City?
        var bestD = Double.infinity
        for e in list {
            let dy = e.lat - lat
            var dx = abs(e.lon - lon)
            if dx > 180 { dx = 360 - dx }
            let d = dy * dy + (dx * k) * (dx * k)
            if d < bestD { bestD = d; best = e }
        }
        guard let best else { return nil }
        let km = distance(lat1: lat, lon1: lon, lat2: best.lat, lon2: best.lon) / 1000
        guard km <= 200 else { return nil }
        return NearestPlace(name: best.name, region: best.region, country: best.country, km: km,
                            from: bearing(lat1: best.lat, lon1: best.lon, lat2: lat, lon2: lon))
    }

    /// "Denver, Colorado" within 5 km; otherwise "28 mi SW of Glenwood Springs, Colorado".
    static func placeText(_ p: NearestPlace?, feet: Bool) -> String? {
        guard let p else { return nil }
        let place = [p.name, p.region].filter { !$0.isEmpty }.joined(separator: ", ")
        if p.km <= 5 { return place }
        let dist = feet ? "\(group(p.km / 1.609344)) mi" : "\(group(p.km)) km"
        return "\(dist) \(point(p.from)) of \(place)"
    }

    /// The list bundled with the app and the widget, read the first time it's needed. Empty where it
    /// isn't bundled (`swift test` and `swift run` read the file themselves or go without).
    static let bundledCities: [City] = {
        guard let url = Bundle.main.url(forResource: "Cities", withExtension: "tsv"),
              let text = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        return parseCities(text)
    }()

    /// The offline name for a point: the nearest listed place, or "Far from any town" past 200 km.
    static func offlinePlaceName(lat: Double, lon: Double, feet: Bool, in list: [City] = bundledCities) -> String? {
        guard !list.isEmpty else { return nil }
        return placeText(nearestPlace(lat: lat, lon: lon, in: list), feet: feet) ?? "Far from any town"
    }
}
