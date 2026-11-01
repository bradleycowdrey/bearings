import Foundation

/// Bearings' core: headings, coordinate formats, units, distances. Pure functions, shared by the Mac and
/// iPhone apps and the widgets (the sun and moon are in Sky.swift, the nearest place in Places.swift);
/// web/core.js and the Android app's Core.kt mirror it one for one, and all three are
/// checked against Tests/fixtures/geo.json.
enum Geo {
    static let points = ["N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE", "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW"]
    static let pointNames = ["North", "North-northeast", "Northeast", "East-northeast", "East", "East-southeast", "Southeast", "South-southeast",
                             "South", "South-southwest", "Southwest", "West-southwest", "West", "West-northwest", "Northwest", "North-northwest"]

    /// 0 ≤ angle < 360.
    static func normalize(_ deg: Double) -> Double {
        let d = deg.truncatingRemainder(dividingBy: 360)
        return d < 0 ? d + 360 : d
    }

    /// The short way from `from` to `to`, in -180…180 (positive is clockwise).
    static func delta(from: Double, to: Double) -> Double {
        var d = normalize(to - from)
        if d > 180 { d -= 360 }
        return d
    }

    /// One of the 16 compass points.
    static func point(_ deg: Double) -> String { points[Int((normalize(deg) / 22.5).rounded()) % 16] }
    static func pointName(_ deg: Double) -> String { pointNames[Int((normalize(deg) / 22.5).rounded()) % 16] }

    // MARK: Coordinate formats

    private static func hemi(_ v: Double, _ pos: String, _ neg: String) -> String { v < 0 ? neg : pos }
    private static func ns(_ v: Double, _ isLat: Bool) -> String { isLat ? hemi(v, "N", "S") : hemi(v, "E", "W") }
    /// JavaScript's toFixed (to the same digits for every value Bearings shows).
    static func fixed(_ v: Double, _ digits: Int) -> String { String(format: "%.\(digits)f", v) }
    /// JavaScript's Math.round: halves go up, so -2.5 rounds to -2 (Swift's .rounded() would give -3).
    static func jsRound(_ v: Double) -> Double { (v + 0.5).rounded(.down) }
    private static func pad(_ s: String, _ width: Int) -> String { String(repeating: "0", count: max(0, width - s.count)) + s }

    /// 39.73920° N
    static func dd(_ v: Double, isLat: Bool) -> String { "\(fixed(abs(v), 5))° \(ns(v, isLat))" }

    /// 39° 44′ 21.1″ N (seconds to a tenth, about 3 m).
    static func dms(_ v: Double, isLat: Bool) -> String {
        var tenths = Int((abs(v) * 36000).rounded())
        let d = tenths / 36000; tenths -= d * 36000
        let m = tenths / 600; tenths -= m * 600
        let s = "\(tenths / 10).\(tenths % 10)"
        return "\(d)° \(pad(String(m), 2))′ \(pad(s, 4))″ \(ns(v, isLat))"
    }

    /// 39° 44.352′ N (minutes to a thousandth, about 2 m).
    static func ddm(_ v: Double, isLat: Bool) -> String {
        var th = Int((abs(v) * 60000).rounded())
        let d = th / 60000; th -= d * 60000
        let m = "\(th / 1000).\(pad(String(th % 1000), 3))"
        return "\(d)° \(pad(m, 6))′ \(ns(v, isLat))"
    }

    struct UTM: Equatable { let zone: Int; let band: Character; let easting: Double; let northing: Double }

    private static let a = 6378137.0, f = 1 / 298.257223563, k0 = 0.9996
    private static let e2 = f * (2 - f), ep2 = e2 / (1 - e2)
    private static let bands = Array("CDEFGHJKLMNPQRSTUVWX")

    static func utmZone(lat: Double, lon: Double) -> Int {
        var zone = Int(((lon + 180) / 6).rounded(.down)) + 1
        if lon >= 180 { zone = 60 }
        if lat >= 56 && lat < 64 && lon >= 3 && lon < 12 { zone = 32 }   // Norway
        if lat >= 72 && lat < 84 {                                        // Svalbard
            if lon >= 0 && lon < 9 { zone = 31 } else if lon >= 9 && lon < 21 { zone = 33 }
            else if lon >= 21 && lon < 33 { zone = 35 } else if lon >= 33 && lon < 42 { zone = 37 }
        }
        return zone
    }

    /// UTM on WGS84 (Snyder's series), or nil near the poles (UTM covers 80° S to 84° N).
    static func utm(lat: Double, lon: Double) -> UTM? {
        guard lat >= -80 && lat < 84 else { return nil }
        let zone = utmZone(lat: lat, lon: lon)
        let band = bands[min(19, Int(((lat + 80) / 8).rounded(.down)))]
        let phi = lat * .pi / 180, lam = lon * .pi / 180, lam0 = Double((zone - 1) * 6 - 180 + 3) * .pi / 180
        let s = sin(phi), c = cos(phi), t = tan(phi)
        let n = a / (1 - e2 * s * s).squareRoot(), tt = t * t, cc = ep2 * c * c, aa = c * (lam - lam0)
        let e4 = e2 * e2, e6 = e4 * e2
        let m1 = (1 - e2 / 4 - 3 * e4 / 64 - 5 * e6 / 256) * phi
        let m2 = (3 * e2 / 8 + 3 * e4 / 32 + 45 * e6 / 1024) * sin(2 * phi)
        let m3 = (15 * e4 / 256 + 45 * e6 / 1024) * sin(4 * phi)
        let m4 = (35 * e6 / 3072) * sin(6 * phi)
        let mm = a * (m1 - m2 + m3 - m4)
        let a3 = pow(aa, 3), a4 = pow(aa, 4), a5 = pow(aa, 5), a6 = pow(aa, 6)
        let x1 = (1 - tt + cc) * a3 / 6
        let x2 = (5 - 18 * tt + tt * tt + 72 * cc - 58 * ep2) * a5 / 120
        let easting = k0 * n * (aa + x1 + x2) + 500000
        let y1 = aa * aa / 2
        let y2 = (5 - tt + 9 * cc + 4 * cc * cc) * a4 / 24
        let y3 = (61 - 58 * tt + tt * tt + 600 * cc - 330 * ep2) * a6 / 720
        var northing = k0 * (mm + n * t * (y1 + y2 + y3))
        if lat < 0 { northing += 10000000 }
        return UTM(zone: zone, band: band, easting: easting, northing: northing)
    }

    /// 13S 500830E 4398757N
    static func utmText(lat: Double, lon: Double) -> String? {
        guard let u = utm(lat: lat, lon: lon) else { return nil }
        return "\(u.zone)\(u.band) \(Int(u.easting.rounded(.down)))E \(Int(u.northing.rounded(.down)))N"
    }

    /// 13S DE 00830 98757 (1 m).
    static func mgrs(lat: Double, lon: Double) -> String? {
        guard let u = utm(lat: lat, lon: lon) else { return nil }
        let set = ((u.zone - 1) % 6) + 1
        let cols = Array(["ABCDEFGH", "JKLMNPQR", "STUVWXYZ"][(set - 1) % 3])
        let rows = Array("ABCDEFGHJKLMNPQRSTUV")
        let e100 = Int((u.easting / 100000).rounded(.down)), n100 = Int((u.northing / 100000).rounded(.down))
        let col = cols[e100 - 1]
        let row = rows[(n100 + (set % 2 == 0 ? 5 : 0)) % 20]
        let e = pad(String(Int(u.easting.rounded(.down)) % 100000), 5)
        let n = pad(String(Int(u.northing.rounded(.down)) % 100000), 5)
        return "\(u.zone)\(u.band) \(col)\(row) \(e) \(n)"
    }

    /// Open Location Code, 10 digits (about 14 m): 85FPQXGV+XX
    static func plusCode(lat: Double, lon: Double) -> String {
        let alphabet = Array("23456789CFGHJMPQRVWX")
        let la = min(max(lat, -90), 90), lo = normalize(lon + 180) - 180
        // As the current reference does: to whole units of the 15-digit grid first (rounding away float
        // noise, so 60.39 stays 60.39), then down to 10 digits.
        var latI = Int((((la + 90) * 2.5e7 * 1e6).rounded() / 1e6).rounded(.down)) / 3125
        var lonI = Int((((lo + 180) * 8192000 * 1e6).rounded() / 1e6).rounded(.down)) / 1024
        latI = min(latI, 180 * 8000 - 1)
        var code = ""
        for _ in 0..<5 {
            code = String(alphabet[latI % 20]) + String(alphabet[lonI % 20]) + code
            latI /= 20; lonI /= 20
        }
        return String(code.prefix(8)) + "+" + String(code.suffix(2))
    }

    enum Format: String, CaseIterable, Identifiable {
        case dd, dms, ddm, utm, mgrs, plus
        var id: String { rawValue }
        var name: String {
            switch self {
            case .dd: "Decimal Degrees"
            case .dms: "Degrees, Minutes, Seconds"
            case .ddm: "Degrees, Decimal Minutes"
            case .utm: "UTM"
            case .mgrs: "MGRS"
            case .plus: "Plus Code"
            }
        }
        var next: Format { let all = Format.allCases; return all[(all.firstIndex(of: self)! + 1) % all.count] }
    }

    /// Latitude and longitude for the paired formats; one grid reference for UTM, MGRS and Plus Code.
    enum Formatted: Equatable {
        case pair(lat: String, lon: String)
        case single(String)
    }

    static func format(_ format: Format, lat: Double, lon: Double) -> Formatted {
        switch format {
        case .dd: .pair(lat: dd(lat, isLat: true), lon: dd(lon, isLat: false))
        case .dms: .pair(lat: dms(lat, isLat: true), lon: dms(lon, isLat: false))
        case .ddm: .pair(lat: ddm(lat, isLat: true), lon: ddm(lon, isLat: false))
        case .utm: .single(utmText(lat: lat, lon: lon) ?? "Outside UTM (polar)")
        case .mgrs: .single(mgrs(lat: lat, lon: lon) ?? "Outside MGRS (polar)")
        case .plus: .single(plusCode(lat: lat, lon: lon))
        }
    }

    /// What Copy puts on the clipboard.
    static func copyText(_ format: Format, lat: Double, lon: Double) -> String {
        switch self.format(format, lat: lat, lon: lon) {
        case let .pair(la, lo): "\(la), \(lo)"
        case let .single(s): s
        }
    }

    // MARK: Units

    static let foot = 0.3048

    /// 5280 → "5,280" (always with commas, and rounded as the web app rounds).
    static func group(_ value: Double) -> String {
        let n = Int(jsRound(value))
        let digits = String(abs(n))
        var out = ""
        for (i, ch) in digits.enumerated() {
            if i > 0 && (digits.count - i) % 3 == 0 { out.append(",") }
            out.append(ch)
        }
        return (n < 0 ? "-" : "") + out
    }

    /// ("5,280 ft", "1,609 m")
    static func elevation(_ metres: Double) -> (ft: String, m: String) {
        ("\(group(metres / foot)) ft", "\(group(metres)) m")
    }

    /// ±12 m or ±39 ft.
    static func accuracy(_ metres: Double, feet: Bool) -> String {
        feet ? "±\(group(metres / foot)) ft" : "±\(group(metres)) m"
    }

    /// Countries that use feet for elevation.
    static func prefersFeet(region: String?) -> Bool { ["US", "LR", "MM"].contains(region ?? "") }

    /// What's sent to Open-Meteo: rounded to 3 decimals (about 100 m), enough for 90 m terrain data.
    static func rounded(_ v: Double) -> Double { (v * 1000).rounded() / 1000 }

    // MARK: Distance and bearing (a marked spot)

    static let earthRadius = 6371008.8
    private static let rad = Double.pi / 180

    /// Great-circle distance in metres.
    static func distance(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
        let p1 = lat1 * rad, p2 = lat2 * rad, dp = (lat2 - lat1) * rad, dl = (lon2 - lon1) * rad
        let a = pow(sin(dp / 2), 2) + cos(p1) * cos(p2) * pow(sin(dl / 2), 2)
        return 2 * earthRadius * asin(min(1, a.squareRoot()))
    }

    /// Initial bearing from the first point to the second, degrees from true north.
    static func bearing(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
        let p1 = lat1 * rad, p2 = lat2 * rad, dl = (lon2 - lon1) * rad
        return normalize(atan2(sin(dl) * cos(p2), cos(p1) * sin(p2) - sin(p1) * cos(p2) * cos(dl)) / rad)
    }

    /// "350 ft", "0.4 mi", "12 mi" or "120 m", "1.3 km", "12 km".
    static func distanceText(_ m: Double, feet: Bool) -> String {
        if feet {
            let ft = m / foot
            if ft < 1000 { return "\(group(jsRound(ft / 10) * 10)) ft" }
            let mi = m / 1609.344
            return mi < 9.95 ? "\(fixed(mi, 1)) mi" : "\(group(mi)) mi"
        }
        if m < 1000 { return "\(group(jsRound(m / 5) * 5)) m" }
        let km = m / 1000
        return km < 9.95 ? "\(fixed(km, 1)) km" : "\(group(km)) km"
    }

    // MARK: Speed and pressure

    /// "3.2 mph" or "5.1 km/h" (metres per second in).
    static func speedText(_ mps: Double, feet: Bool) -> String {
        let v = feet ? mps * 2.2369363 : mps * 3.6
        return "\(v < 9.95 ? fixed(v, 1) : group(v)) \(feet ? "mph" : "km/h")"
    }

    /// "29.92 inHg" or "1,013 hPa" (hectopascals in).
    static func pressureText(_ hpa: Double, feet: Bool) -> String {
        feet ? "\(fixed(hpa * 0.0295299830714, 2)) inHg" : "\(group(hpa)) hPa"
    }
}

/// Smooths headings as a unit vector, so 359° and 1° average to 0°, not 180°.
struct HeadingSmoother {
    var k: Double
    private var x: Double?
    private var y: Double?

    init(k: Double) { self.k = k }

    mutating func push(_ deg: Double) -> Double {
        let r = deg * .pi / 180
        if let px = x, let py = y {
            x = px + k * (cos(r) - px)
            y = py + k * (sin(r) - py)
        } else {
            x = cos(r); y = sin(r)
        }
        return Geo.normalize(atan2(y!, x!) * 180 / .pi)
    }

    mutating func reset() { x = nil; y = nil }
}
