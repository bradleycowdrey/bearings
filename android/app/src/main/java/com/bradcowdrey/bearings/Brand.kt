package com.bradcowdrey.bearings

/** Single source of truth for branding: the same wording as the Mac and iPhone apps (Brand.swift). */
object Brand {
    const val APP_NAME = "Bearings"
    const val TAGLINE = "A compass with your coordinates, elevation and a map, on one screen."
    const val WEBSITE = "https://bradcowdrey.com"
    const val LEGAL = "https://bradcowdrey.com/legal"
    /** Bump when the terms change materially, so everyone is asked to agree again (same as Brand.swift). */
    const val TERMS_VERSION = "2026-11-01"
    const val REPOSITORY = "https://github.com/bradleycowdrey/bearings"
    const val PRODUCT_PAGE = "https://bradcowdrey.com/bearings"
    const val SHARE_MESSAGE = "Bearings: a compass with your latitude, longitude, elevation and a map, on one screen. Free and open source, by Bradley Cowdrey."
    const val TERMS_SUMMARY = "Bearings is free and provided as is, without warranty. It is not a navigation or safety instrument: compasses are thrown off by metal and magnets, and positions and elevations can be wrong, so carry a map and a real compass where it matters. Your location stays on your phone; only a rounded position goes to Open-Meteo for the ground elevation, and the map loads from OpenFreeMap."
    const val MAP_STYLE = "https://tiles.openfreemap.org/styles/liberty"
}

/**
 * When to ask for the Terms of Use and Privacy: always the first time; again when they change, but no
 * more than once a month. The same rule as the Mac and iPhone apps.
 */
object TermsSchedule {
    const val INTERVAL_MS = 30L * 24 * 60 * 60 * 1000

    fun shouldAsk(acceptedVersion: String?, acceptedAt: Long, current: String = Brand.TERMS_VERSION, now: Long = System.currentTimeMillis()): Boolean {
        if (acceptedVersion.isNullOrEmpty()) return true
        if (acceptedVersion == current) return false
        if (acceptedAt <= 0L) return true
        return now - acceptedAt >= INTERVAL_MS
    }
}

/** A few known answers, checked by the on-device self-test (the unit tests check the whole fixture). */
object CoreChecks {
    fun run(): List<Pair<String, Boolean>> {
        val lat = 39.09898; val lon = -106.94117
        val smooth = HeadingSmoother(0.5).let { it.push(359.0); it.push(1.0) }
        return listOf(
            "Decimal degrees" to (Geo.copyText(Geo.Format.DD, lat, lon) == "39.09898° N, 106.94117° W"),
            "Degrees, minutes, seconds" to (Geo.copyText(Geo.Format.DMS, lat, lon) == "39° 05′ 56.3″ N, 106° 56′ 28.2″ W"),
            "Degrees, decimal minutes" to (Geo.copyText(Geo.Format.DDM, lat, lon) == "39° 05.939′ N, 106° 56.470′ W"),
            "UTM" to (Geo.utmText(lat, lon) == "13S 332138E 4329554N"),
            "MGRS" to (Geo.mgrs(lat, lon) == "13S CD 32138 29554"),
            "Plus Code" to (Geo.plusCode(lat, lon) == "85FM33X5+HG"),
            "Compass points" to (Geo.point(348.76) == "N" && Geo.point(247.0) == "WSW" && Geo.point(-10.0) == "N"),
            "Short way round" to (Geo.delta(350.0, 10.0) == 20.0 && Geo.delta(10.0, 350.0) == -20.0),
            "Smoothing across north" to (smooth < 0.01 || smooth > 359.99),
            "Elevation in feet and metres" to (Geo.elevation(2922.0) == ("9,587 ft" to "2,922 m")),
            "Sun's position" to (near(sun.azimuth, 134.16779, 0.001) && near(sun.altitude, 23.15559, 0.001)),
            "Sunrise and sunset" to (near(times.sunrise ?: 0.0, 1793540189283.0, 1000.0) && near(times.sunset ?: 0.0, 1793578121517.0, 1000.0)),
            "Midnight sun" to (Sky.sunTimes(1782043200000.0, 78.2232, 15.6267).polar == Polar.DAY),
            "Moon's position" to (near(moon.azimuth, 258.40172, 0.001) && near(moon.altitude, 47.31184, 0.001)),
            "Moon's phase" to (phase.name == "Last Quarter" && near(phase.fraction, 0.53214, 0.0001)),
            "Distance and bearing" to (near(Geo.distance(lat, lon, 39.1911, -106.8175), 14787.382, 0.01) &&
                near(Geo.bearing(lat, lon, 39.1911, -106.8175), 46.11639, 0.0001)),
            "Distance in words" to (Geo.distanceText(14787.382, true) == "9.2 mi" && Geo.distanceText(14787.382, false) == "15 km" &&
                Geo.distanceText(58.136, true) == "190 ft"),
            "Speed and pressure" to (Geo.speedText(1.43, true) == "3.2 mph" && Geo.speedText(1.43, false) == "5.1 km/h" &&
                Geo.pressureText(1013.25, true) == "29.92 inHg" && Geo.pressureText(1013.25, false) == "1,013 hPa"),
        )
    }

    private fun near(a: Double, b: Double, within: Double) = kotlin.math.abs(a - b) <= within

    /** The sky at Maroon Bells at 9 AM on 1 November 2026, as in Tests/fixtures/geo.json. */
    private const val T = 1793548800000.0
    private val sun get() = Sky.sunPosition(T, 39.09898, -106.94117)
    private val moon get() = Sky.moonPosition(T, 39.09898, -106.94117)
    private val times get() = Sky.sunTimes(T, 39.09898, -106.94117)
    private val phase get() = Sky.moonPhase(T)
}
