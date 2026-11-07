package com.bradcowdrey.bearings.ui

import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.view.HapticFeedbackConstants
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
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
import androidx.compose.material.icons.filled.GridOn
import androidx.compose.material.icons.filled.LocationOn
import androidx.compose.material.icons.filled.MoreHoriz
import androidx.compose.material.icons.filled.NightsStay
import androidx.compose.material.icons.filled.Place
import androidx.compose.material.icons.filled.SwapHoriz
import androidx.compose.material.icons.filled.SwapVert
import androidx.compose.material.icons.filled.Terrain
import androidx.compose.material.icons.filled.WbSunny
import androidx.compose.material.icons.filled.WbTwilight
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
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalClipboardManager
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
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
 * Bearings' one screen, top to bottom as in docs/DESIGN.md and docs/LOOK.md (Two Degrees' look: black,
 * white type, a sky card, frosted tiles): the title, the place and time on the sky, the dial with the sun,
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
        surface = Palette.menu.night(night), surfaceContainer = Palette.menu.night(night), onSurface = Color.White.night(night),
    )) {
        BoxWithConstraints(
            Modifier.fillMaxSize()
                // Night mode: the whole screen through a red multiply, so only red light is left.
                .drawWithContent { drawContent(); if (night) drawRect(Palette.nightRed, blendMode = BlendMode.Multiply) }
                .background(Palette.screen)
                .windowInsetsPadding(WindowInsets.safeDrawing),
        ) {
            // Short screens drop the title row and put the ⋯ menu in the sky card, so the dial keeps its room.
            // So does a larger font size when the title row would leave the dial under 140 (as on iPhone).
            val fs = LocalDensity.current.fontScale.coerceIn(1f, 1.4f)
            val titleH = maxOf(Look.titleRow, (40 * fs).dp)
            fun dialFor(compact: Boolean): Dp {
                val gap = if (compact) 8.dp else Look.gap
                val readoutSize = if (compact) 44f else 56f
                val tileTall = if (compact) 8.dp else 12.dp
                // What everything but the dial and the map takes, so the dial gets what's left (at most 36% of
                // the height and 360) and the map keeps at least its minimum. At a larger font size each tile
                // keeps a second detail line. At the top: the title row (48, or the title's line at a larger font
                // size, and 4 below it) and the sky card (padding and two lines; at least the menu's 48 dp target
                // and its padding when compact).
                val skyH = if (compact) maxOf(72.dp, 24.dp + (44 * fs).dp) else Look.skyPadding * 2 + (44 * fs).dp
                val top = (if (compact) 0.dp else titleH + 4.dp) + skyH
                val tileH = (58 * fs).dp + (if (fs > 1.1f) (16 * fs).dp else 0.dp) + tileTall * 2
                val fixed = top + gap + 4.dp + (readoutSize * 1.1f * fs).dp + (18 * fs * (if (fs > 1.1f) 2 else 1)).dp + gap +
                    (if (nav.mark != null && nav.fix != null) 46.dp + gap else 0.dp) + tileH * 2 + Look.tileGap + gap + 12.dp
                val mapMin = if (compact) 96.dp else 120.dp
                return minOf(minOf(maxWidth - 32.dp, maxHeight * 0.36f), minOf(360.dp, maxHeight - fixed - mapMin)).coerceAtLeast(120.dp)
            }
            val compact = maxHeight < Look.compactHeight || dialFor(false) < 140.dp
            val gap = if (compact) 8.dp else Look.gap
            val readoutSize = if (compact) 44f else 56f
            val tileTall = if (compact) 8.dp else 12.dp
            val tileH = (58 * fs).dp + (if (fs > 1.1f) (16 * fs).dp else 0.dp) + tileTall * 2
            val dialSide = dialFor(compact)

            Column(
                Modifier.fillMaxSize().widthIn(max = 520.dp).align(Alignment.TopCenter)
                    .padding(start = Look.margin, end = Look.margin, top = 0.dp, bottom = 12.dp),
            ) {
                val menu: @Composable () -> Unit = { MenuButton(nav, night, onCopy = { copy() }, onAbout = { about = true }) }
                if (!compact) {
                    TitleRow(titleH, menu)
                    Spacer(Modifier.height(4.dp))
                }
                SkyCard(nav, compact, menu)
                Spacer(Modifier.height(gap))
                DialBlock(nav, dialSide)
                Spacer(Modifier.height(4.dp))
                if (nav.compass == CompassStatus.UNAVAILABLE && nav.heading == null) {
                    // No compass: say so where the heading would be, so nothing overlaps the dial.
                    Box(Modifier.fillMaxWidth().height((readoutSize * 1.1f * fs).dp + (18 * fs).dp), contentAlignment = Alignment.Center) {
                        Text("No compass on this device. Your coordinates, elevation and map still work.",
                            style = text(15f, color = white(Op.CAPTION)), textAlign = TextAlign.Center, maxLines = 2,
                            modifier = Modifier.widthIn(max = 300.dp))
                    }
                } else {
                    Readout(nav, readoutSize)
                    // At a larger font size the subline wraps rather than being cut off.
                    Text(subline(nav), style = text(13f, color = white(Op.CAPTION)).copy(lineHeight = 18.sp), textAlign = TextAlign.Center, maxLines = if (fs > 1.1f) 2 else 1,
                        overflow = TextOverflow.Ellipsis, modifier = Modifier.fillMaxWidth().heightIn(min = 18.dp))
                }
                Spacer(Modifier.height(gap))
                val markText = nav.markText
                if (markText != null) {
                    MarkPill(markText, onClear = { nav.clearMark() })
                    Spacer(Modifier.height(gap))
                }
                if (nav.fix == null && nav.access != Access.ALLOWED) {
                    AskForLocation(nav.access == Access.DENIED, onUseLocation, onOpenSettings, Modifier.heightIn(min = tileH * 2 + Look.tileGap))
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
                // A white capsule with black text, as Two Degrees' buttons.
                Text(t, style = text(14f, FontWeight.SemiBold, Color.Black),
                    modifier = Modifier.align(Alignment.BottomCenter).padding(bottom = 28.dp).clip(CircleShape).background(Color.White)
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
    // Light in Two Degrees; Inter has no Light here, so Normal.
    val big = text(size, FontWeight.Normal, if (h == null) white(Op.FAINT) else Color.White)
        .copy(letterSpacing = (-2).sp, lineHeight = (size * 1.1f).sp, fontFeatureSettings = "tnum")
    Row(Modifier.fillMaxWidth().semantics(mergeDescendants = true) {}, horizontalArrangement = Arrangement.Center) {
        Text(if (h == null) "—" else "${Math.round(h) % 360}°", style = big, modifier = Modifier.alignByBaseline())
        Spacer(Modifier.width(10.dp))
        Text(if (h == null) "" else Geo.point(h), style = text(size / 2, FontWeight.Medium, white(Op.CAPTION)),
            modifier = Modifier.alignByBaseline().widthIn(min = (size * 1.1f).dp))
    }
}

private fun subline(nav: Navigator): AnnotatedString = buildAnnotatedString {
    val warn = SpanStyle(color = Palette.notice, fontWeight = FontWeight.SemiBold)
    when {
        nav.compass != CompassStatus.LIVE || nav.heading == null -> append(" ")
        nav.interference -> withStyle(warn) { append("Magnet or metal nearby: move away") }
        (nav.headingAccuracy ?: 0.0) > Navigator.POOR_HEADING_ACCURACY -> withStyle(warn) { append("Low accuracy: move your phone in a figure 8") }
        else -> {
            appendDotted(keepTogether(nav.northLabel))
            nav.headingAccuracy?.let { appendDotted(keepTogether(" · ±${Math.round(it)}°")) }
        }
    }
    // The locked bearing is white, not pink: pink means north and nothing else.
    nav.lockText?.let {
        appendDotted(keepTogether(" · "))
        withStyle(SpanStyle(color = Color.White, fontWeight = FontWeight.SemiBold)) { append(keepTogether(it)) }
    }
}

/** Appends [s] with its dots (·) fainter than the words around them. */
private fun AnnotatedString.Builder.appendDotted(s: String) {
    for (ch in s) {
        if (ch == '·') withStyle(SpanStyle(color = white(Op.FAINT))) { append(ch) } else append(ch)
    }
}

/**
 * For a larger font size, where lines wrap: numbers stay with their units ("21.29 inHg", "turn 12° right")
 * and a " · " never starts a line ("Last Quarter · 53%"), by turning those spaces into no-break spaces
 * (U+00A0). The space after a dot stays, so that's where a line breaks first. Spaces between words
 * ("Waxing Crescent") stay too, so a long name can still wrap in a narrow tile instead of mid-word.
 */
private fun keepTogether(s: String): String {
    val out = StringBuilder(s.length)
    for (i in s.indices) {
        val c = s[i]
        if (c != ' ') { out.append(c); continue }
        val before = s.getOrNull(i - 1)
        val after = s.getOrNull(i + 1)
        val glue = before != '·' && (after == '·' || after == '±' || before == '°' ||
            before?.isDigit() == true || after?.isDigit() == true)
        out.append(if (glue) '\u00A0' else ' ')
    }
    return out.toString()
}

// ---------- The title, the sky card and the menu ----------

/** "Bearings" large on the left (a heading for TalkBack), the ⋯ menu on the right, as Two Degrees' title. */
@Composable
private fun TitleRow(height: Dp, menu: @Composable () -> Unit) {
    Row(Modifier.fillMaxWidth().heightIn(min = height), verticalAlignment = Alignment.CenterVertically) {
        Text(Brand.APP_NAME, style = text(Look.TITLE_SIZE, FontWeight.SemiBold).copy(letterSpacing = 0.4.sp, lineHeight = 40.sp), maxLines = 1,
            overflow = TextOverflow.Ellipsis, modifier = Modifier.weight(1f).semantics { heading() })
        menu()
    }
}

/**
 * The place and the date and time on the sky where you are (blue by day, navy at night, following the sun's
 * altitude), with the sky's symbol in the corner, or the ⋯ menu on short screens. Read as one heading.
 */
@Composable
private fun SkyCard(nav: Navigator, compact: Boolean, menu: @Composable () -> Unit) {
    val sun = nav.fix?.let { com.bradcowdrey.bearings.Sky.sunPosition(nav.now.toDouble(), it.latitude, it.longitude) }
    Row(
        Modifier.fillMaxWidth().heightIn(min = if (compact) 72.dp else 0.dp).skyCard(sun?.altitude)
            .padding(if (compact) 12.dp else Look.skyPadding),
        verticalAlignment = if (compact) Alignment.CenterVertically else Alignment.Top,
    ) {
        Column(Modifier.weight(1f).semantics(mergeDescendants = true) { heading() }) {
            Text(nav.title, style = text(20f, FontWeight.SemiBold).copy(letterSpacing = (-0.3).sp, lineHeight = 24.sp), maxLines = 1,
                overflow = TextOverflow.Ellipsis)
            Spacer(Modifier.height(2.dp))
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(nav.dateTimeText, style = text(14f, FontWeight.Medium, white(Op.BODY)).copy(lineHeight = 18.sp, fontFeatureSettings = "tnum"),
                    maxLines = 1, overflow = TextOverflow.Ellipsis, modifier = Modifier.weight(1f, fill = false))
                if (nav.sample) {
                    Spacer(Modifier.width(8.dp))
                    Text("Sample", style = text(11f, FontWeight.SemiBold, Color.Black),
                        modifier = Modifier.clip(CircleShape).background(Palette.notice).padding(horizontal = 6.dp, vertical = 1.dp))
                }
            }
        }
        if (compact) {
            Spacer(Modifier.width(4.dp))
            menu()
        } else {
            Spacer(Modifier.width(8.dp))
            // Decorative: TalkBack hears the place and time.
            Icon(skyIcon(sun?.altitude, sun?.azimuth), null, tint = white(Op.BODY), modifier = Modifier.size(20.dp))
        }
    }
}

/** The sun by day, sunrise or sunset in twilight, the moon at night, a pin before a fix (SkyTone.phase). */
private fun skyIcon(altitude: Double?, azimuth: Double?): ImageVector = when (SkyTone.phase(altitude, azimuth)) {
    SkyTone.Phase.DAY -> Icons.Filled.WbSunny
    SkyTone.Phase.TWILIGHT_MORNING, SkyTone.Phase.TWILIGHT_EVENING -> Icons.Filled.WbTwilight
    SkyTone.Phase.NIGHT -> Icons.Filled.NightsStay
    SkyTone.Phase.UNKNOWN -> Icons.Filled.LocationOn
}

/** The ⋯ menu: a faint white 36 dp circle in a 48 dp touch target, and everything Bearings can do or change. */
@Composable
private fun MenuButton(nav: Navigator, night: Boolean, onCopy: () -> Unit, onAbout: () -> Unit) {
    var open by remember { mutableStateOf(false) }
    val context = LocalContext.current
    val uri = LocalUriHandler.current
    fun share(text: String) {
        val send = Intent(Intent.ACTION_SEND).setType("text/plain").putExtra(Intent.EXTRA_TEXT, text)
        context.startActivity(Intent.createChooser(send, null))
    }
    Box {
        Box(
            Modifier.size(48.dp).clip(CircleShape).clickable(role = Role.Button, onClickLabel = "Open the menu") { open = true }
                .semantics { contentDescription = "Settings and more" },
            contentAlignment = Alignment.Center,
        ) {
            Box(Modifier.size(36.dp).clip(CircleShape).background(Palette.chipOff), contentAlignment = Alignment.Center) {
                Icon(Icons.Filled.MoreHoriz, null, tint = Color.White, modifier = Modifier.size(20.dp))
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
            HorizontalDivider(color = white(Op.STROKE).night(night))
            Check("Night Mode", night, night) { nav.setNight(!night); open = false }
            HorizontalDivider(color = white(Op.STROKE).night(night))
            if (nav.mark == null) Item("Mark This Spot", night, hasFix) { nav.markHere(); open = false }
            else Item("Clear Marked Spot", night) { nav.clearMark(); open = false }
            Item(if (nav.lock == null) "Lock This Bearing" else "Clear Locked Bearing", night, nav.heading != null) { nav.toggleLock(); open = false }
            Item("Copy Coordinates", night, hasFix) { onCopy(); open = false }
            Item("Share My Location…", night, hasFix) { nav.shareLocationText?.let(::share); open = false }
            Item("Share Bearings…", night) { share("${Brand.SHARE_MESSAGE} ${Brand.PRODUCT_PAGE}"); open = false }
            HorizontalDivider(color = white(Op.STROKE).night(night))
            Item("Terms & Privacy", night) { uri.openUri(Brand.LEGAL); open = false }
            Item("About Bearings", night) { onAbout(); open = false }
        }
    }
}

@Composable private fun MenuSection(title: String, night: Boolean) =
    Text(title.uppercase(), style = text(11f, FontWeight.SemiBold, white(Op.FAINT).night(night)),
        modifier = Modifier.padding(start = 16.dp, top = 10.dp, bottom = 2.dp))

@Composable private fun Check(title: String, on: Boolean, night: Boolean, onClick: () -> Unit) =
    DropdownMenuItem(text = { Text(title, style = text(15f, color = Color.White.night(night))) }, onClick = onClick,
        leadingIcon = { Text(if (on) "✓" else "", style = text(15f, color = Color.White.night(night)), modifier = Modifier.widthIn(min = 14.dp)) })

@Composable private fun Item(title: String, night: Boolean, enabled: Boolean = true, onClick: () -> Unit) =
    DropdownMenuItem(text = { Text(title, style = text(15f, color = (if (enabled) Color.White else white(Op.FAINT)).night(night))) },
        onClick = onClick, enabled = enabled, leadingIcon = { Spacer(Modifier.widthIn(min = 14.dp)) })

// ---------- The marked spot ----------

/** A frosted capsule: the pin, "Marked spot" and its distance and direction, and ✕ to clear it. */
@Composable
private fun MarkPill(label: String, onClear: () -> Unit) {
    Row(
        Modifier.fillMaxWidth().heightIn(min = 46.dp).frostedTile(CircleShape),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Spacer(Modifier.width(16.dp))
        Icon(Icons.Filled.Place, null, tint = Color.White, modifier = Modifier.size(16.dp))
        Spacer(Modifier.width(6.dp))
        Text(
            buildAnnotatedString {
                withStyle(SpanStyle(color = Color.White, fontWeight = FontWeight.SemiBold)) { append("Marked spot") }
                withStyle(SpanStyle(color = white(Op.SUB))) { append(" · $label") }
            },
            style = text(14f).copy(fontFeatureSettings = "tnum"), maxLines = 1, overflow = TextOverflow.Ellipsis,
            modifier = Modifier.weight(1f),
        )
        Box(
            Modifier.size(48.dp, 44.dp).clip(CircleShape).clickable(role = Role.Button, onClick = onClear)
                .semantics { contentDescription = "Clear the marked spot" },
            contentAlignment = Alignment.Center,
        ) { Icon(Icons.Filled.Close, null, tint = white(Op.CAPTION), modifier = Modifier.size(16.dp)) }
    }
}

// ---------- The tiles ----------

@Composable
private fun AskForLocation(denied: Boolean, onUseLocation: () -> Unit, onOpenSettings: () -> Unit, modifier: Modifier) {
    Column(modifier.fillMaxWidth().frostedTile().padding(horizontal = Look.padding, vertical = Look.paddingV),
        verticalArrangement = Arrangement.spacedBy(12.dp, Alignment.CenterVertically)) {
        Text(if (denied) "Location is off for Bearings. Allow it in Settings to see where you are, your coordinates, elevation and map."
            else "Allow your location to see where you are, your latitude, longitude, elevation and map. It stays on this phone.",
            style = text(13f, color = white(Op.BODY)))
        // A compact white capsule with black text, in a 48 dp touch target.
        Box(
            Modifier.heightIn(min = 48.dp).clip(CircleShape)
                .clickable(role = Role.Button) { if (denied) onOpenSettings() else onUseLocation() },
            contentAlignment = Alignment.Center,
        ) {
            Text(if (denied) "Open Settings" else "Use My Location", style = text(14f, FontWeight.SemiBold, Color.Black),
                modifier = Modifier.clip(CircleShape).background(Color.White).padding(horizontal = 14.dp, vertical = 8.dp))
        }
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
    Column(verticalArrangement = Arrangement.spacedBy(Look.tileGap)) {
        when (val f = fix?.let { Geo.format(nav.format, it.latitude, it.longitude) }) {
            is Geo.Formatted.Single -> Tile(nav.format.title, Icons.Filled.GridOn, AnnotatedString(f.text), accuracy ?: " ", vertical, stale,
                "${nav.format.title}, ${f.text}. Tap to change the format, touch and hold to copy", Modifier.fillMaxWidth().then(tap))
            is Geo.Formatted.Pair -> Row(horizontalArrangement = Arrangement.spacedBy(Look.tileGap)) {
                Tile("Latitude", Icons.Filled.SwapVert, AnnotatedString(f.lat), accuracy ?: " ", vertical, stale, "Latitude, ${f.lat}", Modifier.weight(1f).then(tap))
                Tile("Longitude", Icons.Filled.SwapHoriz, AnnotatedString(f.lon), nav.format.title, vertical, stale, "Longitude, ${f.lon}", Modifier.weight(1f).then(tap))
            }
            null -> Row(horizontalArrangement = Arrangement.spacedBy(Look.tileGap)) {
                Tile("Latitude", Icons.Filled.SwapVert, AnnotatedString("—"), if (nav.locating) "Finding you…" else " ", vertical, false,
                    "Latitude, not known yet", Modifier.weight(1f))
                Tile("Longitude", Icons.Filled.SwapHoriz, AnnotatedString("—"), nav.format.title, vertical, false, "Longitude, not known yet", Modifier.weight(1f))
            }
        }
        Row(horizontalArrangement = Arrangement.spacedBy(Look.tileGap)) {
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
                // The second unit 14 against the value's 20.
                withStyle(SpanStyle(fontSize = 0.7.em, fontWeight = FontWeight.Medium, color = white(Op.CAPTION))) { append("  $second") }
            }
            val spoken = "Elevation, ${spokenUnits(first)}, ${spokenUnits(second)}, ${if (e.fromGps) "from GPS" else "from terrain data"}"
            Tile("Elevation", Icons.Filled.Terrain, value, e.source + pressure, vertical, stale, spoken, modifier)
        }
        is ElevationReading.Pending -> Tile("Elevation", Icons.Filled.Terrain, AnnotatedString("—"), e.note, vertical, false, "Elevation, ${e.note}", modifier)
    }
}

/** "9,587 ft" → "9,587 feet", for TalkBack. */
private fun spokenUnits(s: String) = s.removeSuffix(" ft").let { if (it != s) "$it feet" else s.removeSuffix(" m") + " metres" }

@Composable
private fun SunTile(nav: Navigator, vertical: Dp, modifier: Modifier) {
    val phase = nav.moonPhase
    val sun = nav.sunText
    Tile("Sun", Icons.Filled.WbSunny, AnnotatedString(sun ?: "—"), "Moon", vertical, false,
        "Sun, ${sun?.replace("–", "to") ?: "not known yet"}. Moon, ${com.bradcowdrey.bearings.Sky.moonLine(phase)}", modifier) {
        // The same detail lines as the other tiles, with the glyph centred on the first line.
        val lines = detailLines()
        Row(verticalAlignment = Alignment.Top) {
            Box(Modifier.height(with(LocalDensity.current) { 16.sp.toDp() }), contentAlignment = Alignment.Center) {
                Canvas(Modifier.size(12.dp)) { moonGlyph(Offset(size.width / 2, size.height / 2), size.minDimension / 2, phase.phase, 1f) }
            }
            Spacer(Modifier.width(5.dp))
            Text(keepTogether(com.bradcowdrey.bearings.Sky.moonLine(phase)), style = text(12f, color = white(Op.CAPTION)).copy(lineHeight = 16.sp),
                minLines = lines, maxLines = lines, overflow = TextOverflow.Ellipsis)
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
 * One frosted tile, as Two Degrees' cards: a caption in capitals with its icon, the value (shrunk to fit
 * one line), and a detail line, read by TalkBack as one element ([spoken]; the caption is hidden from it).
 * [detailContent] replaces the plain detail text.
 */
@Composable
private fun Tile(
    title: String, icon: ImageVector, value: AnnotatedString, detail: String, vertical: Dp, stale: Boolean, spoken: String,
    modifier: Modifier = Modifier, detailContent: (@Composable () -> Unit)? = null,
) {
    // Clipped before the caller's click, so the ripple keeps the rounded corners.
    Column(Modifier.clip(Look.shape).then(modifier).frostedTile().semantics(mergeDescendants = true) { contentDescription = spoken }
        .padding(horizontal = Look.padding, vertical = vertical)) {
        CardCaption(title, icon)
        Spacer(Modifier.height(2.dp))
        FitText(value, text(Look.VALUE_SIZE, FontWeight.Medium, if (stale) white(Op.CAPTION) else Color.White)
            .copy(lineHeight = 24.sp, fontFeatureSettings = "tnum"))
        if (detailContent != null) {
            detailContent()
        } else {
            // At a larger font size the detail wraps rather than being cut off, as on the iPhone. Two lines
            // are kept for it even when it needs one, so every tile is the same height and the two tiles in
            // a row always match. (FitText measures with BoxWithConstraints, a SubcomposeLayout, so the row
            // can't size its tiles with IntrinsicSize.Min; that would throw at runtime.)
            val lines = detailLines()
            Text(keepTogether(detail), style = text(12f, color = white(Op.CAPTION)).copy(lineHeight = 16.sp),
                minLines = lines, maxLines = lines, overflow = TextOverflow.Ellipsis)
        }
    }
}

/** The detail lines in every tile: one, or two at a larger font size. */
@Composable
private fun detailLines(): Int = if (LocalDensity.current.fontScale > 1.1f) 2 else 1

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
        containerColor = Palette.menu.night(night),
        icon = { AppMark(48.dp) },
        title = { Text("Bearings", style = text(20f, FontWeight.SemiBold, Color.White.night(night))) },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Text("${Brand.TAGLINE} Free, open source, no ads, no tracking.", style = text(14f, color = Color.White.night(night)))
                Text("Made by Bradley Cowdrey · bradcowdrey.com ↗", style = text(14f, FontWeight.Medium, Color.White.night(night)),
                    modifier = Modifier.heightIn(min = 48.dp).clickable(role = Role.Button) { uri.openUri(Brand.WEBSITE) }.padding(vertical = 14.dp))
                Text("Ground elevation: Open-Meteo (CC BY 4.0), Copernicus DEM GLO-90 © DLR/ESA. Map: OpenFreeMap, © OpenStreetMap contributors, MapLibre. " +
                    "Places: GeoNames (CC BY 4.0). Sun and moon after SunCalc.\n\nVersion ${BuildConfig.VERSION_NAME}",
                    style = text(13f, color = white(Op.SUB).night(night)))
            }
        },
        confirmButton = {
            Text("Done", style = text(15f, FontWeight.SemiBold, Color.White.night(night)),
                modifier = Modifier.heightIn(min = 48.dp).clickable(role = Role.Button, onClick = onDismiss).padding(12.dp))
        },
        dismissButton = {
            Text("Source Code", style = text(15f, FontWeight.Medium, Color.White.night(night)),
                modifier = Modifier.heightIn(min = 48.dp).clickable(role = Role.Button) { uri.openUri(Brand.REPOSITORY) }.padding(12.dp))
        },
    )
}
