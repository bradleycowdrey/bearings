package com.bradcowdrey.bearings.ui

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.requiredSize
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.OpenInNew
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.MoreHoriz
import androidx.compose.material.icons.filled.Navigation
import androidx.compose.material.icons.filled.Remove
import androidx.compose.material.icons.outlined.Info
import androidx.compose.material.icons.outlined.Navigation
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
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
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalLifecycleOwner
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
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
import org.maplibre.android.maps.Style
import org.maplibre.android.style.layers.BackgroundLayer
import org.maplibre.android.style.layers.FillExtrusionLayer
import org.maplibre.android.style.layers.FillLayer
import org.maplibre.android.style.layers.LineLayer
import org.maplibre.android.style.layers.Property
import org.maplibre.android.style.layers.PropertyFactory
import org.maplibre.android.style.layers.SymbolLayer
import kotlin.math.cos
import kotlin.math.pow

/**
 * The map of where you are: MapLibre with OpenFreeMap's OpenStreetMap tiles (free, no key) in a dark style
 * (docs/REFINE.md C2.3 #9), centred on you, north up or turned with your heading. The dot, accuracy circle and
 * heading cone are drawn over its centre. With [controls] (the map card and the map sheet) one vertical stack
 * of 36 dp circles in 48 dp targets sits 12 in from the top-trailing corner (+, −, follow heading, open in your
 * map app; a card under 192 tall shows +, − and ⋯ with the other two in its menu), the speed chip 12 in from
 * the top-leading corner, and "© OpenStreetMap" with an (i) for the sources bottom-leading. Without them (the
 * Map tile) it is a north-up thumbnail with gestures off and "© OSM" bottom-trailing. [trueHeading] is from true
 * north, as the map is. [topInset] and [bottomInset] keep the controls and the attribution clear of a bar over
 * the map and of the system bars (the map sheet, which is full-bleed).
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
    controls: Boolean = true,
    shape: Shape = Look.shape,
    edge: Boolean = true,
    topInset: Dp = 0.dp,
    bottomInset: Dp = 0.dp,
    attribution: Boolean = true,
) {
    // A rounded card on black: the tile fill before the map loads, a 1 dp edge over it.
    BoxWithConstraints(modifier.clip(shape).background(Palette.tileFill)) {
        if (fix == null) {
            Text(if (controls) "The map appears once Bearings knows where you are." else "—", style = text(13f, color = secondary()),
                textAlign = TextAlign.Center, modifier = Modifier.align(Alignment.Center).padding(16.dp))
        } else {
            var zoom by remember { mutableDoubleStateOf(if (controls) 15.0 else 14.0) }
            // POI labels only from 160 dp of height, road shields only from 200 dp of width (C3.4 #8).
            val labels = MapDark.Labels(tile = !controls, poi = maxHeight >= MapDark.POI_MIN_HEIGHT.dp, shields = maxWidth >= MapDark.SHIELD_MIN_WIDTH.dp)
            MapContent(fix, trueHeading, follow && controls, live, zoom, labels)
            // Night mode (C3.4 #15): the map dimmed to 35% (never near-black), which the screen's red multiply
            // then tints red.
            if (night) Box(Modifier.fillMaxSize().background(Color.Black.copy(alpha = 1f - MapDark.NIGHT_BRIGHTNESS)))
            if (controls) {
                // One vertical stack everywhere: 36 dp circles 8 apart, 12 in from the top-trailing corner (each
                // sits in a 44 dp cell, its 48 dp target reaching 2 past it). All four need 192 of height.
                val all = maxHeight - topInset >= 192.dp
                Column(Modifier.align(Alignment.TopEnd).padding(top = 8.dp + topInset, end = 8.dp)) {
                    MapButton(Icons.Filled.Add, "Zoom in") { zoom = (zoom + 1).coerceAtMost(19.0) }
                    MapButton(Icons.Filled.Remove, "Zoom out") { zoom = (zoom - 1).coerceAtLeast(3.0) }
                    if (all) {
                        MapButton(if (follow) Icons.Filled.Navigation else Icons.Outlined.Navigation,
                            if (follow) "Map follows your heading. Switch to north up" else "Map is north up. Switch to follow your heading", on = follow, onClick = onToggleFollow)
                        MapButton(Icons.AutoMirrored.Filled.OpenInNew, "Open in your map app") { onOpen(fix) }
                    } else {
                        MapOverflow(follow, night, onToggleFollow) { onOpen(fix) }
                    }
                }
                if (speed != null) {
                    Text(speed, style = text(13f, FontWeight.SemiBold, Color.White),
                        modifier = Modifier.align(Alignment.TopStart).padding(start = 12.dp, top = 12.dp + topInset).clip(CircleShape)
                            .background(Palette.mapControl).padding(horizontal = 10.dp, vertical = 5.dp))
                }
            }
            if (attribution) Attribution(controls, night, bottomInset)
        }
        // The card's edge, drawn over the map.
        if (edge) Box(Modifier.matchParentSize().border(Look.stroke, Palette.tileStroke, shape))
    }
}

/** ⋯ on a short card: Follow Heading (or North Up) and Open in Maps. */
@Composable
private fun MapOverflow(follow: Boolean, night: Boolean, onToggleFollow: () -> Unit, onOpen: () -> Unit) {
    var open by remember { mutableStateOf(false) }
    Box {
        MapButton(Icons.Filled.MoreHoriz, "More map controls") { open = true }
        DropdownMenu(open, onDismissRequest = { open = false }) {
            DropdownMenuItem(text = { Text(if (follow) "North Up" else "Follow Heading", style = text(15f, color = Color.White.night(night))) },
                onClick = { onToggleFollow(); open = false })
            DropdownMenuItem(text = { Text("Open in Maps", style = text(15f, color = Color.White.night(night))) },
                onClick = { onOpen(); open = false })
        }
    }
}

/**
 * The map's attribution, always visible (C3.4 #8): on a card or sheet one pill, "© OpenStreetMap ⓘ", 8 in from
 * the bottom-leading corner at 11 sp white on a dark scrim (well over 4.5:1), the whole pill a 48 dp target for
 * the sources; on a tile without the band (the Map tile draws its own), "© OSM" bottom-trailing.
 */
@Composable
private fun BoxScope.Attribution(full: Boolean, night: Boolean, bottomInset: Dp) {
    val scrim = Color.Black.copy(alpha = 0.6f)
    if (!full) {
        Text("© OSM", style = text(10f, FontWeight.Medium, white(Op.STRONG)),
            modifier = Modifier.align(Alignment.BottomEnd).padding(end = 8.dp, bottom = 8.dp).clip(RoundedCornerShape(4.dp))
                .background(scrim).padding(horizontal = 4.dp, vertical = 1.dp)
                .semantics { contentDescription = "Map data from OpenStreetMap contributors" })
        return
    }
    var open by remember { mutableStateOf(false) }
    val uri = LocalUriHandler.current
    // A 48 dp high target around a 24 dp pill; nudged down 4 so the pill's edge is 8 from the corner.
    Box(Modifier.align(Alignment.BottomStart).padding(start = 8.dp, bottom = bottomInset).offset(y = 4.dp)) {
        Box(
            Modifier.heightIn(min = 48.dp).clickable(role = Role.Button, onClickLabel = "Show the map's sources") { open = true }
                .semantics(mergeDescendants = true) { contentDescription = "Map data from OpenStreetMap contributors. Map sources" },
            contentAlignment = Alignment.CenterStart,
        ) {
            Row(
                Modifier.clip(RoundedCornerShape(12.dp)).background(scrim).heightIn(min = 24.dp).padding(start = 8.dp, end = 5.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text("© OpenStreetMap", style = text(11f, FontWeight.Medium, white(Op.STRONG)))
                Spacer(Modifier.width(4.dp))
                Icon(Icons.Outlined.Info, null, tint = Color.White, modifier = Modifier.size(15.dp))
            }
        }
        DropdownMenu(open, onDismissRequest = { open = false }) {
            for ((label, url) in SOURCES) {
                DropdownMenuItem(text = { Text(label, style = text(15f, color = Color.White.night(night))) },
                    onClick = { uri.openUri(url); open = false })
            }
        }
    }
}

private val SOURCES = listOf(
    "© OpenStreetMap contributors" to "https://www.openstreetmap.org/copyright",
    "OpenFreeMap" to "https://openfreemap.org",
    "© OpenMapTiles" to "https://www.openmaptiles.org",
    "MapLibre" to "https://maplibre.org",
)

/**
 * The dark map (C2.3 #9, C3.4 #8): OpenFreeMap's style recoloured once it loads, so the map is not the brightest
 * thing on a black screen. Land about #0F3B3A, roads #5A6470, water #22348A. Every label (a symbol layer's
 * text) is #C9D3D6 in Noto Sans Regular (never italic or bold, never the style's own cyan), 12 sp (11 in the
 * tile), on a 1.5 dp #0F3B3A halo, at 70% in the tile. POI labels are hidden on a map under 160 dp tall and
 * road shields on one under 200 dp wide. The self-test checks these values ([labelColor], [labelFont]).
 */
object MapDark {
    const val LAND = "#0F3B3A"
    const val COVER = "#124342"
    const val BUILDING = "#1B4A49"
    const val WATER = "#22348A"
    const val ROAD = "#5A6470"
    const val CASING = "#2E353D"
    const val BOUNDARY = "#4A6664"
    const val LABEL = "#C9D3D6"
    const val HALO = "#0F3B3A"
    const val HALO_WIDTH = 1.5f
    const val LABEL_SIZE = 12f
    const val LABEL_SIZE_TILE = 11f
    const val TILE_OPACITY = 0.7f
    /** The one font every label uses: OpenFreeMap's upright regular. */
    val FONT = arrayOf("Noto Sans Regular")
    const val POI_MIN_HEIGHT = 160
    const val SHIELD_MIN_WIDTH = 200
    /** Night: the map at 35% of its brightness, then the screen's red multiply. */
    const val NIGHT_BRIGHTNESS = 0.35f

    /** What the labels of one map should be: the tile's smaller, fainter labels, and which kinds are shown. */
    data class Labels(val tile: Boolean, val poi: Boolean, val shields: Boolean)

    /** The colour and font a label is drawn in, for the self-test (one rule for every symbol layer). */
    val labelColor: String get() = LABEL
    val labelFont: List<String> get() = FONT.toList()

    fun apply(style: Style, labels: Labels) {
        // Each layer on its own, so one the map engine refuses never leaves the rest in the style's own colours.
        for (layer in style.layers) runCatching {
            val id = layer.id.lowercase()
            val water = "water" in id || "ocean" in id || "river" in id || "lake" in id
            when (layer) {
                is BackgroundLayer -> layer.setProperties(PropertyFactory.backgroundColor(LAND))
                is FillLayer -> layer.setProperties(PropertyFactory.fillColor(when {
                    water -> WATER
                    "building" in id -> BUILDING
                    else -> COVER
                }))
                is FillExtrusionLayer -> layer.setProperties(PropertyFactory.fillExtrusionColor(BUILDING))
                is LineLayer -> layer.setProperties(PropertyFactory.lineColor(when {
                    water -> WATER
                    "boundary" in id || "admin" in id -> BOUNDARY
                    "casing" in id -> CASING
                    else -> ROAD
                }))
                is SymbolLayer -> {
                    // Only the kinds this rule hides are switched (back) on; the style's other choices stay.
                    val poi = "poi" in id; val shield = "shield" in id
                    if (poi || shield) {
                        val hidden = (poi && !labels.poi) || (shield && !labels.shields)
                        layer.setProperties(PropertyFactory.visibility(if (hidden) Property.NONE else Property.VISIBLE))
                    }
                    layer.setProperties(
                        PropertyFactory.textColor(LABEL),
                        PropertyFactory.textHaloColor(HALO),
                        PropertyFactory.textHaloWidth(HALO_WIDTH),
                        PropertyFactory.textHaloBlur(0f),
                        PropertyFactory.textFont(FONT),
                        PropertyFactory.textSize(if (labels.tile) LABEL_SIZE_TILE else LABEL_SIZE),
                        PropertyFactory.textOpacity(if (labels.tile) TILE_OPACITY else 1f),
                    )
                }
                else -> {}
            }
        }
    }
}

@Composable
private fun BoxScope.MapContent(fix: Fix, trueHeading: Double?, follow: Boolean, live: Boolean, zoom: Double, labels: MapDark.Labels) {
    val context = LocalContext.current
    val lifecycle = LocalLifecycleOwner.current.lifecycle
    var map by remember { mutableStateOf<MapLibreMap?>(null) }
    var loaded by remember { mutableStateOf(false) }
    var style by remember { mutableStateOf<Style?>(null) }
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
                    // The attribution is drawn by MapSnippet (always visible, with a 48 dp (i)).
                    m.uiSettings.isAttributionEnabled = false
                    m.cameraPosition = CameraPosition.Builder().target(LatLng(fix.latitude, fix.longitude)).zoom(zoom).bearing(bearing).build()
                    m.setStyle(Brand.MAP_STYLE) { st -> MapDark.apply(st, labels); style = st; loaded = true }
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
        // The dark colours and the label rules, again whenever the map's size changes which labels show.
        LaunchedEffect(style, labels) { style?.let { MapDark.apply(it, labels) } }
        // One camera for position, zoom and bearing together, so no change cancels another halfway.
        LaunchedEffect(fix.latitude, fix.longitude, zoom, bearing, map) {
            val m = map ?: return@LaunchedEffect
            val target = CameraPosition.Builder().target(LatLng(fix.latitude, fix.longitude)).zoom(zoom).bearing(bearing).build()
            m.animateCamera(CameraUpdateFactory.newCameraPosition(target), 250)
        }
        AndroidView({ view }, Modifier.fillMaxSize())
    }
    if (!loaded) {
        Text(if (live) "Loading the map…" else "Map", style = text(13f, color = secondary()),
            modifier = Modifier.align(Alignment.Center))
    }
    // You: accuracy circle, heading cone and dot, over the map's centre. MapLibre's zoom is in 512-dp tiles.
    val metresPerDp = 40075016.686 * cos(Math.toRadians(fix.latitude)) / (512 * 2.0.pow(zoom))
    Canvas(Modifier.fillMaxSize()) {
        val c = Offset(size.width / 2, size.height / 2)
        val r = (fix.accuracy / metresPerDp).toFloat().dp.toPx().coerceAtMost(size.maxDimension)
        drawCircle(white(0.1f), r, c)
        drawCircle(white(0.4f), r, c, style = Stroke(1.dp.toPx()))
        if (trueHeading != null) {
            val len = 34.dp.toPx(); val half = 16.dp.toPx()
            val cone = Path().apply { moveTo(0f, 0f); lineTo(-half, -len); lineTo(half, -len); close(); translate(c) }
            val brush = Brush.verticalGradient(listOf(Color.Transparent, white(Op.POINTS)), startY = c.y - len, endY = c.y)
            // On a map that follows the heading, the cone points straight up.
            rotate((trueHeading - bearing).toFloat(), c) { drawPath(cone, brush) }
        }
        // You: a white dot 16 with a 3 dp ring of black at 35%, on a soft shadow.
        drawCircle(Color.Black.copy(alpha = 0.18f), 12.5.dp.toPx(), c + Offset(0f, 1.dp.toPx()))
        drawCircle(Color.Black.copy(alpha = 0.35f), 11.dp.toPx(), c)
        drawCircle(Color.White, 8.dp.toPx(), c)
    }
}

/**
 * A 36 dp circle on the map in a 44 dp cell (so a stack's circles are 8 apart), with a 48 dp touch target:
 * dark, or white when [on] (Follow Heading).
 */
@Composable
private fun MapButton(icon: ImageVector, label: String, on: Boolean = false, onClick: () -> Unit) {
    Box(Modifier.size(44.dp), contentAlignment = Alignment.Center) {
        Box(
            Modifier.requiredSize(48.dp).clip(CircleShape).clickable(role = Role.Button, onClick = onClick).semantics { contentDescription = label },
            contentAlignment = Alignment.Center,
        ) {
            Box(Modifier.size(36.dp).clip(CircleShape).background(if (on) Color.White else Palette.mapControl),
                contentAlignment = Alignment.Center) {
                Icon(icon, null, tint = if (on) Color.Black else Color.White, modifier = Modifier.size(17.dp))
            }
        }
    }
}
