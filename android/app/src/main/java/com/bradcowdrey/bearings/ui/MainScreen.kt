package com.bradcowdrey.bearings.ui

import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.view.HapticFeedbackConstants
import androidx.compose.animation.core.AnimationSpec
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.animateDpAsState
import androidx.compose.animation.core.snap
import androidx.compose.animation.core.spring
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.ScrollState
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.IntrinsicSize
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.requiredSize
import androidx.compose.foundation.layout.safeDrawing
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
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
import androidx.compose.runtime.SideEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.BlendMode
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.layout.positionInRoot
import androidx.compose.ui.platform.LocalClipboardManager
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.semantics.CustomAccessibilityAction
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.customActions
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
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
import kotlinx.coroutines.launch
import java.util.Locale

/**
 * Bearings' one screen (docs/LAYOUTS.md, in docs/LOOK.md's look: black, white type, a sky card, frosted
 * tiles). Two parts: the head, which never scrolls (the title row when it fits, the sky card or bar, the dial
 * with the sun, moon, marked spot and locked bearing, the heading, the subline and the spot line), and
 * Details, which scrolls under it (the summary strip, the map, the four tiles). The dial is sized first by
 * [LayoutPlan] for the chosen layout and is never under 40% of the screen height on a portrait phone. Wide
 * windows and phones in landscape put Details in a column beside the dial.
 */
@Composable
fun MainScreen(nav: Navigator, onUseLocation: () -> Unit, onOpenSettings: () -> Unit) {
    var toast by remember { mutableStateOf<String?>(null) }
    var about by remember { mutableStateOf(false) }
    val clipboard = LocalClipboardManager.current
    val view = LocalView.current
    val context = LocalContext.current
    val uri = LocalUriHandler.current
    // Android 13 and later show their own notice when something is copied.
    val copy: () -> Unit = {
        val t = nav.copyText
        if (t != null) {
            clipboard.setText(AnnotatedString(t))
            if (Build.VERSION.SDK_INT < 33) toast = "Copied"
        }
    }
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
    // Animations off (Settings → Accessibility → Remove animations, or CI): the layout changes at once.
    val reduceMotion = remember {
        Settings.Global.getFloat(context.contentResolver, Settings.Global.ANIMATOR_DURATION_SCALE, 1f) == 0f
    }

    MaterialTheme(colorScheme = darkColorScheme(
        surface = Palette.menu.night(night), surfaceContainer = Palette.menu.night(night), onSurface = Color.White.night(night),
    )) {
        BoxWithConstraints(
            Modifier.fillMaxSize()
                // Night mode: the whole screen through a red multiply, so only red light is left.
                .drawWithContent { drawContent(); if (night) drawRect(Palette.nightRed, blendMode = BlendMode.Multiply) }
                .background(Palette.screen),
        ) {
            // H: the whole screen, system bars included (the app draws edge to edge).
            val fullHeight = maxHeight
            BoxWithConstraints(Modifier.fillMaxSize().windowInsetsPadding(WindowInsets.safeDrawing)) {
                val fontScale = LocalDensity.current.fontScale
                val k = fontScale.coerceIn(1f, LayoutPlan.MAX_K)
                val bigText = fontScale >= 1.5f
                val w = maxWidth.value; val s = maxHeight.value; val h = fullHeight.value
                val plan = LayoutPlan.plan(
                    w, h, s, nav.layout, k, bigText, hasSpot = nav.markText != null,
                    isLandscapePhone = w > h && s < LayoutPlan.LANDSCAPE_PHONE,
                )
                SideEffect { LayoutPlan.last = plan; LayoutPlan.lastHeight = h }
                val spec: AnimationSpec<Dp> = if (reduceMotion) snap<Dp>() else spring<Dp>(stiffness = Spring.StiffnessMediumLow)
                val dial by animateDpAsState(plan.dial.dp, spec, label = "dial")
                val gap = plan.gap.dp

                val details = rememberScrollState()
                val whole = rememberScrollState()
                // Changing the layout scrolls Details back to the top.
                LaunchedEffect(nav.layout) { details.scrollTo(0); whole.scrollTo(0) }
                val scope = rememberCoroutineScope()
                // Where the tiles and the scrolling area are on the screen, for "scroll to the tiles".
                val at = remember { FloatArray(2) }
                val toTiles: () -> Unit = {
                    val state = if (plan.scrollsWhole && !plan.twoPane) whole else details
                    scope.launch { state.animateScrollTo((state.value + at[0] - at[1]).toInt().coerceAtLeast(0)) }
                }
                val tilesMarker = Modifier.onGloballyPositioned { at[0] = it.positionInRoot().y }
                val viewportMarker = Modifier.onGloballyPositioned { at[1] = it.positionInRoot().y }

                val menu: @Composable () -> Unit = {
                    MenuButton(nav, night, onCopy = { copy() }, onAbout = { about = true }, onOpenMap = openMap)
                }
                val head: @Composable () -> Unit = {
                    Head(nav, plan, dial, k, night)
                }
                val detailsContent: @Composable (Dp) -> Unit = { mapHeight ->
                    Details(nav, plan, mapHeight, bigText, tilesMarker, onCopy = { copy() }, onShowTiles = toTiles,
                        onOpenMap = openMap, onUseLocation = onUseLocation, onOpenSettings = onOpenSettings)
                }

                if (plan.twoPane) {
                    Row(Modifier.fillMaxSize()) {
                        // The leading pane: the head, centred.
                        Column(
                            Modifier.weight(1f).fillMaxHeight()
                                .then(if (plan.scrollsWhole) Modifier.verticalScroll(whole) else Modifier)
                                .padding(start = Look.margin, end = Look.margin, top = LayoutPlan.TOP.dp, bottom = LayoutPlan.BOTTOM.dp),
                            verticalArrangement = Arrangement.Center,
                        ) {
                            if (plan.header == Header.BAR) SkyBar(nav, null) else SkyCard(nav, null)
                            Spacer(Modifier.height(gap))
                            head()
                        }
                        // The trailing column: the title row with ⋯, then Details.
                        Column(
                            Modifier.width(plan.trailingWidth.dp).fillMaxHeight()
                                .padding(end = Look.margin, top = LayoutPlan.TOP.dp, bottom = LayoutPlan.BOTTOM.dp),
                        ) {
                            TitleRow(LayoutPlan.titleHeight(k).dp, menu)
                            Spacer(Modifier.height(LayoutPlan.TITLE_SPACE.dp))
                            DetailsScroll(details, Modifier.weight(1f).fillMaxWidth().then(viewportMarker)) {
                                detailsContent(LayoutPlan.MAP.dp)
                            }
                        }
                    }
                } else {
                    Column(
                        Modifier.fillMaxHeight().widthIn(max = LayoutPlan.MAX_COLUMN.dp).fillMaxWidth().align(Alignment.TopCenter)
                            .then(if (plan.scrollsWhole) Modifier.then(viewportMarker).verticalScroll(whole) else Modifier)
                            .padding(top = LayoutPlan.TOP.dp, bottom = LayoutPlan.BOTTOM.dp),
                    ) {
                        when (plan.header) {
                            Header.TITLE_ROW_AND_CARD -> {
                                TitleRow(LayoutPlan.titleHeight(k).dp, menu, Modifier.padding(horizontal = Look.margin))
                                Spacer(Modifier.height(LayoutPlan.TITLE_SPACE.dp))
                                SkyCard(nav, null, Modifier.padding(horizontal = Look.margin))
                            }
                            Header.CARD -> SkyCard(nav, menu, Modifier.padding(horizontal = Look.margin))
                            Header.BAR -> SkyBar(nav, menu, Modifier.padding(horizontal = Look.margin))
                        }
                        Spacer(Modifier.height(gap))
                        head()
                        if (plan.scrollsWhole) {
                            Column(Modifier.padding(horizontal = Look.margin)) { detailsContent(LayoutPlan.MAP.dp) }
                        } else {
                            BoxWithConstraints(Modifier.weight(1f).fillMaxWidth().then(viewportMarker)) {
                                // Small: the map fills what's left of the first screen under the strip (at least 96),
                                // or goes below the fold at 240.
                                val left = maxHeight - LayoutPlan.stripHeight(k).dp - gap
                                val mapHeight = if (plan.mapOnFirstScreen && left >= LayoutPlan.MAP_MIN.dp) left else LayoutPlan.MAP.dp
                                DetailsScroll(details, Modifier.fillMaxSize().padding(horizontal = Look.margin)) {
                                    detailsContent(mapHeight)
                                }
                            }
                        }
                    }
                }
            }
            toast?.let { t ->
                LaunchedEffect(t) { delay(1200); toast = null }
                // A white capsule with black text, as Two Degrees' buttons.
                Text(t, style = text(14f, FontWeight.SemiBold, Color.Black),
                    modifier = Modifier.align(Alignment.BottomCenter).windowInsetsPadding(WindowInsets.safeDrawing).padding(bottom = 28.dp)
                        .clip(CircleShape).background(Color.White)
                        .padding(horizontal = 16.dp, vertical = 9.dp).semantics { liveRegion = LiveRegionMode.Polite })
            }
        }
        if (about) AboutDialog(night) { about = false }
    }
}

/** Details' scrolling area, with a 16 dp fade to black at the bottom while there's more below. */
@Composable
private fun DetailsScroll(state: ScrollState, modifier: Modifier, content: @Composable () -> Unit) {
    Box(modifier) {
        Column(Modifier.fillMaxSize().verticalScroll(state)) { content() }
        if (state.canScrollForward) {
            Box(Modifier.align(Alignment.BottomCenter).fillMaxWidth().height(16.dp)
                .background(Brush.verticalGradient(listOf(Color.Transparent, Palette.screen))))
        }
    }
}

/**
 * Details, top to bottom: the summary strip (or the request for location), the map, and the four tiles under
 * a "Details" heading. [tilesMarker] reports where the tiles are, so the strip's Elevation and Sun cells can
 * scroll to them.
 */
@Composable
private fun Details(
    nav: Navigator, plan: Plan, mapHeight: Dp, bigText: Boolean, tilesMarker: Modifier, onCopy: () -> Unit,
    onShowTiles: () -> Unit, onOpenMap: (Fix) -> Unit, onUseLocation: () -> Unit, onOpenSettings: () -> Unit,
) {
    val gap = plan.gap.dp
    val tileTall = if (plan.gap < LayoutPlan.GAP) 8.dp else 12.dp
    if (nav.fix == null && nav.access != Access.ALLOWED) {
        AskForLocation(nav.access == Access.DENIED, onUseLocation, onOpenSettings, Modifier)
    } else {
        SummaryStrip(nav, vertical = bigText, onCopy = onCopy, onShowTiles = onShowTiles)
    }
    Spacer(Modifier.height(gap))
    MapSnippet(
        nav.fix, nav.trueHeading, nav.followHeading, nav.night,
        speed = nav.speed?.let { Geo.speedText(it, nav.feet) },
        onToggleFollow = { nav.setFollowHeading(!nav.followHeading) },
        onOpen = onOpenMap,
        modifier = Modifier.fillMaxWidth().height(mapHeight),
    )
    Spacer(Modifier.height(gap))
    Text("Details".uppercase(), style = text(Look.CAPTION_SIZE, FontWeight.SemiBold, white(Op.CAPTION)).copy(letterSpacing = 0.3.sp),
        modifier = tilesMarker.padding(start = 4.dp, bottom = 6.dp).semantics { heading() })
    Tiles(nav, tileTall, onCopy = onCopy)
    Spacer(Modifier.height(gap))
}

// ---------- The head: the dial, the heading, the subline and the marked spot ----------

@Composable
private fun Head(nav: Navigator, plan: Plan, dial: Dp, k: Float, night: Boolean) {
    val gap = plan.gap.dp
    DialBlock(nav, dial, plan.layout.e.dp)
    Spacer(Modifier.height(4.dp))
    if (nav.compass == CompassStatus.UNAVAILABLE && nav.heading == null) {
        // No compass: say so where the heading would be, so nothing overlaps the dial.
        Box(Modifier.fillMaxWidth().padding(horizontal = Look.margin)
            .height(LayoutPlan.readoutHeight(plan.headingSize, k).dp + LayoutPlan.sublineHeight(k).dp), contentAlignment = Alignment.Center) {
            Text("No compass on this device. Your coordinates, elevation and map still work.",
                style = text(15f, color = white(Op.CAPTION)), textAlign = TextAlign.Center, maxLines = 2,
                modifier = Modifier.widthIn(max = 300.dp))
        }
    } else {
        // The heading and the subline are read as one.
        Column(Modifier.fillMaxWidth().padding(horizontal = Look.margin).semantics(mergeDescendants = true) {}) {
            Readout(nav, plan.headingSize)
            // At a larger font size the subline wraps rather than being cut off.
            Text(subline(nav), style = text(13f, color = white(Op.CAPTION)).copy(lineHeight = 18.sp), textAlign = TextAlign.Center,
                maxLines = if (k > 1.1f) 2 else 1, overflow = TextOverflow.Ellipsis, modifier = Modifier.fillMaxWidth().heightIn(min = 18.dp))
        }
    }
    Spacer(Modifier.height(gap))
    val markText = nav.markText
    if (markText != null) {
        SpotLine(nav, markText, LayoutPlan.spotHeight(k).dp, night)
        Spacer(Modifier.height(gap))
    }
}

@Composable
private fun DialBlock(nav: Navigator, side: Dp, margin: Dp) {
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
    val value = dialValue(nav, spoken)
    val layout = nav.layout
    val actions = buildList {
        if (nav.heading != null) add(CustomAccessibilityAction(if (nav.lock == null) "Lock Bearing" else "Unlock Bearing") { nav.toggleLock(); true })
        layout.larger?.let { add(CustomAccessibilityAction("Larger Compass") { nav.setLayout(it); true }) }
        layout.smaller?.let { add(CustomAccessibilityAction("Smaller Compass") { nav.setLayout(it); true }) }
    }
    Box(Modifier.fillMaxWidth().padding(horizontal = margin), contentAlignment = Alignment.Center) {
        Box(
            Modifier.size(side).clip(CircleShape)
                .clickable(role = Role.Button, enabled = nav.heading != null,
                    onClickLabel = if (nav.lock == null) "Lock this bearing" else "Clear the locked bearing") { nav.toggleLock() }
                .semantics {
                    contentDescription = "Compass"
                    stateDescription = value
                    liveRegion = LiveRegionMode.Polite
                    customActions = actions
                },
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

/**
 * The dial's spoken value: "Heading 228 degrees, southwest. True north. Sun 245 degrees, up. Moon 110
 * degrees, down. Marked spot 0.4 miles at 245 degrees. Locked 240, turn 12 right." (the parts that apply).
 */
private fun dialValue(nav: Navigator, heading: Double?): String {
    val parts = mutableListOf<String>()
    if (heading == null) parts += "No heading" else {
        parts += "Heading ${Math.round(heading) % 360} degrees, ${Geo.pointName(heading).lowercase()}"
        parts += if (nav.usingTrueNorth) "True north" else "Magnetic north"
    }
    nav.sun?.let { parts += "Sun ${Geo.jsRound(it.azimuth) % 360} degrees, ${if (it.up) "up" else "down"}" }
    nav.moon?.let { parts += "Moon ${Geo.jsRound(it.azimuth) % 360} degrees, ${if (it.up) "up" else "down"}" }
    val b = nav.markBearing; val d = nav.markDistance
    if (b != null && d != null) parts += "Marked spot ${spokenDistance(Geo.distanceText(d, nav.feet))} at ${Geo.jsRound(nav.onCard(b)) % 360} degrees"
    nav.lock?.let { l ->
        val locked = "Locked ${Math.round(l) % 360}"
        parts += if (heading == null) locked else {
            val turn = Math.round(Geo.delta(heading, l)).toInt()
            if (turn == 0) "$locked, on bearing" else "$locked, turn ${kotlin.math.abs(turn)} ${if (turn > 0) "right" else "left"}"
        }
    }
    return parts.joinToString(". ") + "."
}

/** "0.4 mi" → "0.4 miles", for TalkBack. */
private fun spokenDistance(s: String): String = when {
    s.endsWith(" mi") -> s.removeSuffix(" mi") + " miles"
    s.endsWith(" km") -> s.removeSuffix(" km") + " kilometres"
    s.endsWith(" ft") -> s.removeSuffix(" ft") + " feet"
    s.endsWith(" m") -> s.removeSuffix(" m") + " metres"
    else -> s
}

@Composable
private fun Readout(nav: Navigator, baseSize: Float) {
    val h = nav.heading
    // The number follows the font size only up to 1.4 times, like the layout's heights.
    val fs = LocalDensity.current.fontScale
    val size = if (fs > LayoutPlan.MAX_K) baseSize * LayoutPlan.MAX_K / fs else baseSize
    // Tabular figures, so the number doesn't jiggle as it changes.
    // Light in Two Degrees; Inter has no Light here, so Normal.
    val big = text(size, FontWeight.Normal, if (h == null) white(Op.FAINT) else Color.White)
        .copy(letterSpacing = (-2).sp, lineHeight = (size * LayoutPlan.READOUT_LINE).sp, fontFeatureSettings = "tnum")
    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.Center) {
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

// ---------- The title, the sky card or bar, and the menu ----------

/** "Bearings" large on the left (a heading for TalkBack), the ⋯ menu on the right, as Two Degrees' title. */
@Composable
private fun TitleRow(height: Dp, menu: @Composable () -> Unit, modifier: Modifier = Modifier) {
    Row(modifier.fillMaxWidth().heightIn(min = height), verticalAlignment = Alignment.CenterVertically) {
        Text(Brand.APP_NAME, style = text(Look.TITLE_SIZE, FontWeight.SemiBold).copy(letterSpacing = 0.4.sp, lineHeight = 40.sp), maxLines = 1,
            overflow = TextOverflow.Ellipsis, modifier = Modifier.weight(1f).semantics { heading() })
        menu()
    }
}

/**
 * The place and the date and time on the sky where you are (blue by day, navy at night, following the sun's
 * altitude), with the sky's symbol in the corner, or the ⋯ menu ([menu]) when there's no title row. Read as
 * one heading.
 */
@Composable
private fun SkyCard(nav: Navigator, menu: (@Composable () -> Unit)?, modifier: Modifier = Modifier) {
    val sun = nav.fix?.let { com.bradcowdrey.bearings.Sky.sunPosition(nav.now.toDouble(), it.latitude, it.longitude) }
    val withMenu = menu != null
    Row(
        modifier.fillMaxWidth().heightIn(min = if (withMenu) LayoutPlan.SKY_CARD_COMPACT.dp else 0.dp).skyCard(sun?.altitude)
            .padding(if (withMenu) PaddingValues(start = 12.dp, end = 12.dp, top = 10.dp, bottom = 10.dp) else PaddingValues(Look.skyPadding)),
        verticalAlignment = if (withMenu) Alignment.CenterVertically else Alignment.Top,
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
                    SampleBadge()
                }
            }
        }
        if (menu != null) {
            Spacer(Modifier.width(4.dp))
            menu()
        } else {
            Spacer(Modifier.width(8.dp))
            // Decorative: TalkBack hears the place and time.
            Icon(skyIcon(sun?.altitude, sun?.azimuth), null, tint = white(Op.BODY), modifier = Modifier.size(20.dp))
        }
    }
}

/**
 * The sky bar (Extra Large, or a short screen): one line on the same sky, "Crested Butte · Sat 7 Nov · 4:12 PM"
 * (the place is cut short first), the sky's symbol, and the ⋯ menu at the end in a 48 dp target.
 */
@Composable
private fun SkyBar(nav: Navigator, menu: (@Composable () -> Unit)?, modifier: Modifier = Modifier) {
    val sun = nav.fix?.let { com.bradcowdrey.bearings.Sky.sunPosition(nav.now.toDouble(), it.latitude, it.longitude) }
    Row(
        modifier.fillMaxWidth().heightIn(min = LayoutPlan.SKY_BAR.dp).skyCard(sun?.altitude)
            .padding(start = Look.skyPadding, end = if (menu != null) 0.dp else Look.skyPadding),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Row(Modifier.weight(1f).semantics(mergeDescendants = true) { heading() }, verticalAlignment = Alignment.CenterVertically) {
            // One line: the town and the time (the date is in the full sky card), so the place keeps its room.
            Text(nav.title.substringBefore(", "), style = text(15f, FontWeight.SemiBold).copy(lineHeight = 20.sp), maxLines = 1, overflow = TextOverflow.Ellipsis,
                modifier = Modifier.weight(1f, fill = false))
            Text(" · ${nav.dateTimeText.substringAfterLast(" · ")}", style = text(15f).copy(lineHeight = 20.sp, fontFeatureSettings = "tnum"), maxLines = 1, softWrap = false)
            if (nav.sample) {
                Spacer(Modifier.width(6.dp))
                SampleBadge()
            }
        }
        Spacer(Modifier.width(8.dp))
        Icon(skyIcon(sun?.altitude, sun?.azimuth), null, tint = white(Op.BODY), modifier = Modifier.size(17.dp))
        if (menu != null) menu() else Spacer(Modifier.width(0.dp))
    }
}

@Composable
private fun SampleBadge() {
    Text("Sample", style = text(11f, FontWeight.SemiBold, Color.Black), maxLines = 1,
        modifier = Modifier.clip(CircleShape).background(Palette.notice).padding(horizontal = 6.dp, vertical = 1.dp))
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
private fun MenuButton(nav: Navigator, night: Boolean, onCopy: () -> Unit, onAbout: () -> Unit, onOpenMap: (Fix) -> Unit) {
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
            val fix = nav.fix
            val hasFix = fix != null
            MenuSection("Layout", night)
            for (l in Layout.entries) Check(l.title, nav.layout == l, night) { nav.setLayout(l); open = false }
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
            Item("Open in Maps", night, hasFix) { fix?.let(onOpenMap); open = false }
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

/**
 * One line under the heading: the pin, "Marked spot · 0.4 mi · 245° SW", and ✕ to clear it, whose 48 dp
 * target reaches into the gaps above and below. The line opens a small menu: Lock to Spot, Clear Marked Spot.
 */
@Composable
private fun SpotLine(nav: Navigator, label: String, height: Dp, night: Boolean) {
    var open by remember { mutableStateOf(false) }
    val spoken = spotSpoken(nav)
    Box(Modifier.fillMaxWidth().padding(horizontal = Look.margin)) {
        Row(Modifier.fillMaxWidth().height(height), verticalAlignment = Alignment.CenterVertically) {
            Row(
                Modifier.weight(1f).fillMaxHeight().clip(CircleShape)
                    .clickable(role = Role.Button, onClickLabel = "Show what you can do with the marked spot") { open = true }
                    .semantics(mergeDescendants = true) {
                        contentDescription = spoken
                        customActions = listOf(
                            CustomAccessibilityAction("Lock to Spot") { nav.lockToSpot(); true },
                            CustomAccessibilityAction("Clear") { nav.clearMark(); true },
                        )
                    }
                    .padding(start = 4.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Icon(Icons.Filled.Place, null, tint = Color.White, modifier = Modifier.size(16.dp))
                Spacer(Modifier.width(6.dp))
                Text("Marked spot · $label", style = text(15f, FontWeight.Medium).copy(fontFeatureSettings = "tnum"),
                    maxLines = 1, overflow = TextOverflow.Ellipsis)
            }
            // 48 dp to touch, in a line 28 high: it reaches into the gaps above and below.
            Box(Modifier.width(44.dp).fillMaxHeight(), contentAlignment = Alignment.Center) {
                Box(
                    Modifier.requiredSize(48.dp).clip(CircleShape).clickable(role = Role.Button) { nav.clearMark() }
                        .semantics { contentDescription = "Clear the marked spot" },
                    contentAlignment = Alignment.Center,
                ) { Icon(Icons.Filled.Close, null, tint = white(Op.CAPTION), modifier = Modifier.size(16.dp)) }
            }
        }
        DropdownMenu(open, onDismissRequest = { open = false }) {
            Item("Lock to Spot", night, nav.markBearing != null) { nav.lockToSpot(); open = false }
            Item("Clear Marked Spot", night) { nav.clearMark(); open = false }
        }
    }
}

/** "Marked spot, 0.4 miles, 245 degrees southwest" */
private fun spotSpoken(nav: Navigator): String {
    val b = nav.markBearing; val d = nav.markDistance
    if (b == null || d == null) return "Marked spot"
    val card = nav.onCard(b)
    return "Marked spot, ${spokenDistance(Geo.distanceText(d, nav.feet))}, ${Geo.jsRound(card) % 360} degrees ${Geo.pointName(card).lowercase()}"
}

// ---------- The summary strip ----------

/**
 * Tap: the next coordinate format. Touch and hold: copy. The same on the strip's Coordinates cell and on the
 * Latitude and Longitude tiles, with TalkBack actions Next Format and Copy.
 */
@OptIn(ExperimentalFoundationApi::class)
private fun Modifier.coordinateGestures(nav: Navigator, onCopy: () -> Unit): Modifier =
    this.combinedClickable(onClickLabel = "Change the coordinate format", onLongClickLabel = "Copy the coordinates",
        onLongClick = onCopy, onClick = { nav.cycleFormat() })
        .semantics {
            customActions = listOf(
                CustomAccessibilityAction("Next Format") { nav.cycleFormat(); true },
                CustomAccessibilityAction("Copy") { onCopy(); true },
            )
        }

/** The position in the current format, as text (lat over lon), dimmed when the fix is stale. */
@Composable
private fun CoordinateText(nav: Navigator, stale: Boolean, wrap: Boolean) {
    val fix = nav.fix
    val style = text(17f, FontWeight.Medium, if (stale) white(Op.CAPTION) else Color.White).copy(lineHeight = 22.sp, fontFeatureSettings = "tnum")
    val lines = if (wrap) Int.MAX_VALUE else 1
    when (val f = fix?.let { Geo.format(nav.format, it.latitude, it.longitude) }) {
        is Geo.Formatted.Pair -> {
            Text(f.lat, style = style, maxLines = lines, overflow = TextOverflow.Ellipsis)
            Text(f.lon, style = style, maxLines = lines, overflow = TextOverflow.Ellipsis)
        }
        is Geo.Formatted.Single -> Text(f.text, style = style, maxLines = if (wrap) Int.MAX_VALUE else 2, overflow = TextOverflow.Ellipsis)
        null -> Text(if (nav.locating) "Finding you…" else "—", style = style.copy(color = white(Op.CAPTION)), maxLines = 2)
    }
}

/** "39.09898° N" → "39.09898 north", for TalkBack. */
private fun spokenCoordinate(s: String): String {
    val words = mapOf('N' to "north", 'S' to "south", 'E' to "east", 'W' to "west")
    val t = s.replace("°", "")
    val last = t.lastOrNull()
    return if (t.length > 2 && t[t.length - 2] == ' ' && last != null && last in words) t.dropLast(1) + words.getValue(last) else t
}

/** A tick every 15 seconds, for "fix age" and dimming a stale fix. */
@Composable
private fun rememberTick(): Long {
    var tick by remember { mutableLongStateOf(System.currentTimeMillis()) }
    LaunchedEffect(Unit) { while (true) { delay(15_000); tick = System.currentTimeMillis() } }
    return tick
}

/**
 * One frosted row, 64 high, of three cells divided by hairlines: Coordinates (two units wide), Elevation and
 * Sun. At the largest font sizes ([vertical]) the cells stack instead.
 */
@Composable
private fun SummaryStrip(nav: Navigator, vertical: Boolean, onCopy: () -> Unit, onShowTiles: () -> Unit) {
    val fix = nav.fix
    val tick = rememberTick()
    val stale = !nav.sample && fix != null && tick - fix.time > 120_000
    if (vertical) {
        Column(Modifier.fillMaxWidth().frostedTile()) {
            CoordinateCell(nav, stale, true, onCopy, Modifier.fillMaxWidth())
            HorizontalDivider(color = Palette.tileStroke)
            ElevationCell(nav, onShowTiles, Modifier.fillMaxWidth())
            HorizontalDivider(color = Palette.tileStroke)
            SunCell(nav, onShowTiles, Modifier.fillMaxWidth())
        }
    } else {
        Row(Modifier.fillMaxWidth().heightIn(min = LayoutPlan.STRIP.dp).height(IntrinsicSize.Min).frostedTile()) {
            // Coordinates get a little less than half, so "9,587 ft" and "6:36–5:08" fit their cells.
            CoordinateCell(nav, stale, false, onCopy, Modifier.weight(1.6f).fillMaxHeight())
            Hairline()
            ElevationCell(nav, onShowTiles, Modifier.weight(1.2f).fillMaxHeight())
            Hairline()
            SunCell(nav, onShowTiles, Modifier.weight(1.2f).fillMaxHeight())
        }
    }
}

@Composable
private fun Hairline() = Box(Modifier.fillMaxHeight().padding(vertical = 12.dp).width(1.dp).background(Palette.tileStroke))

@Composable
private fun StripCell(spoken: String, modifier: Modifier, content: @Composable () -> Unit) {
    Column(
        modifier.semantics(mergeDescendants = true) { contentDescription = spoken }
            .heightIn(min = LayoutPlan.STRIP.dp).padding(horizontal = 10.dp, vertical = 10.dp),
        verticalArrangement = Arrangement.Center,
    ) { content() }
}

@Composable
private fun CoordinateCell(nav: Navigator, stale: Boolean, wrap: Boolean, onCopy: () -> Unit, modifier: Modifier) {
    val fix = nav.fix
    val spoken = when (val f = fix?.let { Geo.format(nav.format, it.latitude, it.longitude) }) {
        is Geo.Formatted.Pair -> "Coordinates, ${spokenCoordinate(f.lat)}, ${spokenCoordinate(f.lon)}, ${nav.format.title.lowercase()}"
        is Geo.Formatted.Single -> "Coordinates, ${f.text}, ${nav.format.title}"
        null -> "Coordinates, not known yet"
    }
    StripCell(spoken, modifier.then(if (fix != null) Modifier.coordinateGestures(nav, onCopy) else Modifier)) {
        CoordinateText(nav, stale, wrap)
    }
}

@Composable
private fun ElevationCell(nav: Navigator, onShowTiles: () -> Unit, modifier: Modifier) {
    val pressure = nav.pressure?.let { ", pressure ${spokenPressure(Geo.pressureText(it, nav.feet))}" } ?: ""
    val e = nav.elevation
    val spoken = when (e) {
        is ElevationReading.Value -> {
            val (ft, m) = Geo.elevation(e.metres)
            val first = if (nav.feet) ft else m; val second = if (nav.feet) m else ft
            "Elevation, ${spokenUnits(first)}, ${spokenUnits(second)}, ${if (e.fromGps) "from GPS" else "from terrain data"}$pressure"
        }
        is ElevationReading.Pending -> "Elevation, ${e.note.ifBlank { "not known yet" }}"
    }
    StripCell(spoken, modifier.clickable(onClickLabel = "Show the details", onClick = onShowTiles)) {
        when (e) {
            is ElevationReading.Value -> {
                val (ft, m) = Geo.elevation(e.metres)
                Text(if (nav.feet) ft else m, style = text(17f, FontWeight.Medium).copy(lineHeight = 22.sp, fontFeatureSettings = "tnum"),
                    maxLines = 1, overflow = TextOverflow.Ellipsis)
                Text(if (nav.feet) m else ft, style = text(13f, color = white(Op.CAPTION)).copy(lineHeight = 18.sp, fontFeatureSettings = "tnum"),
                    maxLines = 1, overflow = TextOverflow.Ellipsis)
            }
            is ElevationReading.Pending -> {
                Text("—", style = text(17f, FontWeight.Medium, white(Op.CAPTION)).copy(lineHeight = 22.sp))
                Text(e.note, style = text(13f, color = white(Op.CAPTION)).copy(lineHeight = 18.sp), maxLines = 1, overflow = TextOverflow.Ellipsis)
            }
        }
    }
}

/** "1,013 hPa" → "1,013 hectopascals", "21.29 inHg" → "21.29 inches of mercury", for TalkBack. */
private fun spokenPressure(s: String): String =
    s.replace(" hPa", " hectopascals").replace(" inHg", " inches of mercury")

@Composable
private fun SunCell(nav: Navigator, onShowTiles: () -> Unit, modifier: Modifier) {
    val phase = nav.moonPhase
    val fix = nav.fix
    val times = fix?.let { com.bradcowdrey.bearings.Sky.sunTimes(nav.now.toDouble(), it.latitude, it.longitude) }
    val rise = times?.sunrise; val set = times?.sunset
    val moon = "moon ${phase.name.lowercase()}, ${Geo.jsRound(phase.fraction * 100)} percent"
    val spoken = when {
        rise != null && set != null && times?.polar == null -> "Sun, rises ${nav.clock(rise.toLong())}, sets ${nav.clock(set.toLong())}, $moon"
        nav.sunText != null -> "Sun, ${nav.sunText?.removePrefix("Sun ")}, $moon"
        else -> "Sun, not known yet, $moon"
    }
    // "6:42–5:01" without AM or PM; the polar day or night in two words.
    val line = nav.sunText?.let { it.replace(" – ", "–").removePrefix("Sun ").replaceFirstChar { c -> c.uppercase() } } ?: "—"
    StripCell(spoken, modifier.clickable(onClickLabel = "Show the details", onClick = onShowTiles)) {
        Text(line, style = text(15f, FontWeight.Medium, if (nav.sunText == null) white(Op.CAPTION) else Color.White)
            .copy(lineHeight = 22.sp, fontFeatureSettings = "tnum"), maxLines = 1, overflow = TextOverflow.Ellipsis)
        Row(verticalAlignment = Alignment.CenterVertically) {
            Canvas(Modifier.size(12.dp)) { moonGlyph(Offset(size.width / 2, size.height / 2), size.minDimension / 2, phase.phase, 1f) }
            Spacer(Modifier.width(5.dp))
            Text("${Geo.jsRound(phase.fraction * 100)}%", style = text(13f, color = white(Op.CAPTION)).copy(lineHeight = 18.sp, fontFeatureSettings = "tnum"),
                maxLines = 1)
        }
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
    val tick = rememberTick()
    val stale = !nav.sample && fix != null && tick - fix.time > 120_000
    // The same tap and touch-and-hold as the strip's Coordinates cell.
    val tap = Modifier.coordinateGestures(nav, onCopy)
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
