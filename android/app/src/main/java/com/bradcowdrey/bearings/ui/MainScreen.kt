package com.bradcowdrey.bearings.ui

import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.view.HapticFeedbackConstants
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawing
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.MoreHoriz
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.BlendMode
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalClipboardManager
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.em
import androidx.compose.ui.unit.sp
import com.bradcowdrey.bearings.Access
import com.bradcowdrey.bearings.Brand
import com.bradcowdrey.bearings.BuildConfig
import com.bradcowdrey.bearings.CompassStatus
import com.bradcowdrey.bearings.ElevationReading
import com.bradcowdrey.bearings.Fix
import com.bradcowdrey.bearings.Geo
import com.bradcowdrey.bearings.Navigator
import kotlinx.coroutines.delay
import java.util.Locale

/**
 * Bearings' one screen, top to bottom as in docs/DESIGN.md: the place and time, the dial with the sun,
 * moon, marked spot and locked bearing, the heading, a subline (or a warning), the marked spot, four
 * tiles, and the map filling the rest. Everything fits one screen: on short phones the dial shrinks
 * and the gaps tighten.
 */
@Composable
fun MainScreen(nav: Navigator, onUseLocation: () -> Unit, onOpenSettings: () -> Unit) {
    var toast by remember { mutableStateOf<String?>(null) }
    var about by remember { mutableStateOf(false) }
    val clipboard = LocalClipboardManager.current
    val view = LocalView.current
    val context = LocalContext.current
    val uri = LocalUriHandler.current
    val copy = { nav.copyText?.let { clipboard.setText(AnnotatedString(it)); toast = "Coordinates copied" } }
    val openMap = { f: Fix ->
        val lat = String.format(Locale.US, "%.6f", f.latitude); val lon = String.format(Locale.US, "%.6f", f.longitude)
        try {
            context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse("geo:$lat,$lon?q=$lat,$lon")))
        } catch (_: ActivityNotFoundException) {
            uri.openUri(nav.mapLink(f))
        }
    }
    // A light tick as the heading passes N, E, S and W (the phone's own haptics setting applies).
    LaunchedEffect(nav.ticks) { if (nav.ticks > 0) view.performHapticFeedback(HapticFeedbackConstants.CLOCK_TICK) }
    val night = nav.night

    MaterialTheme(colorScheme = darkColorScheme(
        surface = Palette.tile.night(night), surfaceContainer = Palette.tile.night(night), onSurface = Color.White.night(night),
    )) {
        BoxWithConstraints(
            Modifier.fillMaxSize()
                // Night mode: the whole screen through a red multiply, so only red light is left.
                .drawWithContent { drawContent(); if (night) drawRect(Palette.nightRed, blendMode = BlendMode.Multiply) }
                .background(Palette.bg)
                .windowInsetsPadding(WindowInsets.safeDrawing),
        ) {
            val compact = maxHeight < 700.dp
            val fs = LocalDensity.current.fontScale.coerceIn(1f, 1.4f)
            val gap = if (compact) 8.dp else 12.dp
            val readoutSize = if (compact) 44f else 56f
            val tileTall = if (compact) 8.dp else 12.dp
            // What everything but the dial and the map takes, so the dial gets what's left (at most 36% of
            // the height and 360) and the map keeps at least its minimum.
            val tileH = (56 * fs).dp + tileTall * 2
            val fixed = 48.dp + gap + 4.dp + (readoutSize * 1.1f * fs).dp + (18 * fs).dp + gap +
                (if (nav.mark != null && nav.fix != null) 44.dp + gap else 0.dp) + tileH * 2 + 8.dp + gap + 12.dp
            val mapMin = if (compact) 96.dp else 120.dp
            val dialSide = minOf(minOf(maxWidth - 32.dp, maxHeight * 0.36f), minOf(360.dp, maxHeight - fixed - mapMin)).coerceAtLeast(120.dp)

            Column(
                Modifier.fillMaxSize().widthIn(max = 520.dp).align(Alignment.TopCenter).padding(start = 16.dp, end = 16.dp, top = 0.dp, bottom = 12.dp),
            ) {
                Header(nav, night, onCopy = { copy() }, onAbout = { about = true })
                Spacer(Modifier.height(gap))
                DialBlock(nav, dialSide)
                Spacer(Modifier.height(4.dp))
                if (nav.compass == CompassStatus.UNAVAILABLE && nav.heading == null) {
                    // No compass: say so where the heading would be, so nothing overlaps the dial.
                    Box(Modifier.fillMaxWidth().height((readoutSize * 1.1f * fs).dp + (18 * fs).dp), contentAlignment = Alignment.Center) {
                        Text("No compass on this device. Your coordinates, elevation and map still work.",
                            style = text(15f, color = Palette.textMuted), textAlign = TextAlign.Center, maxLines = 2,
                            modifier = Modifier.widthIn(max = 300.dp))
                    }
                } else {
                    Readout(nav, readoutSize)
                    Text(subline(nav), style = text(13f, color = Palette.textMuted).copy(lineHeight = 18.sp), textAlign = TextAlign.Center, maxLines = 1,
                        overflow = TextOverflow.Ellipsis, modifier = Modifier.fillMaxWidth().heightIn(min = 18.dp))
                }
                Spacer(Modifier.height(gap))
                val markText = nav.markText
                if (markText != null) {
                    MarkPill(markText, onClear = { nav.clearMark() })
                    Spacer(Modifier.height(gap))
                }
                if (nav.fix == null && nav.access != Access.ALLOWED) {
                    AskForLocation(nav.access == Access.DENIED, onUseLocation, onOpenSettings, Modifier.heightIn(min = tileH * 2 + 8.dp))
                } else {
                    Tiles(nav, tileTall, onCopy = { copy() })
                }
                Spacer(Modifier.height(gap))
                MapSnippet(
                    nav.fix, nav.trueHeading, nav.followHeading, night,
                    speed = nav.speed?.let { Geo.speedText(it, nav.feet) },
                    onToggleFollow = { nav.setFollowHeading(!nav.followHeading) },
                    onOpen = openMap,
                    modifier = Modifier.fillMaxWidth().weight(1f).heightIn(min = 80.dp),
                )
            }
            toast?.let { t ->
                LaunchedEffect(t) { delay(1600); toast = null }
                Text(t, style = text(14f, FontWeight.SemiBold, Palette.bg),
                    modifier = Modifier.align(Alignment.BottomCenter).padding(bottom = 32.dp).clip(CircleShape).background(Palette.cream)
                        .padding(horizontal = 16.dp, vertical = 9.dp).semantics { liveRegion = LiveRegionMode.Polite })
            }
        }
        if (about) AboutDialog(night) { about = false }
    }
}

// ---------- The dial and the heading ----------

@Composable
private fun DialBlock(nav: Navigator, side: Dp) {
    // TalkBack hears the heading at most every few seconds, not at the sensor's rate.
    var spoken by remember { mutableStateOf<Double?>(null) }
    LaunchedEffect(Unit) {
        while (true) {
            val h = nav.heading
            val s = spoken
            if (h == null || s == null || kotlin.math.abs(Geo.delta(s, h)) >= 3) spoken = h
            delay(3000)
        }
    }
    val label = dialLabel(nav, spoken)
    Box(Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
        Box(
            Modifier.size(side).clip(CircleShape)
                .clickable(role = Role.Button, enabled = nav.heading != null,
                    onClickLabel = if (nav.lock == null) "Lock this bearing" else "Clear the locked bearing") { nav.toggleLock() }
                .semantics { contentDescription = label; liveRegion = LiveRegionMode.Polite },
            contentAlignment = Alignment.Center,
        ) {
            val marks = DialMarks(
                lock = nav.lock,
                sun = nav.sun,
                moon = nav.moon,
                moonPhase = nav.moonPhase.phase,
                mark = nav.markBearing?.let { nav.onCard(it) },
            )
            Dial(nav.cardRotation, nav.heading, marks, nav.tilt, Modifier.fillMaxSize())
        }
    }
}

private fun dialLabel(nav: Navigator, heading: Double?): String {
    val h = heading ?: return "Compass"
    val lock = nav.lock?.let { ". Locked ${Math.round(it) % 360} degrees" } ?: ""
    return "Heading ${Math.round(h) % 360} degrees, ${Geo.pointName(h).lowercase()}$lock"
}

@Composable
private fun Readout(nav: Navigator, size: Float) {
    val h = nav.heading
    // Tabular figures, so the number doesn't jiggle as it changes.
    val big = text(size, FontWeight.SemiBold).copy(letterSpacing = (-0.03 * size).sp, lineHeight = (size * 1.1f).sp, fontFeatureSettings = "tnum")
    Row(Modifier.fillMaxWidth().semantics(mergeDescendants = true) {}, horizontalArrangement = Arrangement.Center) {
        Text(if (h == null) "—" else "${Math.round(h) % 360}°", style = big, modifier = Modifier.alignByBaseline())
        Spacer(Modifier.width(10.dp))
        Text(if (h == null) "" else Geo.point(h), style = text(size / 2, FontWeight.Medium, Palette.textMuted),
            modifier = Modifier.alignByBaseline().widthIn(min = (size * 1.1f).dp))
    }
}

private fun subline(nav: Navigator): AnnotatedString = buildAnnotatedString {
    val warn = SpanStyle(color = Palette.warn, fontWeight = FontWeight.SemiBold)
    when {
        nav.compass != CompassStatus.LIVE || nav.heading == null -> append(" ")
        nav.interference -> withStyle(warn) { append("Magnet or metal nearby: move away") }
        (nav.headingAccuracy ?: 0.0) > Navigator.POOR_HEADING_ACCURACY -> withStyle(warn) { append("Low accuracy: move your phone in a figure 8") }
        else -> {
            append(nav.northLabel)
            nav.headingAccuracy?.let { append(" · ±${Math.round(it)}°") }
        }
    }
    nav.lockText?.let {
        append(" · ")
        withStyle(SpanStyle(color = Palette.accent, fontWeight = FontWeight.SemiBold)) { append(it) }
    }
}

// ---------- The header and its menu ----------

@Composable
private fun Header(nav: Navigator, night: Boolean, onCopy: () -> Unit, onAbout: () -> Unit) {
    var open by remember { mutableStateOf(false) }
    val context = LocalContext.current
    val uri = LocalUriHandler.current
    fun share(text: String) {
        val send = Intent(Intent.ACTION_SEND).setType("text/plain").putExtra(Intent.EXTRA_TEXT, text)
        context.startActivity(Intent.createChooser(send, null))
    }
    Row(Modifier.fillMaxWidth().heightIn(min = 48.dp), verticalAlignment = Alignment.CenterVertically) {
        Column(Modifier.weight(1f).semantics(mergeDescendants = true) {}) {
            Text(nav.title, style = text(20f, FontWeight.SemiBold).copy(lineHeight = 24.sp), maxLines = 1, overflow = TextOverflow.Ellipsis)
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(nav.dateTimeText, style = text(13f, color = Palette.textMuted).copy(lineHeight = 16.sp), maxLines = 1,
                    overflow = TextOverflow.Ellipsis, modifier = Modifier.weight(1f, fill = false))
                if (nav.sample) {
                    Spacer(Modifier.width(8.dp))
                    Text("Sample", style = text(11f, FontWeight.SemiBold, Palette.bg),
                        modifier = Modifier.clip(CircleShape).background(Palette.warn).padding(horizontal = 7.dp, vertical = 1.dp))
                }
            }
        }
        Box {
            // A 36 dp circle in a 48 dp touch target.
            Box(
                Modifier.size(48.dp).clip(CircleShape).clickable(role = Role.Button, onClickLabel = "Open the menu") { open = true }
                    .semantics { contentDescription = "Settings and more" },
                contentAlignment = Alignment.Center,
            ) {
                Box(Modifier.size(36.dp).clip(CircleShape).background(Palette.tile).border(0.5.dp, Palette.border, CircleShape),
                    contentAlignment = Alignment.Center) {
                    Icon(Icons.Filled.MoreHoriz, null, tint = Palette.textSecondary, modifier = Modifier.size(20.dp))
                }
            }
            DropdownMenu(open, onDismissRequest = { open = false }) {
                val hasFix = nav.fix != null
                MenuSection("Coordinates", night)
                for (f in Geo.Format.entries) Check(f.title, nav.format == f, night) { nav.setFormat(f); open = false }
                MenuSection("Units", night)
                Check("Feet First", nav.feet, night) { nav.setFeet(true); open = false }
                Check("Metres First", !nav.feet, night) { nav.setFeet(false); open = false }
                MenuSection("North", night)
                Check("True North", nav.preferTrueNorth, night) { nav.setTrueNorth(true); open = false }
                Check("Magnetic North", !nav.preferTrueNorth, night) { nav.setTrueNorth(false); open = false }
                MenuSection("Map", night)
                Check("Follow Heading", nav.followHeading, night) { nav.setFollowHeading(!nav.followHeading); open = false }
                HorizontalDivider(color = Palette.border.night(night))
                Check("Night Mode", night, night) { nav.setNight(!night); open = false }
                HorizontalDivider(color = Palette.border.night(night))
                if (nav.mark == null) Item("Mark This Spot", night, hasFix) { nav.markHere(); open = false }
                else Item("Clear Marked Spot", night) { nav.clearMark(); open = false }
                Item(if (nav.lock == null) "Lock This Bearing" else "Clear Locked Bearing", night, nav.heading != null) { nav.toggleLock(); open = false }
                Item("Copy Coordinates", night, hasFix) { onCopy(); open = false }
                Item("Share My Location…", night, hasFix) { nav.shareLocationText?.let(::share); open = false }
                Item("Share Bearings…", night) { share("${Brand.SHARE_MESSAGE} ${Brand.PRODUCT_PAGE}"); open = false }
                HorizontalDivider(color = Palette.border.night(night))
                Item("Terms & Privacy", night) { uri.openUri(Brand.LEGAL); open = false }
                Item("About Bearings", night) { onAbout(); open = false }
            }
        }
    }
}

@Composable private fun MenuSection(title: String, night: Boolean) =
    Text(title.uppercase(), style = text(11f, FontWeight.SemiBold, Palette.textFaint.night(night)),
        modifier = Modifier.padding(start = 16.dp, top = 10.dp, bottom = 2.dp))

@Composable private fun Check(title: String, on: Boolean, night: Boolean, onClick: () -> Unit) =
    DropdownMenuItem(text = { Text(title, style = text(15f, color = Color.White.night(night))) }, onClick = onClick,
        leadingIcon = { Text(if (on) "✓" else "", style = text(15f, color = Palette.cream.night(night)), modifier = Modifier.widthIn(min = 14.dp)) })

@Composable private fun Item(title: String, night: Boolean, enabled: Boolean = true, onClick: () -> Unit) =
    DropdownMenuItem(text = { Text(title, style = text(15f, color = (if (enabled) Color.White else Palette.textFaint).night(night))) },
        onClick = onClick, enabled = enabled, leadingIcon = { Spacer(Modifier.widthIn(min = 14.dp)) })

// ---------- The marked spot ----------

@Composable
private fun MarkPill(label: String, onClear: () -> Unit) {
    Row(
        Modifier.fillMaxWidth().height(44.dp).clip(CircleShape).background(Palette.tile),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            buildAnnotatedString {
                withStyle(SpanStyle(color = Palette.accent, fontWeight = FontWeight.SemiBold)) { append("📍 Marked spot") }
                append(" · $label")
            },
            style = text(14f, FontWeight.Medium), maxLines = 1, overflow = TextOverflow.Ellipsis,
            modifier = Modifier.weight(1f).padding(start = 16.dp),
        )
        Box(
            Modifier.size(48.dp, 44.dp).clip(CircleShape).clickable(role = Role.Button, onClick = onClear)
                .semantics { contentDescription = "Clear the marked spot" },
            contentAlignment = Alignment.Center,
        ) { Icon(Icons.Filled.Close, null, tint = Palette.textMuted, modifier = Modifier.size(18.dp)) }
    }
}

// ---------- The tiles ----------

@Composable
private fun AskForLocation(denied: Boolean, onUseLocation: () -> Unit, onOpenSettings: () -> Unit, modifier: Modifier) {
    Column(modifier.fillMaxWidth().clip(RoundedCornerShape(18.dp)).background(Palette.tile).padding(horizontal = 14.dp, vertical = 12.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp, Alignment.CenterVertically)) {
        Text(if (denied) "Location is off for Bearings. Allow it in Settings to see where you are, your coordinates, elevation and map."
            else "Allow your location to see where you are, your latitude, longitude, elevation and map. It stays on this phone.",
            style = text(14f, color = Palette.textSecondary))
        Box(
            Modifier.heightIn(min = 48.dp).clip(CircleShape).background(Palette.cream)
                .clickable(role = Role.Button) { if (denied) onOpenSettings() else onUseLocation() }.padding(horizontal = 18.dp),
            contentAlignment = Alignment.Center,
        ) { Text(if (denied) "Open Settings" else "Use My Location", style = text(15f, FontWeight.SemiBold, Palette.bg)) }
    }
}

@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun Tiles(nav: Navigator, vertical: Dp, onCopy: () -> Unit) {
    val fix = nav.fix
    var tick by remember { mutableLongStateOf(System.currentTimeMillis()) }
    LaunchedEffect(Unit) { while (true) { delay(15_000); tick = System.currentTimeMillis() } }
    val stale = !nav.sample && fix != null && tick - fix.time > 120_000
    val tap = Modifier.combinedClickable(onClickLabel = "Change the coordinate format", onLongClickLabel = "Copy the coordinates",
        onLongClick = onCopy, onClick = { nav.cycleFormat() })
    val accuracy = fix?.let { "${Geo.accuracy(it.accuracy, nav.feet)} · ${if (nav.sample) "Sample" else ago(tick - it.time)}" }
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        when (val f = fix?.let { Geo.format(nav.format, it.latitude, it.longitude) }) {
            is Geo.Formatted.Single -> Tile(nav.format.title, AnnotatedString(f.text), accuracy ?: " ", vertical, stale,
                "${nav.format.title}, ${f.text}. Tap to change the format, touch and hold to copy", Modifier.fillMaxWidth().then(tap))
            is Geo.Formatted.Pair -> Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Tile("Latitude", AnnotatedString(f.lat), accuracy ?: " ", vertical, stale, "Latitude, ${f.lat}", Modifier.weight(1f).then(tap))
                Tile("Longitude", AnnotatedString(f.lon), nav.format.title, vertical, stale, "Longitude, ${f.lon}", Modifier.weight(1f).then(tap))
            }
            null -> Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Tile("Latitude", AnnotatedString("—"), if (nav.locating) "Finding you…" else " ", vertical, false, "Latitude, not known yet", Modifier.weight(1f))
                Tile("Longitude", AnnotatedString("—"), nav.format.title, vertical, false, "Longitude, not known yet", Modifier.weight(1f))
            }
        }
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            ElevationTile(nav, vertical, stale, Modifier.weight(1f))
            SunTile(nav, vertical, Modifier.weight(1f))
        }
    }
}

@Composable
private fun ElevationTile(nav: Navigator, vertical: Dp, stale: Boolean, modifier: Modifier) {
    val pressure = nav.pressure?.let { " · ${Geo.pressureText(it, nav.feet)}" } ?: ""
    when (val e = nav.elevation) {
        is ElevationReading.Value -> {
            val (ft, m) = Geo.elevation(e.metres)
            val first = if (nav.feet) ft else m; val second = if (nav.feet) m else ft
            val value = buildAnnotatedString {
                append(first)
                withStyle(SpanStyle(fontSize = 0.79.em, fontWeight = FontWeight.Medium, color = Palette.textMuted)) { append("  $second") }
            }
            val spoken = "Elevation, ${spokenUnits(first)}, ${spokenUnits(second)}, ${if (e.fromGps) "from GPS" else "from terrain data"}"
            Tile("Elevation", value, e.source + pressure, vertical, stale, spoken, modifier)
        }
        is ElevationReading.Pending -> Tile("Elevation", AnnotatedString("—"), e.note, vertical, false, "Elevation, ${e.note}", modifier)
    }
}

/** "9,587 ft" → "9,587 feet", for TalkBack. */
private fun spokenUnits(s: String) = s.removeSuffix(" ft").let { if (it != s) "$it feet" else s.removeSuffix(" m") + " metres" }

@Composable
private fun SunTile(nav: Navigator, vertical: Dp, modifier: Modifier) {
    val phase = nav.moonPhase
    val sun = nav.sunText
    Tile("Sun", AnnotatedString(sun ?: "—"), "Moon", vertical, false,
        "Sun, ${sun?.replace("–", "to") ?: "not known yet"}. Moon, ${com.bradcowdrey.bearings.Sky.moonLine(phase)}", modifier) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Canvas(Modifier.size(12.dp)) { moonGlyph(Offset(size.width / 2, size.height / 2), size.minDimension / 2, phase.phase, 1f) }
            Spacer(Modifier.width(5.dp))
            Text(com.bradcowdrey.bearings.Sky.moonLine(phase), style = text(12f, color = Palette.textMuted).copy(lineHeight = 16.sp),
                maxLines = 1, overflow = TextOverflow.Ellipsis)
        }
    }
}

private fun ago(ms: Long): String {
    val s = maxOf(0L, ms / 1000)
    if (s < 10) return "Just now"
    if (s < 60) return "$s s ago"
    val m = s / 60
    return if (m < 60) "$m min ago" else "${m / 60} hr ago"
}

/**
 * One rounded tile: a small title, the value (shrunk to fit one line), and a detail line, read by
 * TalkBack as one element ([spoken]). [detailContent] replaces the plain detail text.
 */
@Composable
private fun Tile(
    title: String, value: AnnotatedString, detail: String, vertical: Dp, stale: Boolean, spoken: String, modifier: Modifier = Modifier,
    detailContent: (@Composable () -> Unit)? = null,
) {
    // Clipped before the caller's click, so the ripple keeps the rounded corners.
    Column(Modifier.clip(RoundedCornerShape(18.dp)).then(modifier).background(Palette.tile).semantics(mergeDescendants = true) { contentDescription = spoken }
        .padding(horizontal = 14.dp, vertical = vertical)) {
        Text(title, style = text(12f, FontWeight.SemiBold, Palette.textMuted).copy(lineHeight = 16.sp), maxLines = 1)
        FitText(value, text(19f, FontWeight.SemiBold, if (stale) Palette.textMuted else Color.White).copy(lineHeight = 24.sp, fontFeatureSettings = "tnum"))
        if (detailContent != null) detailContent()
        else Text(detail, style = text(12f, color = Palette.textMuted).copy(lineHeight = 16.sp), maxLines = 1, overflow = TextOverflow.Ellipsis)
    }
}

/** One line of text at its size, or smaller (down to 13) until it fits the width; the line's height stays the same. */
@Composable
private fun FitText(value: AnnotatedString, style: TextStyle) {
    val measurer = rememberTextMeasurer()
    BoxWithConstraints(Modifier.fillMaxWidth()) {
        val max = constraints.maxWidth
        val base = style.fontSize.value
        val fitted = remember(value, max, style) {
            var s = base
            while (s > 13f && measurer.measure(value, style.copy(fontSize = s.sp), softWrap = false, maxLines = 1).size.width > max) s -= 1f
            s
        }
        Text(value, style = style.copy(fontSize = fitted.sp), maxLines = 1, softWrap = false, overflow = TextOverflow.Ellipsis)
    }
}

// ---------- About ----------

@Composable
fun AppMark(size: Dp) {
    androidx.compose.foundation.Image(androidx.compose.ui.res.painterResource(com.bradcowdrey.bearings.R.drawable.app_mark), null,
        Modifier.size(size).clip(RoundedCornerShape(size * 0.23f)))
}

@Composable
private fun AboutDialog(night: Boolean, onDismiss: () -> Unit) {
    val uri = LocalUriHandler.current
    androidx.compose.material3.AlertDialog(
        onDismissRequest = onDismiss,
        containerColor = Palette.tile.night(night),
        icon = { AppMark(48.dp) },
        title = { Text("Bearings", style = text(20f, FontWeight.SemiBold, Color.White.night(night))) },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Text("${Brand.TAGLINE} Free, open source, no ads, no tracking.", style = text(14f, color = Palette.textSecondary.night(night)))
                Text("Made by Bradley Cowdrey · bradcowdrey.com ↗", style = text(14f, FontWeight.Medium, Palette.cream.night(night)),
                    modifier = Modifier.heightIn(min = 48.dp).clickable(role = Role.Button) { uri.openUri(Brand.WEBSITE) }.padding(vertical = 14.dp))
                Text("Ground elevation: Open-Meteo (CC BY 4.0), Copernicus DEM GLO-90 © DLR/ESA. Map: OpenFreeMap, © OpenStreetMap contributors, MapLibre. " +
                    "Places: GeoNames (CC BY 4.0). Sun and moon after SunCalc.\n\nVersion ${BuildConfig.VERSION_NAME}",
                    style = text(13f, color = Palette.textMuted.night(night)))
            }
        },
        confirmButton = {
            Text("Done", style = text(15f, FontWeight.SemiBold, Palette.cream.night(night)),
                modifier = Modifier.heightIn(min = 48.dp).clickable(role = Role.Button, onClick = onDismiss).padding(12.dp))
        },
        dismissButton = {
            Text("Source Code", style = text(15f, FontWeight.Medium, Color.White.night(night)),
                modifier = Modifier.heightIn(min = 48.dp).clickable(role = Role.Button) { uri.openUri(Brand.REPOSITORY) }.padding(12.dp))
        },
    )
}
