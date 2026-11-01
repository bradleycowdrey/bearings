package com.bradcowdrey.bearings

import android.content.Context
import android.location.Address
import android.location.Geocoder
import android.os.Build
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeoutOrNull
import java.util.Locale
import kotlin.coroutines.resume

/**
 * The place's name ("Aspen, Colorado"): the phone's own geocoder first, where it has one; otherwise
 * (no geocoder, or offline) the nearest place in the bundled GeoNames list, Resources/Cities.tsv, copied
 * into the app's assets at build time: its name within 5 km, "66 mi NE of Montrose, Colorado" up to
 * 200 km, and null beyond that ("Far from any town").
 */
object Places {
    /** Reads the bundled list; set by the app (from its assets). */
    @Volatile var source: () -> String? = { null }

    /** Parsed once, on first use (about 34,000 places, a fraction of a second). */
    val all: List<Geo.City> by lazy { source()?.let { Geo.parseCities(it) } ?: emptyList() }

    /** The bundled list's answer: a name, or null when nothing is within 200 km. */
    suspend fun nearby(latitude: Double, longitude: Double, feet: Boolean): String? = withContext(Dispatchers.Default) {
        Geo.placeText(Geo.nearestPlace(latitude, longitude, all), feet)
    }

    suspend fun name(context: Context, latitude: Double, longitude: Double, feet: Boolean): String? =
        geocode(context, latitude, longitude) ?: nearby(latitude, longitude, feet)

    /** Locality, then administrative area, from Android's Geocoder; null if there isn't one or it fails. */
    private suspend fun geocode(context: Context, latitude: Double, longitude: Double): String? {
        if (!Geocoder.isPresent()) return null
        val address: Address? = withContext(Dispatchers.IO) {
            withTimeoutOrNull(8_000) {
                runCatching {
                    val geocoder = Geocoder(context, Locale.getDefault())
                    if (Build.VERSION.SDK_INT >= 33) {
                        suspendCancellableCoroutine<Address?> { c ->
                            geocoder.getFromLocation(latitude, longitude, 1, object : Geocoder.GeocodeListener {
                                override fun onGeocode(addresses: MutableList<Address>) { if (c.isActive) c.resume(addresses.firstOrNull()) }
                                override fun onError(errorMessage: String?) { if (c.isActive) c.resume(null) }
                            })
                        }
                    } else {
                        // The blocking call, on the IO thread; deprecated in API 33 for the listener above.
                        @Suppress("DEPRECATION")
                        geocoder.getFromLocation(latitude, longitude, 1)?.firstOrNull()
                    }
                }.getOrNull()
            }
        }
        val a = address ?: return null
        val name = a.locality ?: a.subAdminArea ?: return null
        val region = a.adminArea ?: a.countryName
        return if (region.isNullOrEmpty() || region == name) name else "$name, $region"
    }
}
