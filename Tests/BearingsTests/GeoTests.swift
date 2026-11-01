import XCTest
@testable import Bearings

/// The coordinate formats, compass points, units, sun and moon, distances and the nearest place, against
/// Tests/fixtures/geo.json: the same expected values the web app (tests/web.test.js) and the Android app
/// (CoreTest.kt) are checked against.
final class GeoTests: XCTestCase {
    struct Place: Decodable { let name: String; let lat: Double; let lon: Double; let dd, dms, ddm, plus: String; let utm, mgrs: String? }
    struct Heading: Decodable { let deg: Double; let point: String; let normalized: Double }
    struct Elevation: Decodable { let metres: Double; let ft: String; let m: String }
    struct SkyCase: Decodable {
        let name: String; let lat: Double; let lon: Double; let t: Double
        let sunAzimuth, sunAltitude, moonAzimuth, moonAltitude: Double
        let sunrise, sunset, goldenHour: Double?
        let noon: Double
        let polar: String?
        let moonFraction, moonPhase: Double
        let moonName: String
    }
    struct Pair: Decodable { let from: [Double]; let to: [Double]; let metres: Double; let bearing: Double; let feetText: String; let metresText: String }
    struct Speed: Decodable { let mps: Double; let feet: String; let metric: String }
    struct Pressure: Decodable { let hpa: Double; let feet: String; let metric: String }
    struct Nearest: Decodable {
        let lat: Double; let lon: Double
        let name, region, country: String?
        let km, from: Double?
        let feetText, metresText: String?
    }
    struct Fixture: Decodable {
        let places: [Place]; let headings: [Heading]; let elevations: [Elevation]
        let sky: [SkyCase]; let pairs: [Pair]; let speeds: [Speed]; let pressures: [Pressure]; let nearest: [Nearest]
    }

    static let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    static let fixture: Fixture = {
        let url = root.appendingPathComponent("Tests/fixtures/geo.json")
        return try! JSONDecoder().decode(Fixture.self, from: Data(contentsOf: url))
    }()

    static let cities: [Geo.City] = {
        let url = root.appendingPathComponent("Resources/Cities.tsv")
        return Geo.parseCities(try! String(contentsOf: url, encoding: .utf8))
    }()

    /// Times to within a second (the fixture's are milliseconds); nil must stay nil.
    private func assertTime(_ got: Double?, _ want: Double?, _ what: String, file: StaticString = #filePath, line: UInt = #line) {
        switch (got, want) {
        case (nil, nil): break
        case let (g?, w?): XCTAssertEqual(g, w, accuracy: 1000, what, file: file, line: line)
        default: XCTFail("\(what): got \(String(describing: got)), want \(String(describing: want))", file: file, line: line)
        }
    }

    func testSunAndMoon() {
        XCTAssertFalse(Self.fixture.sky.isEmpty)
        for c in Self.fixture.sky {
            let what = "\(c.name) at \(c.t)"
            let sun = Sky.sunPosition(ms: c.t, lat: c.lat, lon: c.lon)
            XCTAssertEqual(sun.azimuth, c.sunAzimuth, accuracy: 1e-6, "sun azimuth, \(what)")
            XCTAssertEqual(sun.altitude, c.sunAltitude, accuracy: 1e-6, "sun altitude, \(what)")
            let moon = Sky.moonPosition(ms: c.t, lat: c.lat, lon: c.lon)
            XCTAssertEqual(moon.azimuth, c.moonAzimuth, accuracy: 1e-6, "moon azimuth, \(what)")
            XCTAssertEqual(moon.altitude, c.moonAltitude, accuracy: 1e-6, "moon altitude, \(what)")
            let times = Sky.sunTimes(ms: c.t, lat: c.lat, lon: c.lon)
            assertTime(times.sunrise, c.sunrise, "sunrise, \(what)")
            assertTime(times.sunset, c.sunset, "sunset, \(what)")
            assertTime(times.noon, c.noon, "noon, \(what)")
            assertTime(times.goldenHour, c.goldenHour, "golden hour, \(what)")
            XCTAssertEqual(times.polar?.rawValue, c.polar, "polar, \(what)")
            let phase = Sky.moonPhase(ms: c.t)
            XCTAssertEqual(phase.fraction, c.moonFraction, accuracy: 1e-9, "moon lit, \(what)")
            XCTAssertEqual(phase.phase, c.moonPhase, accuracy: 1e-9, "moon phase, \(what)")
            XCTAssertEqual(phase.name, c.moonName, what)
        }
    }

    func testDistancesAndBearings() {
        for p in Self.fixture.pairs {
            let what = "\(p.from) → \(p.to)"
            let m = Geo.distance(lat1: p.from[0], lon1: p.from[1], lat2: p.to[0], lon2: p.to[1])
            XCTAssertEqual(m, p.metres, accuracy: 1e-3, what)
            XCTAssertEqual(Geo.bearing(lat1: p.from[0], lon1: p.from[1], lat2: p.to[0], lon2: p.to[1]), p.bearing, accuracy: 1e-6, what)
            XCTAssertEqual(Geo.distanceText(p.metres, feet: true), p.feetText, what)
            XCTAssertEqual(Geo.distanceText(p.metres, feet: false), p.metresText, what)
        }
    }

    func testSpeedsAndPressures() {
        for s in Self.fixture.speeds {
            XCTAssertEqual(Geo.speedText(s.mps, feet: true), s.feet, "\(s.mps) m/s")
            XCTAssertEqual(Geo.speedText(s.mps, feet: false), s.metric, "\(s.mps) m/s")
        }
        for p in Self.fixture.pressures {
            XCTAssertEqual(Geo.pressureText(p.hpa, feet: true), p.feet, "\(p.hpa) hPa")
            XCTAssertEqual(Geo.pressureText(p.hpa, feet: false), p.metric, "\(p.hpa) hPa")
        }
    }

    func testNearestPlace() {
        XCTAssertGreaterThan(Self.cities.count, 10000)
        for n in Self.fixture.nearest {
            let what = "\(n.lat), \(n.lon)"
            let got = Geo.nearestPlace(lat: n.lat, lon: n.lon, in: Self.cities)
            XCTAssertEqual(got?.name, n.name, what)
            XCTAssertEqual(got?.region, n.region, what)
            XCTAssertEqual(got?.country, n.country, what)
            if let km = n.km { XCTAssertEqual(got?.km ?? -1, km, accuracy: 1e-6, what) }
            if let from = n.from { XCTAssertEqual(got?.from ?? -1, from, accuracy: 1e-6, what) }
            XCTAssertEqual(Geo.placeText(got, feet: true), n.feetText, what)
            XCTAssertEqual(Geo.placeText(got, feet: false), n.metresText, what)
        }
    }

    func testFormatsMatchTheFixture() {
        for p in Self.fixture.places {
            XCTAssertEqual(Geo.copyText(.dd, lat: p.lat, lon: p.lon), p.dd, p.name)
            XCTAssertEqual(Geo.copyText(.dms, lat: p.lat, lon: p.lon), p.dms, p.name)
            XCTAssertEqual(Geo.copyText(.ddm, lat: p.lat, lon: p.lon), p.ddm, p.name)
            XCTAssertEqual(Geo.utmText(lat: p.lat, lon: p.lon), p.utm, p.name)
            XCTAssertEqual(Geo.mgrs(lat: p.lat, lon: p.lon), p.mgrs, p.name)
            XCTAssertEqual(Geo.plusCode(lat: p.lat, lon: p.lon), p.plus, p.name)
        }
    }

    func testCompassPoints() {
        for h in Self.fixture.headings {
            XCTAssertEqual(Geo.point(h.deg), h.point, "\(h.deg)")
            XCTAssertEqual(Geo.normalize(h.deg), h.normalized, accuracy: 1e-9)
        }
    }

    func testElevations() {
        for e in Self.fixture.elevations {
            XCTAssertEqual(Geo.elevation(e.metres).ft, e.ft)
            XCTAssertEqual(Geo.elevation(e.metres).m, e.m)
        }
    }

    func testShortWayRound() {
        XCTAssertEqual(Geo.delta(from: 350, to: 10), 20)
        XCTAssertEqual(Geo.delta(from: 10, to: 350), -20)
        XCTAssertEqual(Geo.delta(from: 0, to: 180), 180)
    }

    func testSmoothingAcrossNorth() {
        var s = HeadingSmoother(k: 0.5)
        _ = s.push(359)
        let h = s.push(1)
        XCTAssertTrue(h < 0.01 || h > 359.99, "\(h)")
    }

    func testUnits() {
        XCTAssertEqual(Geo.elevation(1609.344).ft, "5,280 ft")
        XCTAssertEqual(Geo.elevation(8848.86).m, "8,849 m")
        XCTAssertEqual(Geo.accuracy(12, feet: false), "±12 m")
        XCTAssertEqual(Geo.accuracy(12, feet: true), "±39 ft")
        XCTAssertEqual(Geo.group(-1412.07), "-1,412")
        XCTAssertTrue(Geo.prefersFeet(region: "US"))
        XCTAssertFalse(Geo.prefersFeet(region: "GB"))
    }

    func testCoreChecksPass() {
        for (name, ok) in CoreChecks.run() { XCTAssertTrue(ok, name) }
    }

    func testFormatsCycle() {
        XCTAssertEqual(Geo.Format.dd.next, .dms)
        XCTAssertEqual(Geo.Format.plus.next, .dd)
    }

    func testUpdateComparison() {
        XCTAssertTrue(Updater.isNewer("0.10.0", than: "0.9.3"))
        XCTAssertFalse(Updater.isNewer("0.1.0", than: "0.1.0"))
    }

    func testTermsSchedule() {
        XCTAssertTrue(TermsSchedule.shouldAsk(acceptedVersion: nil, acceptedAt: nil))
        XCTAssertFalse(TermsSchedule.shouldAsk(acceptedVersion: Brand.termsVersion, acceptedAt: Date()))
    }
}
