package com.bradcowdrey.bearings

import android.app.Application
import com.bradcowdrey.bearings.widget.WidgetUpdates
import org.maplibre.android.MapLibre

class BearingsApp : Application() {
    override fun onCreate() {
        super.onCreate()
        MapLibre.getInstance(this)
        // The offline place names: Resources/Cities.tsv, copied into the assets at build time.
        Places.source = { runCatching { assets.open("Cities.tsv").bufferedReader().use { it.readText() } }.getOrNull() }
        WidgetUpdates.schedule(this)
    }
}
