import Foundation

/// The sun and moon (after SunCalc by Vladimir Agafonkin, BSD-2-Clause), line for line as in
/// web/core.js. Positions to a fraction of a degree and rise and set times to about a minute: plenty
/// for a compass. Times are UTC milliseconds, as in JavaScript, so the fixture's numbers compare directly;
/// the Date versions are for the screens.
enum Sky {
    private static let rad = Double.pi / 180, dayMs = 86400000.0, j1970 = 2440588.0, j2000 = 2451545.0
    private static let obliquity = rad * 23.4397

    struct Position: Equatable {
        /// Degrees from true north, clockwise.
        let azimuth: Double
        /// Degrees above the horizon (negative below it).
        let altitude: Double
    }

    enum Polar: String { case day, night }

    struct Times: Equatable {
        let noon: Double
        /// nil when the sun doesn't rise or set that day (see `polar`).
        let sunrise: Double?
        let sunset: Double?
        /// The evening's golden hour starts (the sun 6° up).
        let goldenHour: Double?
        /// Midnight sun or polar night, when there's no sunrise or sunset.
        let polar: Polar?

        var sunriseDate: Date? { sunrise.map { Sky.date($0) } }
        var sunsetDate: Date? { sunset.map { Sky.date($0) } }
    }

    struct Phase: Equatable {
        /// How much of the moon is lit, 0–1.
        let fraction: Double
        /// 0 new, 0.25 first quarter, 0.5 full, 0.75 last quarter.
        let phase: Double
        let name: String
    }

    static let phaseNames = ["New Moon", "Waxing Crescent", "First Quarter", "Waxing Gibbous", "Full Moon", "Waning Gibbous", "Last Quarter", "Waning Crescent"]

    static func ms(_ date: Date) -> Double { date.timeIntervalSince1970 * 1000 }
    static func date(_ ms: Double) -> Date { Date(timeIntervalSince1970: ms / 1000) }

    // MARK: The pieces

    private static func toDays(_ ms: Double) -> Double { ms / dayMs - 0.5 + j1970 - j2000 }
    private static func fromJulian(_ j: Double) -> Double { (j + 0.5 - j1970) * dayMs }
    private static func rightAscension(_ l: Double, _ b: Double) -> Double {
        atan2(sin(l) * cos(obliquity) - tan(b) * sin(obliquity), cos(l))
    }
    private static func declination(_ l: Double, _ b: Double) -> Double {
        asin(sin(b) * cos(obliquity) + cos(b) * sin(obliquity) * sin(l))
    }
    private static func azimuthOf(_ h: Double, _ phi: Double, _ dec: Double) -> Double {
        atan2(sin(h), cos(h) * sin(phi) - tan(dec) * cos(phi))
    }
    private static func altitudeOf(_ h: Double, _ phi: Double, _ dec: Double) -> Double {
        asin(sin(phi) * sin(dec) + cos(phi) * cos(dec) * cos(h))
    }
    private static func siderealTime(_ d: Double, _ lw: Double) -> Double { rad * (280.16 + 360.9856235 * d) - lw }
    private static func solarMeanAnomaly(_ d: Double) -> Double { rad * (357.5291 + 0.98560028 * d) }
    private static func eclipticLongitude(_ m: Double) -> Double {
        let c = rad * (1.9148 * sin(m) + 0.02 * sin(2 * m) + 0.0003 * sin(3 * m))
        return m + c + rad * 102.9372 + Double.pi
    }
    private static func sunCoords(_ d: Double) -> (dec: Double, ra: Double) {
        let l = eclipticLongitude(solarMeanAnomaly(d))
        return (declination(l, 0), rightAscension(l, 0))
    }
    private static func astroRefraction(_ h0: Double) -> Double {
        let h = h0 < 0 ? 0 : h0
        return 0.0002967 / tan(h + 0.00312536 / (h + 0.08901179))
    }
    private static func moonCoords(_ d: Double) -> (ra: Double, dec: Double, dist: Double) {
        let l0 = rad * (218.316 + 13.176396 * d), m = rad * (134.963 + 13.064993 * d), f = rad * (93.272 + 13.229350 * d)
        let l = l0 + rad * 6.289 * sin(m), b = rad * 5.128 * sin(f), dist = 385001 - 20905 * cos(m)
        return (rightAscension(l, b), declination(l, b), dist)
    }

    // MARK: Sun

    /// The sun's direction at a moment (UTC milliseconds).
    static func sunPosition(ms: Double, lat: Double, lon: Double) -> Position {
        let lw = rad * -lon, phi = rad * lat, d = toDays(ms), c = sunCoords(d), h = siderealTime(d, lw) - c.ra
        return Position(azimuth: Geo.normalize(azimuthOf(h, phi, c.dec) / rad + 180), altitude: altitudeOf(h, phi, c.dec) / rad)
    }

    static func sunPosition(at date: Date, lat: Double, lon: Double) -> Position { sunPosition(ms: ms(date), lat: lat, lon: lon) }

    /// Sunrise, sunset, solar noon and the evening's golden hour for the day containing `ms`.
    static func sunTimes(ms: Double, lat: Double, lon: Double) -> Times {
        let j0 = 0.0009, lw = rad * -lon, phi = rad * lat, d = toDays(ms)
        let n = Geo.jsRound(d - j0 - lw / (2 * Double.pi))
        let ds = j0 + (0 + lw) / (2 * Double.pi) + n
        let m = solarMeanAnomaly(ds), l = eclipticLongitude(m), dec = declination(l, 0)
        func transit(_ a: Double) -> Double { j2000 + a + 0.0053 * sin(m) - 0.0069 * sin(2 * l) }
        let jNoon = transit(ds)
        func setFor(_ h: Double) -> Double? {
            let w = acos((sin(h) - sin(phi) * sin(dec)) / (cos(phi) * cos(dec)))
            if w.isNaN { return nil }
            return transit(j0 + (w + lw) / (2 * Double.pi) + n)
        }
        let setJ = setFor(-0.833 * rad)
        let golden = setFor(6 * rad)
        // Midnight sun or polar night: which one, from the sun at noon.
        let polar: Polar? = setJ == nil ? (altitudeOf(0, phi, dec) > 0 ? .day : .night) : nil
        return Times(noon: fromJulian(jNoon),
                     sunrise: setJ.map { fromJulian(jNoon - ($0 - jNoon)) },
                     sunset: setJ.map { fromJulian($0) },
                     goldenHour: golden.map { fromJulian($0) },
                     polar: polar)
    }

    static func sunTimes(at date: Date, lat: Double, lon: Double) -> Times { sunTimes(ms: ms(date), lat: lat, lon: lon) }

    // MARK: Moon

    /// The moon's direction, like sunPosition (altitude corrected for refraction).
    static func moonPosition(ms: Double, lat: Double, lon: Double) -> Position {
        let lw = rad * -lon, phi = rad * lat, d = toDays(ms), c = moonCoords(d), h = siderealTime(d, lw) - c.ra
        var alt = altitudeOf(h, phi, c.dec)
        alt += astroRefraction(alt)
        return Position(azimuth: Geo.normalize(azimuthOf(h, phi, c.dec) / rad + 180), altitude: alt / rad)
    }

    static func moonPosition(at date: Date, lat: Double, lon: Double) -> Position { moonPosition(ms: ms(date), lat: lat, lon: lon) }

    /// How much of the moon is lit, where it is in its month, and the phase's name.
    static func moonPhase(ms: Double) -> Phase {
        let d = toDays(ms), s = sunCoords(d), m = moonCoords(d), sdist = 149598000.0
        let phi = acos(sin(s.dec) * sin(m.dec) + cos(s.dec) * cos(m.dec) * cos(s.ra - m.ra))
        let inc = atan2(sdist * sin(phi), m.dist - sdist * cos(phi))
        let angle = atan2(cos(s.dec) * sin(s.ra - m.ra), sin(s.dec) * cos(m.dec) - cos(s.dec) * sin(m.dec) * cos(s.ra - m.ra))
        let fraction = (1 + cos(inc)) / 2
        let phase = 0.5 + 0.5 * inc * (angle < 0 ? -1 : 1) / Double.pi
        return Phase(fraction: fraction, phase: phase, name: phaseNames[Int(Geo.jsRound(phase * 8)) % 8])
    }

    static func moonPhase(at date: Date) -> Phase { moonPhase(ms: ms(date)) }
}
