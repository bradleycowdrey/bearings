package com.bradcowdrey.bearings

import kotlin.math.PI
import kotlin.math.acos
import kotlin.math.asin
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.sin
import kotlin.math.tan

/** A direction in the sky: degrees clockwise from true north, and degrees above the horizon. */
data class SkyPosition(val azimuth: Double, val altitude: Double)

/** Midnight sun or polar night: the sun doesn't rise or set that day. */
enum class Polar { DAY, NIGHT }

/** UTC milliseconds; [sunrise] and [sunset] are null when the sun doesn't rise or set (see [polar]). */
data class SunTimes(val noon: Double, val sunrise: Double?, val sunset: Double?, val goldenHour: Double?, val polar: Polar?)

/** [fraction] lit (0–1); [phase] 0 new, 0.25 first quarter, 0.5 full, 0.75 last quarter. */
data class MoonPhase(val fraction: Double, val phase: Double, val name: String)

/**
 * The sun and moon, after SunCalc by Vladimir Agafonkin (BSD-2-Clause), line for line with web/core.js:
 * positions to a fraction of a degree and rise and set times to about a minute, plenty for a compass.
 */
object Sky {
    private const val RAD = PI / 180
    private const val DAY_MS = 86400000.0
    private const val J1970 = 2440588.0
    private const val J2000 = 2451545.0
    private const val OBLIQ = RAD * 23.4397

    private fun toDays(ms: Double) = ms / DAY_MS - 0.5 + J1970 - J2000
    private fun fromJulian(j: Double) = (j + 0.5 - J1970) * DAY_MS
    private fun rightAscension(l: Double, b: Double) = atan2(sin(l) * cos(OBLIQ) - tan(b) * sin(OBLIQ), cos(l))
    private fun declination(l: Double, b: Double) = asin(sin(b) * cos(OBLIQ) + cos(b) * sin(OBLIQ) * sin(l))
    private fun azimuthOf(h: Double, phi: Double, dec: Double) = atan2(sin(h), cos(h) * sin(phi) - tan(dec) * cos(phi))
    private fun altitudeOf(h: Double, phi: Double, dec: Double) = asin(sin(phi) * sin(dec) + cos(phi) * cos(dec) * cos(h))
    private fun siderealTime(d: Double, lw: Double) = RAD * (280.16 + 360.9856235 * d) - lw
    private fun solarMeanAnomaly(d: Double) = RAD * (357.5291 + 0.98560028 * d)

    private fun eclipticLongitude(m: Double): Double {
        val c = RAD * (1.9148 * sin(m) + 0.02 * sin(2 * m) + 0.0003 * sin(3 * m))
        return m + c + RAD * 102.9372 + PI
    }

    /** Declination and right ascension. */
    private class Coords(val dec: Double, val ra: Double, val dist: Double = 0.0)

    private fun sunCoords(d: Double): Coords {
        val l = eclipticLongitude(solarMeanAnomaly(d))
        return Coords(declination(l, 0.0), rightAscension(l, 0.0))
    }

    private fun astroRefraction(h0: Double): Double {
        val h = if (h0 < 0) 0.0 else h0
        return 0.0002967 / tan(h + 0.00312536 / (h + 0.08901179))
    }

    /** The sun's direction at [ms] (UTC milliseconds). */
    fun sunPosition(ms: Double, lat: Double, lon: Double): SkyPosition {
        val lw = RAD * -lon; val phi = RAD * lat; val d = toDays(ms); val c = sunCoords(d); val h = siderealTime(d, lw) - c.ra
        return SkyPosition(Geo.normalize(azimuthOf(h, phi, c.dec) / RAD + 180), altitudeOf(h, phi, c.dec) / RAD)
    }

    /** Sunrise, sunset and solar noon for the day containing [ms], and golden hour's start (sun 6° up) in the evening. */
    fun sunTimes(ms: Double, lat: Double, lon: Double): SunTimes {
        val j0 = 0.0009; val lw = RAD * -lon; val phi = RAD * lat; val d = toDays(ms)
        val n = Geo.jsRound(d - j0 - lw / (2 * PI)).toDouble()
        val ds = j0 + (0 + lw) / (2 * PI) + n
        val m = solarMeanAnomaly(ds); val l = eclipticLongitude(m); val dec = declination(l, 0.0)
        fun transit(a: Double) = J2000 + a + 0.0053 * sin(m) - 0.0069 * sin(2 * l)
        val jNoon = transit(ds)
        fun setFor(h: Double): Double? {
            val w = acos((sin(h) - sin(phi) * sin(dec)) / (cos(phi) * cos(dec)))
            if (w.isNaN()) return null
            return transit(j0 + (w + lw) / (2 * PI) + n)
        }
        val set = setFor(-0.833 * RAD)
        val golden = setFor(6 * RAD)
        // Midnight sun or polar night: which one, from the sun at noon.
        val polar = if (set == null) (if (altitudeOf(0.0, phi, dec) > 0) Polar.DAY else Polar.NIGHT) else null
        return SunTimes(
            noon = fromJulian(jNoon),
            sunrise = set?.let { fromJulian(jNoon - (it - jNoon)) },
            sunset = set?.let { fromJulian(it) },
            goldenHour = golden?.let { fromJulian(it) },
            polar = polar,
        )
    }

    private fun moonCoords(d: Double): Coords {
        val l0 = RAD * (218.316 + 13.176396 * d); val m = RAD * (134.963 + 13.064993 * d); val f = RAD * (93.272 + 13.229350 * d)
        val l = l0 + RAD * 6.289 * sin(m); val b = RAD * 5.128 * sin(f); val dist = 385001 - 20905 * cos(m)
        return Coords(declination(l, b), rightAscension(l, b), dist)
    }

    /** The moon's direction, like [sunPosition] (altitude corrected for refraction). */
    fun moonPosition(ms: Double, lat: Double, lon: Double): SkyPosition {
        val lw = RAD * -lon; val phi = RAD * lat; val d = toDays(ms); val c = moonCoords(d); val h = siderealTime(d, lw) - c.ra
        var alt = altitudeOf(h, phi, c.dec)
        alt += astroRefraction(alt)
        return SkyPosition(Geo.normalize(azimuthOf(h, phi, c.dec) / RAD + 180), alt / RAD)
    }

    private val PHASES = listOf("New Moon", "Waxing Crescent", "First Quarter", "Waxing Gibbous", "Full Moon", "Waning Gibbous", "Last Quarter", "Waning Crescent")

    fun moonPhase(ms: Double): MoonPhase {
        val d = toDays(ms); val s = sunCoords(d); val m = moonCoords(d); val sdist = 149598000.0
        val phi = acos(sin(s.dec) * sin(m.dec) + cos(s.dec) * cos(m.dec) * cos(s.ra - m.ra))
        val inc = atan2(sdist * sin(phi), m.dist - sdist * cos(phi))
        val angle = atan2(cos(s.dec) * sin(s.ra - m.ra), sin(s.dec) * cos(m.dec) - cos(s.dec) * sin(m.dec) * cos(s.ra - m.ra))
        val fraction = (1 + cos(inc)) / 2
        val phase = 0.5 + 0.5 * inc * (if (angle < 0) -1 else 1) / PI
        return MoonPhase(fraction, phase, PHASES[(Geo.jsRound(phase * 8) % 8).toInt()])
    }

    // ---------- How they read (the Sun tile and the widgets) ----------

    /** "6:42 AM – 5:01 PM", or "Sun up all day" / "Sun down all day". [clock] formats UTC milliseconds. */
    fun sunLine(t: SunTimes, clock: (Long) -> String): String = when {
        t.polar == Polar.DAY -> "Sun up all day"
        t.polar == Polar.NIGHT -> "Sun down all day"
        else -> "${clock(t.sunrise!!.toLong())} – ${clock(t.sunset!!.toLong())}"
    }

    /** "Waxing Gibbous · 82%" */
    fun moonLine(p: MoonPhase): String = "${p.name} · ${Geo.jsRound(p.fraction * 100)}%"
}
