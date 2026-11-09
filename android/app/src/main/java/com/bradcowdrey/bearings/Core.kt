package com.bradcowdrey.bearings

import java.util.Locale
import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.asin
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.floor
import kotlin.math.min
import kotlin.math.max
import kotlin.math.pow
import kotlin.math.sin
import kotlin.math.sqrt
import kotlin.math.tan

/**
 * Bearings' core: headings, coordinate formats, units, distances and the nearest place (the sun and moon
 * are in Sky.kt). Pure functions; web/core.js and the Mac and
 * iPhone apps' Geo.swift mirror it one for one, and all three are checked against Tests/fixtures/geo.json.
 */
object Geo {
    private val POINTS = listOf("N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE", "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW")
    private val NAMES = listOf("North", "North-northeast", "Northeast", "East-northeast", "East", "East-southeast", "Southeast", "South-southeast",
        "South", "South-southwest", "Southwest", "West-southwest", "West", "West-northwest", "Northwest", "North-northwest")

    /** 0 ≤ angle < 360. */
    fun normalize(deg: Double): Double { val d = deg % 360; return if (d < 0) d + 360 else d }

    /** The short way from [from] to [to], in -180…180 (positive is clockwise). */
    fun delta(from: Double, to: Double): Double { var d = normalize(to - from); if (d > 180) d -= 360; return d }

    /** Rounds half up, like JavaScript's Math.round, so all three apps agree. */
    internal fun jsRound(v: Double): Long = floor(v + 0.5).toLong()

    /**
     * JavaScript's toFixed: rounds the double's exact binary value half up, which is what toFixed does.
     * (String.format rounds a shortened decimal copy instead, and can disagree on ties such as 1.005.)
     */
    internal fun toFixed(v: Double, digits: Int): String =
        java.math.BigDecimal(v).setScale(digits, java.math.RoundingMode.HALF_UP).toPlainString()

    fun point(deg: Double): String = POINTS[(jsRound(normalize(deg) / 22.5) % 16).toInt()]
    fun pointName(deg: Double): String = NAMES[(jsRound(normalize(deg) / 22.5) % 16).toInt()]
    /** "228 degrees, southwest": all a screen reader hears of the heading as the phone turns (as on iPhone). */
    fun headingSpoken(deg: Double): String = "${Math.round(deg) % 360} degrees, ${pointName(deg).lowercase()}"

    // ---------- Coordinate formats ----------

    private fun ns(v: Double, isLat: Boolean) = if (isLat) (if (v < 0) "S" else "N") else (if (v < 0) "W" else "E")
    private fun fixed(v: Double, digits: Int) = toFixed(v, digits)

    /** 39.73920° N */
    fun dd(v: Double, isLat: Boolean) = "${fixed(abs(v), 5)}° ${ns(v, isLat)}"

    /** 39° 44′ 21.1″ N (seconds to a tenth, about 3 m). */
    fun dms(v: Double, isLat: Boolean): String {
        var tenths = jsRound(abs(v) * 36000)
        val d = tenths / 36000; tenths -= d * 36000
        val m = tenths / 600; tenths -= m * 600
        val s = "${tenths / 10}.${tenths % 10}"
        return "$d° ${m.toString().padStart(2, '0')}′ ${s.padStart(4, '0')}″ ${ns(v, isLat)}"
    }

    /** 39° 44.352′ N (minutes to a thousandth, about 2 m). */
    fun ddm(v: Double, isLat: Boolean): String {
        var th = jsRound(abs(v) * 60000)
        val d = th / 60000; th -= d * 60000
        val m = "${th / 1000}.${(th % 1000).toString().padStart(3, '0')}"
        return "$d° ${m.padStart(6, '0')}′ ${ns(v, isLat)}"
    }

    data class Utm(val zone: Int, val band: Char, val easting: Double, val northing: Double)

    private const val A = 6378137.0
    private const val F = 1 / 298.257223563
    private const val K0 = 0.9996
    private const val E2 = F * (2 - F)
    private const val EP2 = E2 / (1 - E2)
    private const val BANDS = "CDEFGHJKLMNPQRSTUVWX"

    fun utmZone(lat: Double, lon: Double): Int {
        var zone = floor((lon + 180) / 6).toInt() + 1
        if (lon >= 180) zone = 60
        if (lat >= 56 && lat < 64 && lon >= 3 && lon < 12) zone = 32   // Norway
        if (lat >= 72 && lat < 84) {                                   // Svalbard
            if (lon >= 0 && lon < 9) zone = 31 else if (lon >= 9 && lon < 21) zone = 33
            else if (lon >= 21 && lon < 33) zone = 35 else if (lon >= 33 && lon < 42) zone = 37
        }
        return zone
    }

    /** UTM on WGS84 (Snyder's series), or null near the poles (UTM covers 80° S to 84° N). */
    fun utm(lat: Double, lon: Double): Utm? {
        if (!(lat >= -80 && lat < 84)) return null
        val zone = utmZone(lat, lon)
        val band = BANDS[min(19, floor((lat + 80) / 8).toInt())]
        val phi = Math.toRadians(lat); val lam = Math.toRadians(lon); val lam0 = Math.toRadians(((zone - 1) * 6 - 180 + 3).toDouble())
        val s = sin(phi); val c = cos(phi); val t = tan(phi)
        val n = A / sqrt(1 - E2 * s * s); val tt = t * t; val cc = EP2 * c * c; val aa = c * (lam - lam0)
        val e4 = E2 * E2; val e6 = e4 * E2
        val mm = A * ((1 - E2 / 4 - 3 * e4 / 64 - 5 * e6 / 256) * phi
            - (3 * E2 / 8 + 3 * e4 / 32 + 45 * e6 / 1024) * sin(2 * phi)
            + (15 * e4 / 256 + 45 * e6 / 1024) * sin(4 * phi)
            - (35 * e6 / 3072) * sin(6 * phi))
        val easting = K0 * n * (aa + (1 - tt + cc) * aa.pow(3) / 6 + (5 - 18 * tt + tt * tt + 72 * cc - 58 * EP2) * aa.pow(5) / 120) + 500000
        var northing = K0 * (mm + n * t * (aa * aa / 2 + (5 - tt + 9 * cc + 4 * cc * cc) * aa.pow(4) / 24
            + (61 - 58 * tt + tt * tt + 600 * cc - 330 * EP2) * aa.pow(6) / 720))
        if (lat < 0) northing += 10000000
        return Utm(zone, band, easting, northing)
    }

    /** 13S 500830E 4398757N */
    fun utmText(lat: Double, lon: Double): String? =
        utm(lat, lon)?.let { "${it.zone}${it.band} ${floor(it.easting).toLong()}E ${floor(it.northing).toLong()}N" }

    /** 13S DE 00830 98757 (1 m). */
    fun mgrs(lat: Double, lon: Double): String? {
        val u = utm(lat, lon) ?: return null
        val set = ((u.zone - 1) % 6) + 1
        val cols = listOf("ABCDEFGH", "JKLMNPQR", "STUVWXYZ")[(set - 1) % 3]
        val rows = "ABCDEFGHJKLMNPQRSTUV"
        val e100 = floor(u.easting / 100000).toInt(); val n100 = floor(u.northing / 100000).toInt()
        val col = cols[e100 - 1]
        val row = rows[(n100 + (if (set % 2 == 0) 5 else 0)) % 20]
        val e = (floor(u.easting).toLong() % 100000).toString().padStart(5, '0')
        val n = (floor(u.northing).toLong() % 100000).toString().padStart(5, '0')
        return "${u.zone}${u.band} $col$row $e $n"
    }

    /** Open Location Code, 10 digits (about 14 m): 85FPQXGV+XX */
    fun plusCode(lat: Double, lon: Double): String {
        val alphabet = "23456789CFGHJMPQRVWX"
        val la = min(max(lat, -90.0), 90.0); val lo = normalize(lon + 180) - 180
        // As the current reference does: to whole units of the 15-digit grid first (rounding away float
        // noise, so 60.39 stays 60.39), then down to 10 digits.
        var latI = floor(jsRound((la + 90) * 2.5e7 * 1e6) / 1e6).toLong() / 3125
        var lonI = floor(jsRound((lo + 180) * 8192000.0 * 1e6) / 1e6).toLong() / 1024
        latI = min(latI, 180L * 8000 - 1)
        var code = ""
        repeat(5) {
            code = "${alphabet[(latI % 20).toInt()]}${alphabet[(lonI % 20).toInt()]}$code"
            latI /= 20; lonI /= 20
        }
        return code.take(8) + "+" + code.drop(8)
    }

    enum class Format(val id: String, val title: String) {
        DD("dd", "Decimal Degrees"), DMS("dms", "Degrees, Minutes, Seconds"), DDM("ddm", "Degrees, Decimal Minutes"),
        UTM("utm", "UTM"), MGRS("mgrs", "MGRS"), PLUS("plus", "Plus Code");

        val next: Format get() = entries[(ordinal + 1) % entries.size]

        companion object { fun of(id: String?) = entries.firstOrNull { it.id == id } ?: DD }
    }

    /** Latitude and longitude for the paired formats; one grid reference for UTM, MGRS and Plus Code. */
    sealed interface Formatted {
        data class Pair(val lat: String, val lon: String) : Formatted
        data class Single(val text: String) : Formatted
    }

    fun format(format: Format, lat: Double, lon: Double): Formatted = when (format) {
        Format.DD -> Formatted.Pair(dd(lat, true), dd(lon, false))
        Format.DMS -> Formatted.Pair(dms(lat, true), dms(lon, false))
        Format.DDM -> Formatted.Pair(ddm(lat, true), ddm(lon, false))
        Format.UTM -> Formatted.Single(utmText(lat, lon) ?: "Outside UTM (polar)")
        Format.MGRS -> Formatted.Single(mgrs(lat, lon) ?: "Outside MGRS (polar)")
        Format.PLUS -> Formatted.Single(plusCode(lat, lon))
    }

    /** What Copy puts on the clipboard. */
    fun copyText(format: Format, lat: Double, lon: Double): String = when (val f = format(format, lat, lon)) {
        is Formatted.Pair -> "${f.lat}, ${f.lon}"
        is Formatted.Single -> f.text
    }

    // ---------- Units ----------
    const val FOOT = 0.3048

    /** 5280.0 → "5,280" (always with commas, like the web app). */
    fun group(value: Double): String = String.format(Locale.US, "%,d", jsRound(value))

    /** "5,280 ft" to "1,609 m". */
    fun elevation(metres: Double): kotlin.Pair<String, String> = "${group(metres / FOOT)} ft" to "${group(metres)} m"

    /** ±12 m or ±39 ft. */
    fun accuracy(metres: Double, feet: Boolean) = if (feet) "±${group(metres / FOOT)} ft" else "±${group(metres)} m"

    /** Countries that use feet for elevation. */
    fun prefersFeet(country: String?) = country in setOf("US", "LR", "MM")

    /** What's sent to Open-Meteo: rounded to 3 decimals (about 100 m), enough for 90 m terrain data. */
    fun rounded(v: Double) = jsRound(v * 1000) / 1000.0

    // ---------- Distance and bearing (a marked spot) ----------
    private const val EARTH_R = 6371008.8
    private const val RAD = PI / 180

    /** Great-circle distance in metres. */
    fun distance(lat1: Double, lon1: Double, lat2: Double, lon2: Double): Double {
        val p1 = lat1 * RAD; val p2 = lat2 * RAD; val dp = (lat2 - lat1) * RAD; val dl = (lon2 - lon1) * RAD
        val a = sin(dp / 2).pow(2) + cos(p1) * cos(p2) * sin(dl / 2).pow(2)
        return 2 * EARTH_R * asin(min(1.0, sqrt(a)))
    }

    /** Initial bearing from the first point to the second, degrees from true north. */
    fun bearing(lat1: Double, lon1: Double, lat2: Double, lon2: Double): Double {
        val p1 = lat1 * RAD; val p2 = lat2 * RAD; val dl = (lon2 - lon1) * RAD
        return normalize(atan2(sin(dl) * cos(p2), cos(p1) * sin(p2) - sin(p1) * cos(p2) * cos(dl)) / RAD)
    }

    /** "350 ft", "0.4 mi", "12 mi" or "120 m", "1.3 km", "12 km". */
    fun distanceText(m: Double, feet: Boolean): String {
        if (feet) {
            val ft = m / FOOT
            if (ft < 1000) return "${group(jsRound(ft / 10) * 10.0)} ft"
            val mi = m / 1609.344
            return if (mi < 9.95) "${toFixed(mi, 1)} mi" else "${group(mi)} mi"
        }
        if (m < 1000) return "${group(jsRound(m / 5) * 5.0)} m"
        val km = m / 1000
        return if (km < 9.95) "${toFixed(km, 1)} km" else "${group(km)} km"
    }

    // ---------- Speed and pressure ----------

    /** "3.2 mph" or "5.1 km/h" (metres per second in). */
    fun speedText(mps: Double, feet: Boolean): String {
        val v = if (feet) mps * 2.2369363 else mps * 3.6
        return "${if (v < 9.95) toFixed(v, 1) else group(v)} ${if (feet) "mph" else "km/h"}"
    }

    /** "29.92 inHg" or "1,013 hPa" (hectopascals in). */
    fun pressureText(hpa: Double, feet: Boolean): String =
        if (feet) "${toFixed(hpa * 0.0295299830714, 2)} inHg" else "${group(hpa)} hPa"

    // ---------- The nearest place (offline naming, from the bundled GeoNames list) ----------

    data class City(val name: String, val region: String, val country: String, val lat: Double, val lon: Double)

    /** A listed place near a point: [km] away, and [from] is the bearing from the place to the point. */
    data class Nearby(val name: String, val region: String, val country: String, val km: Double, val from: Double)

    /** Parses Resources/Cities.tsv lines: name, ASCII name, region, country code, latitude, longitude. */
    fun parseCities(text: String): List<City> {
        val out = ArrayList<City>()
        for (line in text.split('\n')) {
            val c = line.split('\t')
            if (c.size < 6) continue
            val lat = c[4].trim().toDoubleOrNull(); val lon = c[5].trim().toDoubleOrNull()
            if (lat != null && lon != null && lat.isFinite() && lon.isFinite()) out += City(c[0], c[2], c[3], lat, lon)
        }
        return out
    }

    /** The listed place nearest a point, within 200 km, or null. */
    fun nearestPlace(lat: Double, lon: Double, list: List<City>): Nearby? {
        val k = cos(lat * RAD)
        var best: City? = null
        var bestD = Double.POSITIVE_INFINITY
        for (e in list) {
            val dy = e.lat - lat
            var dx = abs(e.lon - lon); if (dx > 180) dx = 360 - dx
            val d = dy * dy + (dx * k) * (dx * k)
            if (d < bestD) { bestD = d; best = e }
        }
        val b = best ?: return null
        val km = distance(lat, lon, b.lat, b.lon) / 1000
        return if (km <= 200) Nearby(b.name, b.region, b.country, km, bearing(b.lat, b.lon, lat, lon)) else null
    }

    /** "Denver, Colorado" within 5 km; otherwise "28 mi SW of Glenwood Springs, Colorado". */
    fun placeText(p: Nearby?, feet: Boolean): String? {
        if (p == null) return null
        val where = listOf(p.name, p.region).filter { it.isNotEmpty() }.joinToString(", ")
        if (p.km <= 5) return where
        val dist = if (feet) "${group(p.km / 1.609344)} mi" else "${group(p.km)} km"
        return "$dist ${point(p.from)} of $where"
    }
}

/** Smooths headings as a unit vector, so 359° and 1° average to 0°, not 180°. */
class HeadingSmoother(private val k: Double) {
    private var x: Double? = null
    private var y: Double? = null

    fun push(deg: Double): Double {
        val r = Math.toRadians(deg)
        val px = x; val py = y
        if (px == null || py == null) { x = cos(r); y = sin(r) } else { x = px + k * (cos(r) - px); y = py + k * (sin(r) - py) }
        return Geo.normalize(Math.toDegrees(atan2(y!!, x!!)))
    }

    fun reset() { x = null; y = null }
}
