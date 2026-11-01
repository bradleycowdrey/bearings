import Foundation

/// A few known answers, checked by the Mac and iPhone self-tests on the device itself (the unit tests
/// check the full Tests/fixtures/geo.json).
enum CoreChecks {
    static func run() -> [(String, Bool)] {
        let lat = 39.09898, lon = -106.94117
        // Maroon Bells at 16:00 UTC on 1 November 2026, 9 AM there (Tests/fixtures/geo.json).
        let t = 1793548800000.0
        let sun = Sky.sunPosition(ms: t, lat: lat, lon: lon), moon = Sky.moonPosition(ms: t, lat: lat, lon: lon)
        let times = Sky.sunTimes(ms: t, lat: lat, lon: lon), phase = Sky.moonPhase(ms: t)
        let polar = Sky.sunTimes(ms: t, lat: 78.2232, lon: 15.6267)
        return [
            ("Decimal degrees", Geo.copyText(.dd, lat: lat, lon: lon) == "39.09898° N, 106.94117° W"),
            ("Degrees, minutes, seconds", Geo.copyText(.dms, lat: lat, lon: lon) == "39° 05′ 56.3″ N, 106° 56′ 28.2″ W"),
            ("Degrees, decimal minutes", Geo.copyText(.ddm, lat: lat, lon: lon) == "39° 05.939′ N, 106° 56.470′ W"),
            ("UTM", Geo.utmText(lat: lat, lon: lon) == "13S 332138E 4329554N"),
            ("MGRS", Geo.mgrs(lat: lat, lon: lon) == "13S CD 32138 29554"),
            ("Plus Code", Geo.plusCode(lat: lat, lon: lon) == "85FM33X5+HG"),
            ("Compass points", Geo.point(348.76) == "N" && Geo.point(247) == "WSW" && Geo.point(-10) == "N"),
            ("Short way round", Geo.delta(from: 350, to: 10) == 20 && Geo.delta(from: 10, to: 350) == -20),
            ("Smoothing across north", { () -> Bool in var s = HeadingSmoother(k: 0.5); _ = s.push(359); let h = s.push(1); return h < 0.01 || h > 359.99 }()),
            ("Elevation in feet and metres", Geo.elevation(2922).ft == "9,587 ft" && Geo.elevation(2922).m == "2,922 m"),
            ("Sun's direction", abs(sun.azimuth - 134.167794) < 1e-4 && abs(sun.altitude - 23.155591) < 1e-4),
            ("Sunrise and sunset", abs((times.sunrise ?? 0) - 1793540189283) < 1000 && abs((times.sunset ?? 0) - 1793578121516) < 1000),
            ("Polar night in Longyearbyen", polar.sunrise == nil && polar.polar == .night),
            ("Moon's direction", abs(moon.azimuth - 258.401717) < 1e-4 && abs(moon.altitude - 47.311841) < 1e-4),
            ("Moon's phase", phase.name == "Last Quarter" && abs(phase.fraction - 0.532136) < 1e-4),
            ("Distance and bearing to a spot", abs(Geo.distance(lat1: lat, lon1: lon, lat2: 39.1911, lon2: -106.8175) - 14787.38) < 0.1
                && abs(Geo.bearing(lat1: lat, lon1: lon, lat2: 39.1911, lon2: -106.8175) - 46.1164) < 1e-3),
            ("Distances in words", Geo.distanceText(14787.38, feet: true) == "9.2 mi" && Geo.distanceText(14787.38, feet: false) == "15 km"
                && Geo.distanceText(58.14, feet: true) == "190 ft" && Geo.distanceText(58.14, feet: false) == "60 m"),
            ("Speed", Geo.speedText(1.43, feet: true) == "3.2 mph" && Geo.speedText(31.3, feet: false) == "113 km/h"),
            ("Air pressure", Geo.pressureText(1013.25, feet: true) == "29.92 inHg" && Geo.pressureText(1013.25, feet: false) == "1,013 hPa"),
            ("Place in words", Geo.placeText(Geo.NearestPlace(name: "Montrose", region: "Colorado", country: "US", km: 106.4459, from: 49.2894), feet: true)
                == "66 mi NE of Montrose, Colorado"),
        ]
    }
}
