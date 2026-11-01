package com.bradcowdrey.bearings.ui

import android.view.Gravity
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.OpenInNew
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Navigation
import androidx.compose.material.icons.filled.Remove
import androidx.compose.material.icons.outlined.Navigation
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableDoubleStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalLifecycleOwner
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import com.bradcowdrey.bearings.Brand
import com.bradcowdrey.bearings.Fix
import com.bradcowdrey.bearings.Geo
import org.maplibre.android.camera.CameraPosition
import org.maplibre.android.camera.CameraUpdateFactory
import org.maplibre.android.geometry.LatLng
import org.maplibre.android.maps.MapLibreMap
import org.maplibre.android.maps.MapLibreMapOptions
import org.maplibre.android.maps.MapView
import kotlin.math.cos
import kotlin.math.pow

/**
 * The map of where you are: MapLibre with OpenFreeMap's OpenStreetMap tiles (free, no key), centred on
 * you, north up or turned with your heading. The dot, accuracy circle and heading cone are drawn over its
 * centre. + and − zoom, the arrow switches north up and follow heading, and the last button opens the
 * place in your map app. [trueHeading] is from true north, as the map is.
 */
@Composable
fun MapSnippet(
    fix: Fix?,
    trueHeading: Double?,
    follow: Boolean,
    night: Boolean,
    speed: String?,
    onToggleFollow: () -> Unit,
    onOpen: (Fix) -> Unit,
    modifier: Modifier = Modifier,
    live: Boolean = true,
) {
    val shape = RoundedCornerShape(18.dp)
    BoxWithConstraints(modifier.clip(shape).background(Palette.tile)) {
        if (fix == null) {
            Text("The map appears once Bearings knows where you are.", style = text(13f, color = Palette.textMuted),
                textAlign = TextAlign.Center, modifier = Modifier.align(Alignment.Center).padding(16.dp))
        } else {
            var zoom by remember { mutableDoubleStateOf(15.0) }
            MapContent(fix, trueHeading, follow, live, zoom)
            // Night mode dims the map; the screen's red multiply then does the rest.
            if (night) Box(Modifier.fillMaxSize().background(Color.Black.copy(alpha = 0.45f)))
            // Four buttons stack down the right when there's room; on a short map they sit in a row.
            val tall = maxHeight >= 44.dp * 4 + 8.dp
            val buttons: @Composable () -> Unit = {
                MapButton(Icons.Filled.Add, "Zoom in") { zoom = (zoom + 1).coerceAtMost(19.0) }
                MapButton(Icons.Filled.Remove, "Zoom out") { zoom = (zoom - 1).coerceAtLeast(3.0) }
                MapButton(if (follow) Icons.Filled.Navigation else Icons.Outlined.Navigation,
                    if (follow) "Map follows your heading. Switch to north up" else "Map is north up. Switch to follow your heading", onToggleFollow)
                MapButton(Icons.AutoMirrored.Filled.OpenInNew, "Open in your map app") { onOpen(fix) }
            }
            if (tall) Column(Modifier.align(Alignment.TopEnd).padding(4.dp)) { buttons() }
            else Row(Modifier.align(Alignment.TopEnd).padding(4.dp)) { buttons() }
            if (speed != null) {
                Text(speed, style = text(13f, FontWeight.SemiBold, Palette.cream),
                    modifier = Modifier.align(Alignment.BottomStart).padding(10.dp).clip(CircleShape)
                        .background(Palette.bg.copy(alpha = 0.86f)).padding(horizontal = 10.dp, vertical = 5.dp))
            }
        }
    }
}

@Composable
private fun BoxScope.MapContent(fix: Fix, trueHeading: Double?, follow: Boolean, live: Boolean, zoom: Double) {
    val context = LocalContext.current
    val lifecycle = LocalLifecycleOwner.current.lifecycle
    var map by remember { mutableStateOf<MapLibreMap?>(null) }
    var loaded by remember { mutableStateOf(false) }
    // Following, the map turns in whole degrees (smooth enough, and not a camera move per sensor reading).
    val bearing = if (follow && trueHeading != null) Geo.jsRound(trueHeading).toDouble() % 360 else 0.0
    if (live) {
        val view = remember {
            // A TextureView map, so night mode's red multiply reaches it (a SurfaceView sits outside the drawing).
            MapView(context, MapLibreMapOptions.createFromAttributes(context).textureMode(true)).apply {
                onCreate(null)
                getMapAsync { m ->
                    m.uiSettings.setAllGesturesEnabled(false)
                    m.uiSettings.isCompassEnabled = false
                    m.uiSettings.isLogoEnabled = false
                    m.uiSettings.isAttributionEnabled = true
                    // Bottom right, clear of the speed chip.
                    m.uiSettings.setAttributionGravity(Gravity.BOTTOM or Gravity.END)
                    m.cameraPosition = CameraPosition.Builder().target(LatLng(fix.latitude, fix.longitude)).zoom(zoom).bearing(bearing).build()
                    m.setStyle(Brand.MAP_STYLE) { loaded = true }
                    map = m
                }
            }
        }
        DisposableEffect(lifecycle) {
            val observer = LifecycleEventObserver { _, e ->
                when (e) {
                    Lifecycle.Event.ON_START -> view.onStart()
                    Lifecycle.Event.ON_RESUME -> view.onResume()
                    Lifecycle.Event.ON_PAUSE -> view.onPause()
                    Lifecycle.Event.ON_STOP -> view.onStop()
                    else -> {}
                }
            }
            lifecycle.addObserver(observer)
            if (lifecycle.currentState.isAtLeast(Lifecycle.State.STARTED)) view.onStart()
            if (lifecycle.currentState.isAtLeast(Lifecycle.State.RESUMED)) view.onResume()
            onDispose { lifecycle.removeObserver(observer); view.onPause(); view.onStop(); view.onDestroy() }
        }
        // One camera for position, zoom and bearing together, so no change cancels another halfway.
        LaunchedEffect(fix.latitude, fix.longitude, zoom, bearing, map) {
            val m = map ?: return@LaunchedEffect
            val target = CameraPosition.Builder().target(LatLng(fix.latitude, fix.longitude)).zoom(zoom).bearing(bearing).build()
            m.animateCamera(CameraUpdateFactory.newCameraPosition(target), 250)
        }
        AndroidView({ view }, Modifier.fillMaxSize())
    }
    if (!loaded) {
        Text(if (live) "Loading the map…" else "Map", style = text(13f, color = Palette.textMuted),
            modifier = Modifier.align(Alignment.Center))
    }
    // You: accuracy circle, heading cone and dot, over the map's centre. MapLibre's zoom is in 512-dp tiles.
    val metresPerDp = 40075016.686 * cos(Math.toRadians(fix.latitude)) / (512 * 2.0.pow(zoom))
    Canvas(Modifier.fillMaxSize()) {
        val c = Offset(size.width / 2, size.height / 2)
        val r = (fix.accuracy / metresPerDp).toFloat().dp.toPx().coerceAtMost(size.maxDimension)
        drawCircle(Palette.accent.copy(alpha = 0.16f), r, c)
        drawCircle(Palette.accent.copy(alpha = 0.45f), r, c, style = Stroke(1.dp.toPx()))
        if (trueHeading != null) {
            val len = 34.dp.toPx(); val half = 16.dp.toPx()
            val cone = Path().apply { moveTo(0f, 0f); lineTo(-half, -len); lineTo(half, -len); close(); translate(c) }
            val brush = Brush.verticalGradient(listOf(Color.Transparent, Palette.accent.copy(alpha = 0.55f)), startY = c.y - len, endY = c.y)
            // On a map that follows the heading, the cone points straight up.
            rotate((trueHeading - bearing).toFloat(), c) { drawPath(cone, brush) }
        }
        drawCircle(Color.Black.copy(alpha = 0.3f), 10.dp.toPx(), c + Offset(0f, 1.dp.toPx()))
        drawCircle(Color.White, 9.5.dp.toPx(), c)
        drawCircle(Palette.accent, 6.5.dp.toPx(), c)
    }
}

/** A 32 dp circle on the map, in a 44 dp touch target. */
@Composable
private fun MapButton(icon: ImageVector, label: String, onClick: () -> Unit) {
    Box(
        Modifier.size(44.dp).clip(CircleShape).clickable(role = Role.Button, onClick = onClick).semantics { contentDescription = label },
        contentAlignment = Alignment.Center,
    ) {
        Box(Modifier.size(32.dp).clip(CircleShape).background(Palette.bg.copy(alpha = 0.86f)).border(0.5.dp, Palette.border, CircleShape),
            contentAlignment = Alignment.Center) {
            Icon(icon, null, tint = Palette.cream, modifier = Modifier.size(17.dp))
        }
    }
}
