package com.bradcowdrey.bearings

import android.Manifest
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.view.Surface
import androidx.activity.ComponentActivity
import androidx.activity.SystemBarStyle
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.lifecycleScope
import com.bradcowdrey.bearings.ui.Layout
import com.bradcowdrey.bearings.ui.MainScreen
import com.bradcowdrey.bearings.ui.TermsScreen
import kotlinx.coroutines.launch

/**
 * The app: one screen. Extras for CI: `selftest` runs the checks and writes files/report.txt; `sample`
 * shows the sample place; `format` picks a coordinate format; `night` turns on night mode and `layout`
 * (small, medium, large, extraLarge) picks the layout, both without saving; `mapSheet` opens the map sheet
 * at launch; `noCompass` (with `sample`) shows the sample place as a phone without a compass shows it;
 * `lock` false and `spot` false (with `sample`) leave out the locked bearing and the marked spot (the live
 * state: no lock row, no spot row); `show` = "terms" shows the terms.
 */
class MainActivity : ComponentActivity() {
    private lateinit var nav: Navigator
    private var askTerms by mutableStateOf(false)
    private val ci get() = intent.getBooleanExtra("selftest", false) || intent.getBooleanExtra("sample", false)

    private val askLocation = registerForActivityResult(ActivityResultContracts.RequestMultiplePermissions()) {
        nav.markLocationAsked()
        nav.refreshAccess(asked = true)
        nav.start()
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        enableEdgeToEdge(statusBarStyle = SystemBarStyle.dark(0), navigationBarStyle = SystemBarStyle.dark(0))
        super.onCreate(savedInstanceState)
        nav = Navigator(applicationContext) { currentRotation() }
        intent.getStringExtra("format")?.let { nav.setFormat(Geo.Format.of(it)) }
        if (intent.hasExtra("night")) nav.setNight(intent.getBooleanExtra("night", false), save = false)
        intent.getStringExtra("layout")?.let { nav.setLayout(Layout.of(it), save = false) }
        val prefs = getSharedPreferences("bearings", MODE_PRIVATE)
        askTerms = intent.getStringExtra("show") == "terms" ||
            (!ci && TermsSchedule.shouldAsk(prefs.getString("terms.accepted", null), prefs.getLong("terms.acceptedAt", 0L)))
        setContent {
            if (askTerms) {
                TermsScreen {
                    prefs.edit().putString("terms.accepted", Brand.TERMS_VERSION).putLong("terms.acceptedAt", System.currentTimeMillis()).apply()
                    askTerms = false
                    useLocation()
                }
            } else {
                MainScreen(nav, onUseLocation = ::useLocation, onOpenSettings = ::openSettings,
                    showMapSheet = intent.getBooleanExtra("mapSheet", false))
            }
        }
        when {
            intent.getBooleanExtra("sample", false) -> nav.showSample(
                sampleLock = if (intent.getBooleanExtra("lock", true)) 240.0 else null,
                noCompass = intent.getBooleanExtra("noCompass", false),
                markSpot = intent.getBooleanExtra("spot", true),
            )
            intent.getBooleanExtra("selftest", false) -> lifecycleScope.launch { SelfTest.run(this@MainActivity, nav) }
        }
    }

    /** Starts everything, asking Android for location the first time. */
    private fun useLocation() {
        if (!nav.allowed() && !nav.locationAsked) {
            askLocation.launch(arrayOf(Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.ACCESS_COARSE_LOCATION))
        } else {
            nav.start()
        }
    }

    private fun openSettings() {
        startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.fromParts("package", packageName, null)))
    }

    @Suppress("DEPRECATION")
    private fun currentRotation(): Int =
        (if (Build.VERSION.SDK_INT >= 30) display?.rotation else windowManager.defaultDisplay.rotation) ?: Surface.ROTATION_0

    override fun onResume() {
        super.onResume()
        if (!askTerms && !ci) { nav.refreshAccess(nav.locationAsked); nav.start() }
    }

    override fun onPause() {
        super.onPause()
        if (!ci) nav.stop()
    }
}
