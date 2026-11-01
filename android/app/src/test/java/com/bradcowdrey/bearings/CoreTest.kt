package com.bradcowdrey.bearings

import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * The coordinate formats, compass points, units, sun and moon, distances and the nearest place, against
 * Tests/fixtures/geo.json: the same expected values the web app (tests/web.test.js) and the Mac and
 * iPhone apps are checked against.
 */
class CoreTest {
    private val fixture: JSONObject by lazy {
        val file = listOf("../../Tests/fixtures/geo.json", "../Tests/fixtures/geo.json").map(::File).first { it.exists() }
        JSONObject(file.readText())
    }

    @Test fun formatsMatchTheFixture() {
        val places = fixture.getJSONArray("places")
        for (i in 0 until places.length()) {
            val p = places.getJSONObject(i)
            val lat = p.getDouble("lat"); val lon = p.getDouble("lon"); val name = p.getString("name")
            assertEquals(name, p.getString("dd"), Geo.copyText(Geo.Format.DD, lat, lon))
            assertEquals(name, p.getString("dms"), Geo.copyText(Geo.Format.DMS, lat, lon))
            assertEquals(name, p.getString("ddm"), Geo.copyText(Geo.Format.DDM, lat, lon))
            assertEquals(name, p.optString("utm").takeIf { !p.isNull("utm") }, Geo.utmText(lat, lon))
            assertEquals(name, p.optString("mgrs").takeIf { !p.isNull("mgrs") }, Geo.mgrs(lat, lon))
            assertEquals(name, p.getString("plus"), Geo.plusCode(lat, lon))
        }
    }

    @Test fun compassPoints() {
        val headings = fixture.getJSONArray("headings")
        for (i in 0 until headings.length()) {
            val h = headings.getJSONObject(i)
            assertEquals("${h.getDouble("deg")}", h.getString("point"), Geo.point(h.getDouble("deg")))
            assertEquals(h.getDouble("normalized"), Geo.normalize(h.getDouble("deg")), 1e-9)
        }
    }

    @Test fun elevations() {
        val list = fixture.getJSONArray("elevations")
        for (i in 0 until list.length()) {
            val e = list.getJSONObject(i)
            val (ft, m) = Geo.elevation(e.getDouble("metres"))
            assertEquals(e.getString("ft"), ft)
            assertEquals(e.getString("m"), m)
        }
    }

    @Test fun shortWayRoundAndSmoothing() {
        assertEquals(20.0, Geo.delta(350.0, 10.0), 1e-9)
        assertEquals(-20.0, Geo.delta(10.0, 350.0), 1e-9)
        val s = HeadingSmoother(0.5); s.push(359.0); val h = s.push(1.0)
        assertTrue("$h", h < 0.01 || h > 359.99)
    }

    @Test fun units() {
        assertEquals("±12 m", Geo.accuracy(12.0, false))
        assertEquals("±39 ft", Geo.accuracy(12.0, true))
        assertTrue(Geo.prefersFeet("US"))
        assertEquals(Geo.Format.DD, Geo.Format.PLUS.next)
    }

    private fun JSONObject.double(key: String): Double? = if (isNull(key)) null else getDouble(key)
    private fun JSONObject.string(key: String): String? = if (isNull(key)) null else getString(key)

    /** Times within a second; null where the fixture has none. */
    private fun assertTime(what: String, expected: Double?, actual: Double?) {
        if (expected == null) assertNull(what, actual) else { assertNotNull(what, actual); assertEquals(what, expected, actual!!, 1000.0) }
    }

    /** Directions within a millionth of a degree, the short way round (so 359.9999999 matches 0). */
    private fun assertDirection(what: String, expected: Double, actual: Double) =
        assertEquals(what, 0.0, Geo.delta(expected, actual), 1e-6)

    @Test fun sunAndMoon() {
        val sky = fixture.getJSONArray("sky")
        for (i in 0 until sky.length()) {
            val s = sky.getJSONObject(i)
            val lat = s.getDouble("lat"); val lon = s.getDouble("lon"); val t = s.getDouble("t")
            val what = "${s.getString("name")} at ${s.getLong("t")}"
            val sun = Sky.sunPosition(t, lat, lon)
            assertDirection("$what sun azimuth", s.getDouble("sunAzimuth"), sun.azimuth)
            assertEquals("$what sun altitude", s.getDouble("sunAltitude"), sun.altitude, 1e-6)
            val moon = Sky.moonPosition(t, lat, lon)
            assertDirection("$what moon azimuth", s.getDouble("moonAzimuth"), moon.azimuth)
            assertEquals("$what moon altitude", s.getDouble("moonAltitude"), moon.altitude, 1e-6)
            val times = Sky.sunTimes(t, lat, lon)
            assertTime("$what sunrise", s.double("sunrise"), times.sunrise)
            assertTime("$what sunset", s.double("sunset"), times.sunset)
            assertTime("$what noon", s.double("noon"), times.noon)
            assertTime("$what golden hour", s.double("goldenHour"), times.goldenHour)
            assertEquals("$what polar", s.string("polar"), times.polar?.name?.lowercase())
            val phase = Sky.moonPhase(t)
            assertEquals("$what moon lit", s.getDouble("moonFraction"), phase.fraction, 1e-9)
            assertEquals("$what moon phase", s.getDouble("moonPhase"), phase.phase, 1e-9)
            assertEquals("$what moon name", s.getString("moonName"), phase.name)
        }
    }

    @Test fun distancesAndBearings() {
        val pairs = fixture.getJSONArray("pairs")
        for (i in 0 until pairs.length()) {
            val p = pairs.getJSONObject(i)
            val a = p.getJSONArray("from"); val b = p.getJSONArray("to")
            val m = Geo.distance(a.getDouble(0), a.getDouble(1), b.getDouble(0), b.getDouble(1))
            assertEquals("$a → $b metres", p.getDouble("metres"), m, 1e-6)
            assertDirection("$a → $b bearing", p.getDouble("bearing"), Geo.bearing(a.getDouble(0), a.getDouble(1), b.getDouble(0), b.getDouble(1)))
            assertEquals(p.getString("feetText"), Geo.distanceText(p.getDouble("metres"), true))
            assertEquals(p.getString("metresText"), Geo.distanceText(p.getDouble("metres"), false))
        }
    }

    @Test fun speedsAndPressures() {
        val speeds = fixture.getJSONArray("speeds")
        for (i in 0 until speeds.length()) {
            val s = speeds.getJSONObject(i)
            assertEquals(s.getString("feet"), Geo.speedText(s.getDouble("mps"), true))
            assertEquals(s.getString("metric"), Geo.speedText(s.getDouble("mps"), false))
        }
        val pressures = fixture.getJSONArray("pressures")
        for (i in 0 until pressures.length()) {
            val p = pressures.getJSONObject(i)
            assertEquals(p.getString("feet"), Geo.pressureText(p.getDouble("hpa"), true))
            assertEquals(p.getString("metric"), Geo.pressureText(p.getDouble("hpa"), false))
        }
    }

    @Test fun nearestPlace() {
        val file = listOf("../../Resources/Cities.tsv", "../Resources/Cities.tsv").map(::File).first { it.exists() }
        val cities = Geo.parseCities(file.readText())
        assertTrue("${cities.size} cities", cities.size > 30_000)
        val list = fixture.getJSONArray("nearest")
        for (i in 0 until list.length()) {
            val n = list.getJSONObject(i)
            val what = "${n.getDouble("lat")}, ${n.getDouble("lon")}"
            val p = Geo.nearestPlace(n.getDouble("lat"), n.getDouble("lon"), cities)
            if (n.isNull("name")) { assertNull(what, p); assertNull(Geo.placeText(p, true)); continue }
            assertNotNull(what, p)
            assertEquals(what, n.getString("name"), p!!.name)
            assertEquals(what, n.getString("region"), p.region)
            assertEquals(what, n.getString("country"), p.country)
            assertEquals(what, n.getDouble("km"), p.km, 1e-6)
            assertDirection(what, n.getDouble("from"), p.from)
            assertEquals(what, n.getString("feetText"), Geo.placeText(p, true))
            assertEquals(what, n.getString("metresText"), Geo.placeText(p, false))
        }
    }

    @Test fun toFixedRoundsLikeJavaScript() {
        // 1.005 is stored as 1.00499999999999989…, so toFixed(2) gives "1.00"; 0.125 is exact, so a tie, up.
        assertEquals("1.00", Geo.toFixed(1.005, 2))
        assertEquals("0.13", Geo.toFixed(0.125, 2))
        assertEquals("9.9", Geo.toFixed(9.94, 1))
    }

    @Test fun selfTestChecksPass() {
        for ((name, ok) in CoreChecks.run()) assertTrue(name, ok)
    }

    @Test fun termsSchedule() {
        assertTrue(TermsSchedule.shouldAsk(null, 0L, now = 1000L))
        assertTrue(!TermsSchedule.shouldAsk(Brand.TERMS_VERSION, 1000L, now = 2000L))
    }
}
