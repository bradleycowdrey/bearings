package com.bradcowdrey.bearings.widget

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationManager
import androidx.core.content.edit
import com.bradcowdrey.bearings.Geo
import com.bradcowdrey.bearings.Navigator
import com.bradcowdrey.bearings.Places
import com.bradcowdrey.bearings.Sky
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.util.Date
import java.util.Locale

/**
 * The last fix the app (or the widget's own refresh) found: what the widget shows, since a widget can't
 * run the compass. Kept in the app's preferences.
 */
data class Snapshot(
    val latitude: Double,
    val longitude: Double,
    /** Horizontal accuracy, metres. */
    val accuracy: Double,
    /** Ground elevation in metres, or null while unknown. */
    val elevation: Double?,
    /** True when [elevation] came from GPS, false for terrain data. */
    val fromGps: Boolean,
    /** "Aspen, Colorado", or null when far from any town. */
    val place: String?,
    /** When the fix was taken, UTC milliseconds. */
    val time: Long,
)

/**
 * Everything one widget shows, worked out for the moment it's drawn. Null [snapshot] is the empty state.
 * Every bearing here is TRUE (from true north): the widget's ring is fixed north-up, since a widget can't read
 * the compass, so it only shows directions that hold wherever the phone points.
 */
class WidgetEntry(
    val snapshot: Snapshot?,
    val place: String,
    val elevationMain: String?,
    val elevationOther: String?,
    val coordinates: List<String>,
    val asOf: String,
    val sunrise: String?,
    val sunset: String?,
    /** "Sun up all day" or "Sun down all day", instead of sunrise and sunset. */
    val sunAllDay: String?,
    val sunAzimuth: Double?,
    val sunUp: Boolean,
    val moonLine: String,
    val moonPhase: Double,
    val markLine: String?,
    /** The short place ("Maroon Bells" of "Maroon Bells, Colorado") for the Small header. */
    val shortPlace: String = place,
    /** "Sun, Nov 1 · 9:41 AM": the day and time of the reading, for the Medium and Large headers. */
    val asOfLong: String = asOf,
    /** The sun's altitude in degrees (the header's sky follows it, as the app's location bar does). */
    val sunAltitude: Double? = null,
    val moonAzimuth: Double? = null,
    val moonUp: Boolean = false,
    /** The moon lit, 0 to 1 ("53%"), and the phase's name ("Last quarter"). */
    val moonPercent: String = "",
    val moonName: String = "",
    /** The marked spot's true bearing from the reading, its distance ("9.2 mi") and "46° NE". */
    val markBearing: Double? = null,
    val markDistance: String? = null,
    val markPoint: String? = null,
    /** The bearing locked in the app, as a true bearing, while one is set. */
    val lock: Double? = null,
)

object WidgetData {
    private const val KEY = "widget.snapshot"
    /** The bearing locked in the app (true degrees), written by Navigator whenever the lock changes. */
    private const val LOCK = "widget.lock"
    private fun prefs(context: Context) = context.getSharedPreferences("bearings", Context.MODE_PRIVATE)

    fun save(context: Context, s: Snapshot) = prefs(context).edit { putString(KEY, encode(s).toString()) }

    fun read(context: Context): Snapshot? = prefs(context).getString(KEY, null)?.let { runCatching { decode(JSONObject(it)) }.getOrNull() }

    /** The locked bearing for the widget (true degrees), or null to clear it. */
    fun saveLock(context: Context, trueBearing: Double?) = prefs(context).edit {
        if (trueBearing == null) remove(LOCK) else putString(LOCK, Geo.normalize(trueBearing).toString())
    }

    fun readLock(context: Context): Double? = prefs(context).getString(LOCK, null)?.toDoubleOrNull()

    /** For the self-test, which puts back whatever was saved before. */
    fun raw(context: Context): String? = prefs(context).getString(KEY, null)
    fun restore(context: Context, raw: String?) = prefs(context).edit { if (raw == null) remove(KEY) else putString(KEY, raw) }

    fun encode(s: Snapshot): JSONObject = JSONObject().apply {
        put("latitude", s.latitude); put("longitude", s.longitude); put("accuracy", s.accuracy)
        s.elevation?.let { put("elevation", it) }
        put("fromGps", s.fromGps)
        s.place?.let { put("place", it) }
        put("time", s.time)
    }

    fun decode(o: JSONObject) = Snapshot(
        latitude = o.getDouble("latitude"), longitude = o.getDouble("longitude"), accuracy = o.getDouble("accuracy"),
        elevation = if (o.has("elevation")) o.getDouble("elevation") else null,
        fromGps = o.optBoolean("fromGps", false),
        place = if (o.has("place")) o.getString("place") else null,
        time = o.getLong("time"),
    )

    /**
     * The widget's own refresh (every 30 minutes): Android's last known location, when Bearings may use
     * it and it's newer than the saved fix; the elevation looked up again after moving 100 m, and the
     * place named again after 500 m (as the app does).
     */
    suspend fun refresh(context: Context) {
        val saved = read(context)
        val location = lastKnown(context) ?: return
        if (saved != null && location.time <= saved.time) return
        val feet = feet(context)
        val moved = saved?.let { Geo.distance(it.latitude, it.longitude, location.latitude, location.longitude) } ?: Double.MAX_VALUE
        val elevation = if (moved < 100 && saved != null) saved.elevation else
            withContext(Dispatchers.IO) { Navigator.fetchGround(Geo.rounded(location.latitude), Geo.rounded(location.longitude)) }
        val place = if (moved < 500 && saved != null) saved.place else Places.name(context, location.latitude, location.longitude, feet)
        save(context, Snapshot(location.latitude, location.longitude, location.accuracy.toDouble(), elevation,
            fromGps = moved < 100 && saved?.fromGps == true, place = place, time = location.time))
    }

    private fun lastKnown(context: Context): Location? {
        val fine = context.checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED
        val coarse = context.checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED
        if (!fine && !coarse) return null
        val manager = context.getSystemService(Context.LOCATION_SERVICE) as? LocationManager ?: return null
        return runCatching { manager.getProviders(true) }.getOrDefault(emptyList())
            .mapNotNull { runCatching { manager.getLastKnownLocation(it) }.getOrNull() }
            .maxByOrNull { it.time }
    }

    private fun feet(context: Context) = prefs(context).getBoolean("feet", Geo.prefersFeet(Locale.getDefault().country))

    /** What the widget shows now: the saved fix in the app's units and coordinate format, and the sky right now. */
    fun entry(context: Context, now: Long = System.currentTimeMillis()): WidgetEntry =
        entry(context, read(context), Navigator.savedMark(prefs(context)), readLock(context), now)

    /**
     * The entry for a given fix, marked spot and locked bearing (true degrees): the sun and moon worked out for
     * [now] at the fix. The self-test draws the sample through this without touching what the app saved.
     */
    fun entry(context: Context, s: Snapshot?, mark: Pair<Double, Double>?, lock: Double?, now: Long): WidgetEntry {
        val prefs = prefs(context)
        val feet = feet(context)
        val clockFormat = android.text.format.DateFormat.getTimeFormat(context)
        val clock = { ms: Long -> clockFormat.format(Date(ms)) }
        val phase = Sky.moonPhase(now.toDouble())
        val percent = "${Geo.jsRound(phase.fraction * 100)}%"
        if (s == null) {
            return WidgetEntry(null, "Bearings", null, null, emptyList(), "", null, null, null, null, false, Sky.moonWords(phase), phase.phase, null,
                moonPercent = percent, moonName = Sky.phaseName(phase))
        }
        val (ft, m) = s.elevation?.let { Geo.elevation(it) } ?: (null to null)
        val coordinates = when (val f = Geo.format(Geo.Format.of(prefs.getString("format", null)), s.latitude, s.longitude)) {
            is Geo.Formatted.Pair -> listOf(f.lat, f.lon)
            is Geo.Formatted.Single -> listOf(f.text)
        }
        val times = Sky.sunTimes(now.toDouble(), s.latitude, s.longitude)
        val sun = Sky.sunPosition(now.toDouble(), s.latitude, s.longitude)
        val moon = Sky.moonPosition(now.toDouble(), s.latitude, s.longitude)
        val markBearing = mark?.let { (lat, lon) -> Geo.bearing(s.latitude, s.longitude, lat, lon) }
        val markDistance = mark?.let { (lat, lon) -> Geo.distanceText(Geo.distance(s.latitude, s.longitude, lat, lon), feet) }
        val markPoint = markBearing?.let { "${Geo.jsRound(it) % 360}° ${Geo.point(it)}" }
        val markLine = if (markDistance != null && markPoint != null) "Marked spot · $markDistance · $markPoint" else null
        val place = s.place ?: "Far from any town"
        val day = java.text.SimpleDateFormat(android.text.format.DateFormat.getBestDateTimePattern(Locale.getDefault(), "EEEMMMd"), Locale.getDefault())
        return WidgetEntry(
            snapshot = s,
            place = place,
            elevationMain = if (feet) ft else m,
            elevationOther = if (feet) m else ft,
            coordinates = coordinates,
            asOf = clock(s.time),
            sunrise = times.sunrise?.let { clock(it.toLong()) },
            sunset = times.sunset?.let { clock(it.toLong()) },
            sunAllDay = if (times.polar != null) Sky.sunLine(times, clock) else null,
            sunAzimuth = sun.azimuth,
            sunUp = sun.altitude > 0,
            moonLine = Sky.moonWords(phase),
            moonPhase = phase.phase,
            markLine = markLine,
            shortPlace = place.substringBefore(',').trim().ifEmpty { place },
            asOfLong = "${day.format(Date(s.time))} · ${clock(s.time)}",
            sunAltitude = sun.altitude,
            moonAzimuth = moon.azimuth,
            moonUp = moon.altitude > 0,
            moonPercent = percent,
            moonName = Sky.phaseName(phase),
            markBearing = markBearing,
            markDistance = markDistance,
            markPoint = markPoint,
            lock = lock,
        )
    }
}
