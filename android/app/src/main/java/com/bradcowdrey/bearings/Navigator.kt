package com.bradcowdrey.bearings

import android.Manifest
import android.content.Context
import android.content.SharedPreferences
import android.content.pm.PackageManager
import android.hardware.GeomagneticField
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Build
import android.os.Bundle
import android.os.Looper
import android.view.Surface
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableDoubleStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.bradcowdrey.bearings.ui.Layout
import com.bradcowdrey.bearings.widget.Snapshot
import com.bradcowdrey.bearings.widget.WidgetData
import com.bradcowdrey.bearings.widget.WidgetUpdates
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import kotlin.math.abs
import kotlin.math.sqrt

/** Where you are, as Android reports it. */
data class Fix(
    val latitude: Double,
    val longitude: Double,
    /** Horizontal accuracy, metres. */
    val accuracy: Double,
    /** Height above sea level from GPS (converted from the ellipsoid on Android 14+), only when it's good. */
    val altitude: Double?,
    val altitudeAccuracy: Double?,
    /** Height above the WGS84 ellipsoid, for the declination. */
    val ellipsoidHeight: Double,
    val time: Long,
)

/** Ground elevation for a rounded position, from Open-Meteo (Copernicus DEM, 90 m). */
data class Ground(val metres: Double, val latitude: Double, val longitude: Double)

enum class CompassStatus { STARTING, LIVE, UNAVAILABLE }
enum class GroundState { IDLE, LOADING, OK, FAILED }
enum class Access { NOT_ASKED, ALLOWED, DENIED }

/** "9,587 ft" over "2,922 m" with where it came from, or a note while there's no value. */
sealed interface ElevationReading {
    data class Value(val metres: Double, val source: String, val fromGps: Boolean) : ElevationReading
    data class Pending(val note: String) : ElevationReading
}

/** The sun or moon on the dial: its direction on the card, and whether it's above the horizon. */
data class DialBody(val azimuth: Double, val up: Boolean)

/**
 * Everything on Bearings' one screen: position, heading, the level, elevation, the place and time, the
 * sun and moon, a marked spot, and the settings that change how they read. Location comes from Android's
 * own LocationManager (no Google Play services); the heading from the rotation-vector sensor, remapped to
 * the screen; true north from GeomagneticField.
 */
class Navigator(private val context: Context, private val displayRotation: () -> Int = { Surface.ROTATION_0 }) :
    SensorEventListener, LocationListener {

    private val prefs = context.getSharedPreferences("bearings", Context.MODE_PRIVATE)
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private val sensors = context.getSystemService(Context.SENSOR_SERVICE) as SensorManager
    private val locations = context.getSystemService(Context.LOCATION_SERVICE) as LocationManager

    var fix by mutableStateOf<Fix?>(null); private set
    var access by mutableStateOf(Access.NOT_ASKED); private set
    var locating by mutableStateOf(false); private set
    /** Smoothed heading toward true or magnetic north (see [usingTrueNorth]), degrees. */
    var heading by mutableStateOf<Double?>(null); private set
    /** The dial card's rotation, unwrapped so it always turns the short way past north. */
    var cardRotation by mutableDoubleStateOf(0.0); private set
    var headingAccuracy by mutableStateOf<Double?>(null); private set
    var declination by mutableStateOf<Double?>(null); private set
    var usingTrueNorth by mutableStateOf(false); private set
    var compass by mutableStateOf(CompassStatus.STARTING); private set
    /** Gravity across the screen (x right, y down), as a fraction of g; null without a sensor. */
    var tilt by mutableStateOf<Pair<Float, Float>?>(null); private set
    var ground by mutableStateOf<Ground?>(null); private set
    var groundState by mutableStateOf(GroundState.IDLE); private set
    var lock by mutableStateOf<Double?>(null)
    var sample by mutableStateOf(false); private set

    /** The place's name; null once [placeKnown] means nowhere within 200 km. */
    var place by mutableStateOf<String?>(null); private set
    var placeKnown by mutableStateOf(false); private set
    /** Ground speed in metres per second, only while moving faster than 0.5 m/s. */
    var speed by mutableStateOf<Double?>(null); private set
    /** Air pressure in hectopascals, on phones with a barometer. */
    var pressure by mutableStateOf<Double?>(null); private set
    /** A magnet or metal nearby: the field is outside the Earth's own 20–70 µT. */
    var interference by mutableStateOf(false); private set
    /** Goes up by one each time the heading crosses N, E, S or W (the screen turns it into a haptic tick). */
    var ticks by mutableIntStateOf(0); private set
    /** Now, to the minute: the clock in the header, and the sun and moon. */
    var now by mutableLongStateOf(System.currentTimeMillis()); private set
    /** The spot marked with Mark This Spot, as latitude and longitude. */
    var mark by mutableStateOf(savedMark(prefs)); private set

    var format by mutableStateOf(Geo.Format.of(prefs.getString("format", null))); private set
    var feet by mutableStateOf(prefs.getBoolean("feet", Geo.prefersFeet(Locale.getDefault().country))); private set
    var preferTrueNorth by mutableStateOf(prefs.getBoolean("trueNorth", true)); private set
    var followHeading by mutableStateOf(prefs.getBoolean("followHeading", false)); private set
    var night by mutableStateOf(prefs.getBoolean("night", false)); private set
    /** The compass size (docs/LAYOUTS.md): Small, Medium (the default), Large or Extra Large. */
    var layout by mutableStateOf(Layout.of(prefs.getString("layout", null))); private set

    private val smoother = HeadingSmoother(0.2)
    private val rotation = FloatArray(9)
    private val remapped = FloatArray(9)
    private val orientation = FloatArray(3)
    private var accel: FloatArray? = null
    private var magnetic: FloatArray? = null
    private var fieldStrength: Double? = null
    private var statusAccuracy = SensorManager.SENSOR_STATUS_ACCURACY_HIGH
    private var started = false
    private var lastGroundAttempt = 0L
    private var timeout: Job? = null
    private var speedReset: Job? = null
    private var placeJob: Job? = null
    private var placeAt: Pair<Double, Double>? = null
    private var tickedAt: Int? = null
    private var saved: Snapshot? = WidgetData.read(context)
    /** The clock's time zone: the phone's, or Colorado's for the sample place. */
    private var zone: TimeZone = TimeZone.getDefault()

    private val rotationSensor = sensors.getDefaultSensor(Sensor.TYPE_ROTATION_VECTOR)
        ?: sensors.getDefaultSensor(Sensor.TYPE_GEOMAGNETIC_ROTATION_VECTOR)
    private val gravitySensor = sensors.getDefaultSensor(Sensor.TYPE_GRAVITY)
    private val accelSensor = sensors.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
    private val magSensor = sensors.getDefaultSensor(Sensor.TYPE_MAGNETIC_FIELD)
    private val pressureSensor = sensors.getDefaultSensor(Sensor.TYPE_PRESSURE)

    val hasCompass get() = rotationSensor != null || (accelSensor != null && magSensor != null)

    init {
        // The clock, on the minute.
        scope.launch {
            while (true) {
                if (!sample) now = System.currentTimeMillis()
                delay(60_000 - System.currentTimeMillis() % 60_000 + 50)
            }
        }
    }

    @JvmName("changeFormat") fun setFormat(value: Geo.Format) { format = value; prefs.edit().putString("format", value.id).apply(); WidgetUpdates.redraw(context) }

    @JvmName("changeFeet") fun setFeet(value: Boolean) {
        feet = value; prefs.edit().putBoolean("feet", value).apply()
        // "66 mi NE of Montrose" is in the units too, so name the place again.
        placeAt = null; fix?.let { nameThePlace(it) }
        WidgetUpdates.redraw(context)
    }

    fun setTrueNorth(value: Boolean) { preferTrueNorth = value; prefs.edit().putBoolean("trueNorth", value).apply(); smoother.reset() }
    @JvmName("changeFollowHeading") fun setFollowHeading(value: Boolean) { followHeading = value; prefs.edit().putBoolean("followHeading", value).apply() }
    /** [save] is false for CI's night-mode screenshot, which shouldn't change the setting. */
    fun setNight(value: Boolean, save: Boolean = true) { night = value; if (save) prefs.edit().putBoolean("night", value).apply() }
    fun cycleFormat() = setFormat(format.next)
    /** [save] is false for CI's `layout` extra, which shouldn't change the setting. */
    @JvmName("changeLayout") fun setLayout(value: Layout, save: Boolean = true) {
        layout = value
        if (save) prefs.edit().putString("layout", value.id).apply()
    }

    fun allowed(): Boolean =
        context.checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED ||
            context.checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED

    /** After the permission dialog, or when coming back to the app. */
    fun refreshAccess(asked: Boolean) {
        access = when {
            allowed() -> Access.ALLOWED
            asked -> Access.DENIED
            else -> Access.NOT_ASKED
        }
    }

    // ---------- Starting and stopping ----------

    fun start() {
        if (sample) return
        started = true
        now = System.currentTimeMillis()
        refreshAccess(prefs.getBoolean("locationAsked", false))
        startLocation()
        if (!hasCompass) { compass = CompassStatus.UNAVAILABLE } else {
            if (rotationSensor != null) sensors.registerListener(this, rotationSensor, SensorManager.SENSOR_DELAY_GAME)
            else {
                sensors.registerListener(this, accelSensor, SensorManager.SENSOR_DELAY_GAME)
                sensors.registerListener(this, magSensor, SensorManager.SENSOR_DELAY_GAME)
            }
            // The raw field as well, for the magnet warning.
            if (magSensor != null && rotationSensor != null) sensors.registerListener(this, magSensor, SensorManager.SENSOR_DELAY_NORMAL)
            timeout?.cancel()
            timeout = scope.launch { delay(4000); if (heading == null && !sample) compass = CompassStatus.UNAVAILABLE }
        }
        (gravitySensor ?: accelSensor)?.let { sensors.registerListener(this, it, SensorManager.SENSOR_DELAY_UI) }
        pressureSensor?.let { sensors.registerListener(this, it, SensorManager.SENSOR_DELAY_NORMAL) }
    }

    fun stop() {
        started = false
        sensors.unregisterListener(this)
        runCatching { locations.removeUpdates(this) }
    }

    fun markLocationAsked() = prefs.edit().putBoolean("locationAsked", true).apply()
    val locationAsked get() = prefs.getBoolean("locationAsked", false)

    private fun startLocation() {
        if (!allowed()) return
        locating = fix == null
        val providers = buildList {
            if (Build.VERSION.SDK_INT >= 31 && locations.allProviders.contains(LocationManager.FUSED_PROVIDER)) add(LocationManager.FUSED_PROVIDER)
            add(LocationManager.GPS_PROVIDER)
            add(LocationManager.NETWORK_PROVIDER)
        }.filter { locations.allProviders.contains(it) }
        for (p in providers) {
            try {
                locations.getLastKnownLocation(p)?.let { if (System.currentTimeMillis() - it.time < 2 * 60 * 1000) take(it) }
                locations.requestLocationUpdates(p, 1000L, 1f, this, Looper.getMainLooper())
            } catch (_: SecurityException) {
            } catch (_: IllegalArgumentException) {
            }
        }
    }

    // ---------- Location ----------

    override fun onLocationChanged(location: Location) { if (!sample) take(location) }
    @Deprecated("Deprecated in Java") override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) {}
    override fun onProviderEnabled(provider: String) {}
    override fun onProviderDisabled(provider: String) {}

    private fun take(location: Location) {
        val current = fix
        // A rougher reading from another source doesn't replace a recent, better one.
        if (current != null && location.accuracy > current.accuracy * 1.5 && location.time - current.time < 10_000) return
        val good = location.hasAltitude() && location.hasVerticalAccuracy() && location.verticalAccuracyMeters < 25
        val next = Fix(location.latitude, location.longitude, location.accuracy.toDouble(), null,
            if (good) location.verticalAccuracyMeters.toDouble() else null, location.altitude, location.time)
        fix = next
        locating = false
        // Speed only while really moving. Standing still sends no updates, so it lapses after a few seconds.
        val moving = location.hasSpeed() && location.speed >= 0.5f
        speed = if (moving) location.speed.toDouble() else null
        speedReset?.cancel()
        if (moving) speedReset = scope.launch { delay(5000); speed = null }
        // GPS heights on Android are above the ellipsoid; Android 14+ converts them to sea level on the phone.
        if (good && Build.VERSION.SDK_INT >= 34) {
            scope.launch {
                val msl = withContext(Dispatchers.IO) {
                    runCatching {
                        val copy = Location(location)
                        android.location.altitude.AltitudeConverter().addMslAltitudeToLocation(context, copy)
                        if (copy.hasMslAltitude()) copy.mslAltitudeMeters else null
                    }.getOrNull()
                }
                if (msl != null && fix?.time == next.time) { fix = next.copy(altitude = msl); saveForWidget() }
            }
        }
        lookUpGround()
        nameThePlace(next)
        saveForWidget()
    }

    // ---------- The place's name ----------

    /** Names the place, and again only after moving 500 m. */
    private fun nameThePlace(f: Fix) {
        if (sample) return
        val at = placeAt
        if (at != null && Geo.distance(at.first, at.second, f.latitude, f.longitude) < 500) return
        if (placeJob?.isActive == true) return
        placeAt = f.latitude to f.longitude
        placeJob = scope.launch {
            place = Places.name(context, f.latitude, f.longitude, feet)
            placeKnown = true
            saveForWidget()
        }
    }

    /** The header's first line. */
    val title: String
        get() = when {
            fix == null -> if (locating) "Finding where you are…" else "Bearings"
            !placeKnown -> "Finding where you are…"
            else -> place ?: "Far from any town"
        }

    // ---------- Ground elevation ----------

    /** Asks Open-Meteo, again only after moving about 100 m (or a minute after a failure). Sends only the rounded position. */
    fun lookUpGround() {
        val f = fix ?: return
        val lat = Geo.rounded(f.latitude); val lon = Geo.rounded(f.longitude)
        val g = ground
        if (g != null && g.latitude == lat && g.longitude == lon) return
        if (groundState == GroundState.LOADING) return
        if (groundState == GroundState.FAILED && System.currentTimeMillis() - lastGroundAttempt < 60_000) return
        groundState = GroundState.LOADING
        lastGroundAttempt = System.currentTimeMillis()
        scope.launch {
            val metres = withContext(Dispatchers.IO) { fetchGround(lat, lon) }
            if (metres != null) {
                ground = Ground(metres, lat, lon); groundState = GroundState.OK
                saveForWidget()
            } else {
                groundState = GroundState.FAILED
            }
        }
    }

    // ---------- The widget ----------

    /**
     * Saves the fix, elevation and place for the widget, and redraws it, when they change enough to show:
     * after moving 100 m, a new place name, or a new elevation.
     */
    private fun saveForWidget() {
        // Not before the place is named (a few seconds), or the widget would briefly say "Far from any town".
        if (sample || !placeKnown) return
        val f = fix ?: return
        val e = elevation as? ElevationReading.Value
        val next = Snapshot(f.latitude, f.longitude, f.accuracy, e?.metres, e?.fromGps == true, place, f.time)
        val last = saved
        val lastElevation = last?.elevation
        val nextElevation = next.elevation
        val changed = last == null ||
            Geo.distance(last.latitude, last.longitude, next.latitude, next.longitude) >= 100 ||
            last.place != next.place ||
            (lastElevation == null && nextElevation != null) ||
            (lastElevation != null && nextElevation != null && abs(nextElevation - lastElevation) >= 10)
        if (!changed) return
        saved = next
        WidgetData.save(context, next)
        WidgetUpdates.redraw(context)
    }

    // ---------- Sensors ----------

    override fun onSensorChanged(event: SensorEvent) {
        if (sample) return
        when (event.sensor.type) {
            Sensor.TYPE_ROTATION_VECTOR, Sensor.TYPE_GEOMAGNETIC_ROTATION_VECTOR -> {
                // Some phones reject a 5-value vector here; the first four are the rotation.
                SensorManager.getRotationMatrixFromVector(rotation, event.values.copyOf(minOf(4, event.values.size)))
                val estimate = if (event.values.size > 4 && event.values[4] > 0) Math.toDegrees(event.values[4].toDouble()) else null
                takeRotation(estimate)
            }
            Sensor.TYPE_GRAVITY -> setTilt(event.values)
            Sensor.TYPE_ACCELEROMETER -> {
                val a = accel ?: event.values.clone().also { accel = it }
                for (i in 0..2) a[i] += 0.2f * (event.values[i] - a[i])
                if (gravitySensor == null) setTilt(a)
                if (rotationSensor == null) fromAccelAndMag()
            }
            Sensor.TYPE_MAGNETIC_FIELD -> {
                magnetic = event.values.clone()
                takeField(event.values)
                if (rotationSensor == null) fromAccelAndMag()
            }
            Sensor.TYPE_PRESSURE -> {
                // Smoothed, and kept to a tenth so the screen redraws only when the reading moves.
                val hpa = event.values[0].toDouble()
                val p = pressure
                val next = if (p == null) hpa else p + 0.2 * (hpa - p)
                pressure = Math.round(next * 10) / 10.0
            }
        }
    }

    /** The Earth's field is 25–65 µT; well outside 20–70 µT something nearby is pulling the needle. */
    private fun takeField(v: FloatArray) {
        val m = sqrt((v[0] * v[0] + v[1] * v[1] + v[2] * v[2]).toDouble())
        val f = fieldStrength
        val smoothed = if (f == null) m else f + 0.15 * (m - f)
        fieldStrength = smoothed
        // A little hysteresis, so the warning doesn't flicker at the edge.
        interference = if (interference) smoothed < 22 || smoothed > 68 else smoothed < 20 || smoothed > 70
    }

    override fun onAccuracyChanged(sensor: Sensor, accuracy: Int) {
        if (sensor.type == Sensor.TYPE_MAGNETIC_FIELD || sensor.type == Sensor.TYPE_ROTATION_VECTOR) statusAccuracy = accuracy
    }

    private fun fromAccelAndMag() {
        val a = accel ?: return; val m = magnetic ?: return
        if (SensorManager.getRotationMatrix(rotation, null, a, m)) takeRotation(null)
    }

    private fun takeRotation(estimate: Double?) {
        val (x, y) = when (displayRotation()) {
            Surface.ROTATION_90 -> SensorManager.AXIS_Y to SensorManager.AXIS_MINUS_X
            Surface.ROTATION_180 -> SensorManager.AXIS_MINUS_X to SensorManager.AXIS_MINUS_Y
            Surface.ROTATION_270 -> SensorManager.AXIS_MINUS_Y to SensorManager.AXIS_X
            else -> SensorManager.AXIS_X to SensorManager.AXIS_Y
        }
        SensorManager.remapCoordinateSystem(rotation, x, y, remapped)
        SensorManager.getOrientation(remapped, orientation)
        val magneticHeading = Geo.normalize(Math.toDegrees(orientation[0].toDouble()))
        val f = fix
        val decl = f?.let { GeomagneticField(it.latitude.toFloat(), it.longitude.toFloat(), it.ellipsoidHeight.toFloat(), System.currentTimeMillis()).declination.toDouble() }
        declination = decl
        usingTrueNorth = preferTrueNorth && decl != null
        setHeading(if (usingTrueNorth) magneticHeading + decl!! else magneticHeading)
        headingAccuracy = estimate ?: when (statusAccuracy) {
            SensorManager.SENSOR_STATUS_ACCURACY_HIGH -> 10.0
            SensorManager.SENSOR_STATUS_ACCURACY_MEDIUM -> 20.0
            SensorManager.SENSOR_STATUS_ACCURACY_LOW -> 30.0
            else -> 45.0
        }
        compass = CompassStatus.LIVE
    }

    private fun setHeading(raw: Double) {
        val previous = heading
        val h = smoother.push(raw)
        heading = h
        cardRotation += Geo.delta(cardRotation, -h)
        if (previous != null) tickIfCrossed(previous, h)
    }

    /**
     * A tick each time the heading passes N, E, S or W; not again for the same point until you've turned
     * 10° away from it, so holding the phone right on north doesn't buzz.
     */
    private fun tickIfCrossed(from: Double, to: Double) {
        tickedAt?.let { if (abs(Geo.delta(it * 90.0, to)) > 10) tickedAt = null }
        if (abs(Geo.delta(from, to)) > 45) return
        for (i in 0..3) {
            val a = Geo.delta(i * 90.0, from); val b = Geo.delta(i * 90.0, to)
            val crossed = (a < 0 && b >= 0) || (a > 0 && b <= 0)
            if (crossed && abs(a) < 45 && tickedAt != i) { tickedAt = i; ticks++; return }
        }
    }

    private fun setTilt(v: FloatArray) {
        val g = SensorManager.GRAVITY_EARTH
        tilt = (-v[0] / g).coerceIn(-1f, 1f) to (v[1] / g).coerceIn(-1f, 1f)
    }

    // ---------- What the screen shows ----------

    /** Ground elevation from GPS when it's accurate (and converted to sea level), otherwise from terrain data. */
    val elevation: ElevationReading
        get() {
            val f = fix ?: return ElevationReading.Pending(" ")
            val alt = f.altitude; val acc = f.altitudeAccuracy
            if (alt != null && acc != null) return ElevationReading.Value(alt, "GPS ${Geo.accuracy(acc, feet)}", fromGps = true)
            ground?.let { return ElevationReading.Value(it.metres, "Terrain data", fromGps = false) }
            return ElevationReading.Pending(if (groundState == GroundState.FAILED) "Needs a connection" else "Looking it up…")
        }

    /** "True north · 8° E" */
    val northLabel: String
        get() {
            var text = if (usingTrueNorth) "True north" else "Magnetic north"
            val d = declination
            if (usingTrueNorth && d != null && abs(d) >= 0.5) text += " · ${Math.round(abs(d))}° ${if (d >= 0) "E" else "W"}"
            return text
        }

    val lockText: String?
        get() {
            val l = lock ?: return null; val h = heading ?: return null
            val d = Math.round(Geo.delta(h, l)).toInt()
            val how = if (d == 0) "on bearing" else "turn ${abs(d)}° ${if (d > 0) "right" else "left"}"
            return "Locked ${Math.round(l) % 360}° · $how"
        }

    fun toggleLock() {
        val h = heading ?: return
        lock = if (lock == null) (Math.round(h) % 360).toDouble() else null
    }

    /** Locks the bearing to the marked spot, as it sits on the card (the same north as the heading). */
    fun lockToSpot() {
        val b = markBearing ?: return
        lock = (Geo.jsRound(onCard(b)) % 360).toDouble()
    }

    /** A true bearing as it sits on the card, which is turned to magnetic north when that's chosen. */
    fun onCard(trueBearing: Double): Double = if (usingTrueNorth) trueBearing else Geo.normalize(trueBearing - (declination ?: 0.0))

    /** The heading from true north, for the map (which is always drawn true north up). */
    val trueHeading: Double?
        get() = heading?.let { if (usingTrueNorth) it else Geo.normalize(it + (declination ?: 0.0)) }

    val sun: DialBody?
        get() = fix?.let { val p = Sky.sunPosition(now.toDouble(), it.latitude, it.longitude); DialBody(onCard(p.azimuth), p.altitude > 0) }

    val moon: DialBody?
        get() = fix?.let { val p = Sky.moonPosition(now.toDouble(), it.latitude, it.longitude); DialBody(onCard(p.azimuth), p.altitude > 0) }

    val moonPhase: MoonPhase get() = Sky.moonPhase(now.toDouble())

    /** "6:42 – 5:01" (sunrise is the morning one, so no AM or PM), or the polar day or night. */
    val sunText: String?
        get() = fix?.let { f -> Sky.sunLine(Sky.sunTimes(now.toDouble(), f.latitude, f.longitude)) { shortClock(it) } }

    /** The phone's own time format without AM or PM: "6:42", or "06:42" on a 24-hour clock. */
    fun shortClock(ms: Long): String {
        val format = android.text.format.DateFormat.getTimeFormat(context).apply { timeZone = zone }
        val symbols = java.text.DateFormatSymbols.getInstance(Locale.getDefault()).amPmStrings
        var text = format.format(Date(ms))
        for (s in symbols) if (s.isNotEmpty()) text = text.replace(s, "")
        return text.replace('\u202F', ' ').replace('\u00A0', ' ').trim()
    }

    /** "9:41 AM" or "09:41", as the phone is set (12- or 24-hour). */
    fun clock(ms: Long): String =
        android.text.format.DateFormat.getTimeFormat(context).apply { timeZone = zone }.format(Date(ms))

    /** "Sat, Nov 1 · 9:41 AM" */
    val dateTimeText: String
        get() {
            val pattern = android.text.format.DateFormat.getBestDateTimePattern(Locale.getDefault(), "EEEMMMd")
            val date = SimpleDateFormat(pattern, Locale.getDefault()).apply { timeZone = zone }.format(Date(now))
            return "$date · ${clock(now)}"
        }

    // ---------- A marked spot ----------

    fun markHere() {
        val f = fix ?: return
        mark = f.latitude to f.longitude
        if (!sample) prefs.edit().putString("mark", "${f.latitude},${f.longitude}").apply()
        WidgetUpdates.redraw(context)
    }

    fun clearMark() {
        mark = null
        if (!sample) prefs.edit().remove("mark").apply()
        WidgetUpdates.redraw(context)
    }

    /** The marked spot's true bearing from here. */
    val markBearing: Double?
        get() { val f = fix ?: return null; val m = mark ?: return null; return Geo.bearing(f.latitude, f.longitude, m.first, m.second) }

    /** How far the marked spot is, metres. */
    val markDistance: Double?
        get() { val f = fix ?: return null; val m = mark ?: return null; return Geo.distance(f.latitude, f.longitude, m.first, m.second) }

    /** "0.4 mi · 245° SW", the direction from the same north as the heading. */
    val markText: String?
        get() {
            val b = markBearing ?: return null; val d = markDistance ?: return null
            val card = onCard(b)
            return "${Geo.distanceText(d, feet)} · ${Geo.jsRound(card) % 360}° ${Geo.point(card)}"
        }

    // ---------- Copy and share ----------

    val copyText: String? get() = fix?.let { Geo.copyText(format, it.latitude, it.longitude) }

    val shareLocationText: String?
        get() = fix?.let { "${copyText}\n${mapLink(it)}" }

    fun mapLink(f: Fix) = String.format(Locale.US, "https://www.openstreetmap.org/?mlat=%.5f&mlon=%.5f#map=16/%.5f/%.5f", f.latitude, f.longitude, f.latitude, f.longitude)

    // ---------- A sample place (screenshots, CI) ----------

    /** Maroon Bells, Colorado, at 9 AM on 1 November 2026, with a spot marked near Aspen and a bearing locked. */
    fun showSample(sampleHeading: Double = 228.0, sampleLock: Double? = 240.0) {
        stop()
        sample = true
        zone = TimeZone.getTimeZone("America/Denver")
        now = SAMPLE_TIME
        fix = Fix(39.09898, -106.94117, 5.0, null, null, 2925.0, SAMPLE_TIME)
        ground = Ground(2922.0, 39.099, -106.941); groundState = GroundState.OK
        place = "Maroon Bells, Colorado"; placeKnown = true
        usingTrueNorth = true; declination = 7.6; headingAccuracy = 8.0; compass = CompassStatus.LIVE
        smoother.reset(); setHeading(sampleHeading)
        tilt = -0.02f to 0.015f
        lock = sampleLock
        mark = 39.1911 to -106.8175
        pressure = 721.0
        access = Access.ALLOWED
    }

    companion object {
        const val POOR_HEADING_ACCURACY = 25.0
        const val SAMPLE_TIME = 1793548800000L

        /** The marked spot saved in the app's preferences ("lat,lon"), for the app and the widget. */
        fun savedMark(prefs: SharedPreferences): Pair<Double, Double>? {
            val parts = prefs.getString("mark", null)?.split(',') ?: return null
            val lat = parts.getOrNull(0)?.toDoubleOrNull(); val lon = parts.getOrNull(1)?.toDoubleOrNull()
            return if (lat != null && lon != null) lat to lon else null
        }

        fun fetchGround(lat: Double, lon: Double): Double? = runCatching {
            val url = URL("https://api.open-meteo.com/v1/elevation?latitude=$lat&longitude=$lon")
            val conn = url.openConnection() as HttpURLConnection
            conn.connectTimeout = 15000; conn.readTimeout = 15000
            conn.setRequestProperty("User-Agent", "Bearings (+https://github.com/bradleycowdrey/bearings)")
            try {
                if (conn.responseCode != 200) return null
                val body = conn.inputStream.bufferedReader().use { it.readText() }
                JSONObject(body).getJSONArray("elevation").getDouble(0).takeIf { it.isFinite() }
            } finally { conn.disconnect() }
        }.getOrNull()
    }
}
