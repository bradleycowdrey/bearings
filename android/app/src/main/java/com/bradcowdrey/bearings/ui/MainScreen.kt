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
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
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
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Dashboard
import androidx.compose.material.icons.filled.Explore
import androidx.compose.material.icons.filled.LocationOn
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.Map
import androidx.compose.material.icons.filled.MoreHoriz
import androidx.compose.material.icons.filled.NightsStay
import androidx.compose.material.icons.filled.Place
import androidx.compose.material.icons.filled.WbSunny
import androidx.compose.material.icons.filled.WbTwilight
import androidx.compose.material.icons.filled.ZoomOutMap
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.SideEffect
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
import androidx.compose.ui.layout.Layout as ComposeLayout
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
import androidx.compose.ui.semantics.paneTitle
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
import androidx.compose.ui.unit.Constraints
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.bradcowdrey.bearings.Access
import com.bradcowdrey.bearings.Brand
import com.bradcowdrey.bearings.BuildConfig
import com.bradcowdrey.bearings.CompassStatus
import com.bradcowdrey.bearings.ElevationReading
import com.bradcowdrey.bearings.Fix
import com.bradcowdrey.bearings.Geo
import com.bradcowdrey.bearings.Navigator
import com.bradcowdrey.bearings.Sky
import kotlinx.coroutines.delay
import java.util.Locale
import kotlin.math.abs
import kotlin.math.max

/**
 * Bearings' one screen, the "instrument panel" (docs/REFINE.md §3, in docs/LOOK.md's look: black, white type,
 * the sky, frosted tiles). Top to bottom: the header bar (place, date and time, the ⋯ menu), the dial, the
 * readout, the status line and lock chip, the marked spot's row, the labelled tile grid (Position, Elevation,
 * Sun, Moon, Map) and, where it fits whole, the map card. [LayoutPlan] sizes everything bottom-up for the
 * chosen layout so nothing is cut and nothing is left empty. Wide windows and phones in landscape use two
 * panes; accessibility text sizes scroll as one list. [showMapSheet] opens the map sheet at launch (CI).
 */
@Composable
fun MainScreen(nav: Navigator, onUseLocation: () -> Unit, onOpenSettings: () -> Unit, showMapSheet: Boolean = false) {
    var toast by remember { mutableStateOf<String?>(null) }
    var about by remember { mutableStateOf(false) }
    var mapSheet by remember { mutableStateOf(showMapSheet) }
    var detailsSheet by remember { mutableStateOf(false) }
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
    val actions = Actions(
        copy = copy, details = { detailsSheet = true }, map = { mapSheet = true }, openMap = openMap,
        useLocation = onUseLocation, openSettings = onOpenSettings, about = { about = true },
    )
    // A light tick as the heading passes N, E, S and W (the phone's own haptics setting applies).
    LaunchedEffect(nav.ticks) { if (nav.ticks > 0) view.performHapticFeedback(HapticFeedbackConstants.CLOCK_TICK) }
    val night = nav.night
    // Animations off (Settings → Accessibility → Remove animations, or CI): the layout changes at once.
    val reduceMotion = remember {
        Settings.Global.getFloat(context.contentResolver, Settings.Global.ANIMATOR_DURATION_SCALE, 1f) == 0f
    }

    CompositionLocalProvider(LocalNight provides night) {
        MaterialTheme(colorScheme = darkColorScheme(
            surface = Palette.menu.night(night), surfaceContainer = Palette.menu.night(night), onSurface = Color.White.night(night),
        )) {
            BoxWithConstraints(
                Modifier.fillMaxSize()
                    // Night mode: the whole screen through a red multiply, so only red light is left.
                    .drawWithContent { drawContent(); if (night) drawRect(Palette.nightRed, blendMode = BlendMode.Multiply) }
                    .background(Palette.screen)
                    // The "Bearings" title is gone from the screen; TalkBack still hears it.
                    .semantics { paneTitle = Brand.APP_NAME },
            ) {
                // H: the whole screen, system bars included (the app draws edge to edge).
                val fullHeight = maxHeight
                BoxWithConstraints(Modifier.fillMaxSize().windowInsetsPadding(WindowInsets.safeDrawing)) {
                    val fontScale = LocalDensity.current.fontScale
                    val k = fontScale.coerceIn(1f, LayoutPlan.MAX_K)
                    val bigText = fontScale >= 1.5f
                    val w = maxWidth.value; val s = maxHeight.value; val h = fullHeight.value
                    val noCompass = nav.compass == CompassStatus.UNAVAILABLE && nav.heading == null
                    val plan = LayoutPlan.plan(
                        w, h, s, nav.layout, k, bigText, locked = nav.lock != null && !noCompass, hasSpot = nav.markText != null,
                        isLandscapePhone = w > h && s < LayoutPlan.LANDSCAPE_PHONE, twoLineStatus = noCompass,
                    )
                    SideEffect { LayoutPlan.last = plan; LayoutPlan.lastHeight = h; LayoutPlan.lastSafeHeight = s }
                    val spec: AnimationSpec<Dp> = if (reduceMotion) snap<Dp>() else spring<Dp>(stiffness = Spring.StiffnessMediumLow)
                    val dial by animateDpAsState(plan.dial.dp, spec, label = "dial")
                    when {
                        plan.twoPane -> TwoPanes(nav, plan, dial, k, noCompass, actions)
                        plan.list -> ListScreen(nav, plan, dial, k, noCompass, actions)
                        else -> SingleColumn(nav, plan, dial, k, noCompass, actions)
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
            if (mapSheet) MapSheet(nav, night, openMap) { mapSheet = false }
            if (detailsSheet) DetailsSheet(nav, night) { detailsSheet = false }
        }
    }
}

/** What the screen's parts can ask for. */
private class Actions(
    val copy: () -> Unit,
    val details: () -> Unit,
    val map: () -> Unit,
    val openMap: (Fix) -> Unit,
    val useLocation: () -> Unit,
    val openSettings: () -> Unit,
    val about: () -> Unit,
)

// ---------- The three arrangements ----------

/**
 * One fixed column (§3.1, §3.3): every block at the planner's size and gap. It sits in a scroll view only as a
 * guard: when the plan fits (it always does at font scales up to 1.3) nothing moves, and if text ever runs
 * taller than planned the last block scrolls into view instead of being cut.
 */
@Composable
private fun SingleColumn(nav: Navigator, plan: Plan, dial: Dp, k: Float, noCompass: Boolean, a: Actions) {
    val column = plan.column.dp
    Column(
        Modifier.fillMaxSize().verticalScroll(rememberScrollState())
            .padding(top = LayoutPlan.TOP.dp, bottom = LayoutPlan.BOTTOM.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        if (plan.topExtra > 0f) Spacer(Modifier.height(plan.topExtra.dp))
        HeaderBar(nav, plan, a, wrap = false, Modifier.width(column))
        Spacer(Modifier.height(plan.headerGap.dp))
        DialBlock(nav, dial, plan.layout.e.dp, noCompass)
        Spacer(Modifier.height(plan.dialGap.dp))
        ReadoutGroup(nav, plan, k, noCompass, Modifier.width(column))
        Spacer(Modifier.height(plan.groupGap.dp))
        if (nav.markText != null) {
            SpotRow(nav, LayoutPlan.spotHeight(k).dp, Modifier.width(column))
            Spacer(Modifier.height(LayoutPlan.ROW_GAP.dp))
        }
        TileGrid(nav, plan, plan.column, a)
        if (plan.map == MapMode.CARD) {
            Spacer(Modifier.height(LayoutPlan.MAP_GAP.dp))
            MapCard(nav, a, Modifier.width(column).height(plan.mapHeight.dp))
        }
    }
}

/**
 * Two panes (§3.5): one full-width header; the dial, readout, status line and lock chip centred in the leading
 * pane; the spot row, the grid and the map card in the trailing pane, top-aligned with the dial.
 */
@Composable
private fun TwoPanes(nav: Navigator, plan: Plan, dial: Dp, k: Float, noCompass: Boolean, a: Actions) {
    val margin = plan.margin.dp
    Column(Modifier.fillMaxSize().padding(top = LayoutPlan.TOP.dp, bottom = LayoutPlan.BOTTOM.dp)) {
        HeaderBar(nav, plan, a, wrap = false, Modifier.padding(horizontal = margin).fillMaxWidth())
        Spacer(Modifier.height(LayoutPlan.HEADER_GAP.dp))
        Row(Modifier.fillMaxWidth().weight(1f).padding(horizontal = margin)) {
            Box(Modifier.weight(1f).fillMaxHeight(), contentAlignment = Alignment.Center) {
                Column(Modifier.fillMaxWidth().verticalScroll(rememberScrollState()), horizontalAlignment = Alignment.CenterHorizontally) {
                    DialBlock(nav, dial, 16.dp, noCompass)
                    Spacer(Modifier.height(LayoutPlan.DIAL_GAP.dp))
                    ReadoutGroup(nav, plan, k, noCompass, Modifier.fillMaxWidth())
                }
            }
            Spacer(Modifier.width(margin))
            Column(Modifier.width(plan.trailingWidth.dp).fillMaxHeight().verticalScroll(rememberScrollState())) {
                if (plan.leadingTop > 0f) Spacer(Modifier.height(plan.leadingTop.dp))
                if (nav.markText != null) {
                    SpotRow(nav, LayoutPlan.spotHeight(k).dp, Modifier.fillMaxWidth())
                    Spacer(Modifier.height(LayoutPlan.ROW_GAP.dp))
                }
                TileGrid(nav, plan, plan.trailingWidth, a)
                if (plan.map == MapMode.CARD) {
                    Spacer(Modifier.height(LayoutPlan.MAP_GAP.dp))
                    MapCard(nav, a, Modifier.fillMaxWidth().height(plan.mapHeight.dp))
                }
            }
        }
    }
}

/**
 * Accessibility text sizes (§3.6): the whole screen is one list. The header wraps, the dial is min(C − 32,
 * 40% of H), the tiles are full-width rows whose values wrap, and the map card is 200. Every block is whole.
 */
@Composable
private fun ListScreen(nav: Navigator, plan: Plan, dial: Dp, k: Float, noCompass: Boolean, a: Actions) {
    Column(
        Modifier.fillMaxSize().verticalScroll(rememberScrollState())
            .padding(start = plan.margin.dp, end = plan.margin.dp, top = LayoutPlan.TOP.dp, bottom = 24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        HeaderBar(nav, plan, a, wrap = true, Modifier.fillMaxWidth())
        Spacer(Modifier.height(LayoutPlan.HEADER_GAP.dp))
        DialBlock(nav, dial, 0.dp, noCompass)
        Spacer(Modifier.height(LayoutPlan.DIAL_GAP.dp))
        ReadoutGroup(nav, plan, k, noCompass, Modifier.fillMaxWidth())
        Spacer(Modifier.height(LayoutPlan.GROUP_GAP.dp))
        if (nav.markText != null) {
            SpotRow(nav, LayoutPlan.spotHeight(k).dp, Modifier.fillMaxWidth())
            Spacer(Modifier.height(LayoutPlan.ROW_GAP.dp))
        }
        TileGrid(nav, plan, plan.column, a)
        Spacer(Modifier.height(LayoutPlan.MAP_GAP.dp))
        MapCard(nav, a, Modifier.fillMaxWidth().height(LayoutPlan.LIST_MAP.dp))
    }
}

// ---------- The header bar ----------

/**
 * The header bar (§3.2): on the sky, "Maroon Bells, Colorado" (the state goes first when it is too long)
 * over "Sun, Nov 1 · 9:41 AM" and the Sample pill; then, at a fixed place at the trailing end, the sky's
 * symbol, the map button (only when the map is neither a tile nor a card) and the ⋯ menu. Read as one heading.
 */
@Composable
private fun HeaderBar(nav: Navigator, plan: Plan, a: Actions, wrap: Boolean, modifier: Modifier) {
    val sun = nav.fix?.let { Sky.sunPosition(nav.now.toDouble(), it.latitude, it.longitude) }
    val night = LocalNight.current
    Row(
        modifier.heightIn(min = plan.header.dp).skyCard(sun?.altitude, Look.headerShape).padding(start = 14.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(
            Modifier.weight(1f).padding(vertical = 4.dp).semantics(mergeDescendants = true) {
                heading()
                contentDescription = "${nav.title}, ${nav.dateTimeText}${if (nav.sample) ", sample place" else ""}"
            },
        ) {
            PlaceLine(nav.title, wrap)
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(nav.dateTimeText, style = text(13f, color = headerSecondary()).copy(lineHeight = 16.sp, fontFeatureSettings = "tnum"),
                    maxLines = if (wrap) 2 else 1, overflow = TextOverflow.Ellipsis, modifier = Modifier.weight(1f, fill = false))
                if (nav.sample) {
                    Spacer(Modifier.width(6.dp))
                    SampleBadge()
                }
            }
        }
        Spacer(Modifier.width(8.dp))
        // Decorative: TalkBack hears the place and time.
        Icon(skyIcon(sun?.altitude, sun?.azimuth), null, tint = white(Op.BODY), modifier = Modifier.size(20.dp))
        Spacer(Modifier.width(4.dp))
        if (plan.mapButton) HeaderButton(Icons.Filled.Map, "Map", "Open the map", a.map)
        MenuButton(nav, night, a)
    }
}

/** The place on one line: the whole name when it fits, otherwise without the state, then cut short. */
@Composable
private fun PlaceLine(title: String, wrap: Boolean) {
    val style = text(17f, FontWeight.SemiBold).copy(lineHeight = 22.sp)
    if (wrap) {
        Text(title, style = style, maxLines = 2, overflow = TextOverflow.Ellipsis)
        return
    }
    val measurer = rememberTextMeasurer()
    BoxWithConstraints(Modifier.fillMaxWidth()) {
        val max = constraints.maxWidth
        val shown = remember(title, max, style) {
            val fits = measurer.measure(AnnotatedString(title), style, softWrap = false, maxLines = 1).size.width <= max
            if (fits) title else title.substringBefore(", ")
        }
        Text(shown, style = style, maxLines = 1, overflow = TextOverflow.Ellipsis)
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

/** A faint white 36 dp circle in a 48 dp touch target, as the ⋯ menu. */
@Composable
private fun HeaderButton(icon: ImageVector, label: String, clickLabel: String, onClick: () -> Unit) {
    Box(
        Modifier.size(48.dp).clip(CircleShape).clickable(role = Role.Button, onClickLabel = clickLabel, onClick = onClick)
            .semantics { contentDescription = label },
        contentAlignment = Alignment.Center,
    ) {
        Box(Modifier.size(36.dp).clip(CircleShape).background(Palette.chipOff), contentAlignment = Alignment.Center) {
            Icon(icon, null, tint = Color.White, modifier = Modifier.size(20.dp))
        }
    }
}

/** The ⋯ menu, at the trailing end of the header on every layout, with everything Bearings can do or change. */
@Composable
private fun MenuButton(nav: Navigator, night: Boolean, a: Actions) {
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
            for (l in Layout.entries) LayoutItem(l, nav.layout == l, night) { nav.setLayout(l); open = false }
            MenuSection("Coordinates", night)
            for (f in Geo.Format.entries) Check(f.title, nav.format == f, night) { nav.setFormat(f); open = false }
            MenuSection("Units", night)
            Check("Feet First", nav.feet, night) { nav.setFeet(true); open = false }
            Check("Metres First", !nav.feet, night) { nav.setFeet(false); open = false }
            MenuSection("North", night)
            Check("True North", nav.preferTrueNorth, night) { nav.setTrueNorth(true); open = false }
            Check("Magnetic North", !nav.preferTrueNorth, night) { nav.setTrueNorth(false); open = false }
            MenuSection("Map", night)
            Item("Show Map", night) { a.map(); open = false }
            Check("Follow Heading", nav.followHeading, night) { nav.setFollowHeading(!nav.followHeading); open = false }
            Item("Open in Maps", night, hasFix) { fix?.let(a.openMap); open = false }
            HorizontalDivider(color = white(Op.STROKE).night(night))
            Check("Night Mode", night, night) { nav.setNight(!night); open = false }
            HorizontalDivider(color = white(Op.STROKE).night(night))
            if (nav.mark == null) Item("Mark This Spot", night, hasFix) { nav.markHere(); open = false }
            else Item("Clear Marked Spot", night) { nav.clearMark(); open = false }
            Item(if (nav.lock == null) "Lock This Bearing" else "Clear Locked Bearing", night, nav.heading != null || nav.lock != null) {
                if (nav.lock != null) nav.lock = null else nav.toggleLock()
                open = false
            }
            Item("Copy Coordinates", night, hasFix) { a.copy(); open = false }
            Item("Details…", night) { a.details(); open = false }
            Item("Share My Location…", night, hasFix) { nav.shareLocationText?.let(::share); open = false }
            Item("Share Bearings…", night) { share("${Brand.SHARE_MESSAGE} ${Brand.PRODUCT_PAGE}"); open = false }
            HorizontalDivider(color = white(Op.STROKE).night(night))
            Item("Terms & Privacy", night) { uri.openUri(Brand.LEGAL); open = false }
            Item("About Bearings", night) { a.about(); open = false }
        }
    }
}

/** Secondary text in a menu or dialog, which night mode's multiply can't reach: tinted by hand, 4.5:1 or better. */
private fun menuSecondary(night: Boolean) = white(if (night) Op.NIGHT_SECONDARY else Op.CAPTION).night(night)

@Composable private fun MenuSection(title: String, night: Boolean) =
    Text(title.uppercase(), style = text(11f, FontWeight.SemiBold, menuSecondary(night)),
        modifier = Modifier.padding(start = 16.dp, top = 10.dp, bottom = 2.dp))

@Composable private fun Check(title: String, on: Boolean, night: Boolean, onClick: () -> Unit) =
    DropdownMenuItem(text = { Text(title, style = text(15f, color = Color.White.night(night))) }, onClick = onClick,
        leadingIcon = { Text(if (on) "✓" else "", style = text(15f, color = Color.White.night(night)), modifier = Modifier.widthIn(min = 14.dp)) })

@Composable private fun Item(title: String, night: Boolean, enabled: Boolean = true, onClick: () -> Unit) =
    DropdownMenuItem(text = { Text(title, style = text(15f, color = (if (enabled) Color.White else white(Op.FAINT)).night(night))) },
        onClick = onClick, enabled = enabled, leadingIcon = { Spacer(Modifier.widthIn(min = 14.dp)) })

/** A layout in the menu (§4.4): its symbol, its name over a one-line subtitle, and a check on the current one. */
@Composable private fun LayoutItem(layout: Layout, on: Boolean, night: Boolean, onClick: () -> Unit) =
    DropdownMenuItem(
        text = {
            Column {
                Text(layout.title, style = text(15f, color = Color.White.night(night)))
                Text(layout.subtitle, style = text(13f, color = menuSecondary(night)))
            }
        },
        onClick = onClick,
        leadingIcon = { Icon(layoutIcon(layout), null, tint = Color.White.night(night), modifier = Modifier.size(20.dp)) },
        trailingIcon = { Text(if (on) "✓" else "", style = text(15f, color = Color.White.night(night)), modifier = Modifier.widthIn(min = 14.dp)) },
        modifier = Modifier.semantics { if (on) stateDescription = "Selected" },
    )

private fun layoutIcon(layout: Layout): ImageVector = when (layout) {
    Layout.SMALL -> Icons.Filled.Map
    Layout.MEDIUM -> Icons.Filled.Dashboard
    Layout.LARGE -> Icons.Filled.Explore
    Layout.EXTRA_LARGE -> Icons.Filled.ZoomOutMap
}

// ---------- The dial, the readout, the status line and the lock chip ----------

@Composable
private fun DialBlock(nav: Navigator, side: Dp, margin: Dp, noCompass: Boolean) {
    // TalkBack hears the heading at most every few seconds, not at the sensor's rate.
    var spoken by remember { mutableStateOf<Double?>(null) }
    LaunchedEffect(Unit) {
        while (true) {
            val h = nav.heading
            val s = spoken
            if (h == null || s == null || abs(Geo.delta(s, h)) >= 3) spoken = h
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
                lock = if (noCompass) null else nav.lock,
                sun = nav.sun,
                moon = nav.moon,
                moonPhase = nav.moonPhase.phase,
                mark = nav.markBearing?.let { nav.onCard(it) },
            )
            Dial(nav.cardRotation, nav.heading, marks, nav.tilt, Modifier.fillMaxSize(), noCompass = noCompass)
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
            if (turn == 0) "$locked, on bearing" else "$locked, turn ${abs(turn)} ${if (turn > 0) "right" else "left"}"
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

/** The readout, the status line (read with it) and the lock chip. */
@Composable
private fun ReadoutGroup(nav: Navigator, plan: Plan, k: Float, noCompass: Boolean, modifier: Modifier) {
    Column(modifier, horizontalAlignment = Alignment.CenterHorizontally) {
        Column(Modifier.fillMaxWidth().semantics(mergeDescendants = true) {}) {
            Readout(nav, plan.headingSize)
            Spacer(Modifier.height(LayoutPlan.STATUS_GAP.dp))
            StatusLine(nav, k, noCompass)
        }
        if (nav.lock != null && !noCompass) {
            Spacer(Modifier.height(LayoutPlan.CHIP_GAP.dp))
            LockChip(nav)
        }
    }
}

@Composable
private fun Readout(nav: Navigator, baseSize: Float) {
    val h = nav.heading
    // The number follows the font size only up to 1.3 times, like the layout's heights.
    val fs = LocalDensity.current.fontScale
    val size = if (fs > LayoutPlan.MAX_K) baseSize * LayoutPlan.MAX_K / fs else baseSize
    // Tabular figures, so the number doesn't jiggle as it changes. Light in Two Degrees; Inter has no Light here, so Normal.
    val big = text(size, FontWeight.Normal, if (h == null) white(Op.NO_HEADING) else Color.White)
        .copy(letterSpacing = (-2).sp, lineHeight = (size * LayoutPlan.READOUT_LINE).sp, fontFeatureSettings = "tnum")
    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.Center) {
        Text(if (h == null) "—°" else "${Math.round(h) % 360}°", style = big, modifier = Modifier.alignByBaseline())
        if (h != null) {
            Spacer(Modifier.width(10.dp))
            Text(Geo.point(h), style = text(size / 2, FontWeight.Medium, secondary()),
                modifier = Modifier.alignByBaseline().widthIn(min = (size * 1.1f).dp))
        }
    }
}

/**
 * The status line (§3.2): "True north · 8° E declination · ±8° accuracy", one line (two at a larger font
 * size, breaking only after a dot). Warnings in amber take its place; with no compass, it says so.
 */
@Composable
private fun StatusLine(nav: Navigator, k: Float, noCompass: Boolean) {
    val (line, spoken) = status(nav, noCompass)
    val two = k > 1.1f || noCompass
    Text(line, style = text(13f, color = secondary()).copy(lineHeight = 18.sp), textAlign = TextAlign.Center,
        // As many lines as the planner keeps for it, so the blocks under it stay where it put them.
        maxLines = if (two) 2 else 1, minLines = if (two) 2 else 1, overflow = TextOverflow.Ellipsis,
        modifier = Modifier.fillMaxWidth().heightIn(min = 18.dp).semantics {
            contentDescription = spoken
            // Said once, politely, when the phone turns out to have no compass.
            if (noCompass) liveRegion = LiveRegionMode.Polite
        })
}

private fun status(nav: Navigator, noCompass: Boolean): Pair<AnnotatedString, String> {
    val warn = SpanStyle(color = Palette.notice, fontWeight = FontWeight.SemiBold)
    return when {
        noCompass -> dotted(listOf("No compass on this device", "position, sun and map still work")) to
            "No compass on this device. Position, sun and map still work."
        nav.compass != CompassStatus.LIVE || nav.heading == null -> AnnotatedString(" ") to ""
        nav.interference -> buildAnnotatedString { withStyle(warn) { append("Magnet or metal nearby: move away") } } to
            "Warning: magnet or metal nearby. Move away."
        (nav.headingAccuracy ?: 0.0) > Navigator.POOR_HEADING_ACCURACY ->
            buildAnnotatedString { withStyle(warn) { append("Low accuracy: move your phone in a figure 8") } } to
                "Low accuracy. Move your phone in a figure 8."
        else -> {
            val north = if (nav.usingTrueNorth) "True north" else "Magnetic north"
            val parts = mutableListOf(north)
            val spoken = mutableListOf(north)
            val d = nav.declination
            if (nav.usingTrueNorth && d != null && abs(d) >= 0.5) {
                val deg = Math.round(abs(d))
                parts += "$deg° ${if (d >= 0) "E" else "W"} declination"
                spoken += "$deg degrees ${if (d >= 0) "east" else "west"} declination"
            }
            nav.headingAccuracy?.let {
                parts += "±${Math.round(it)}° accuracy"
                spoken += "accuracy plus or minus ${Math.round(it)} degrees"
            }
            dotted(parts) to spoken.joinToString(", ")
        }
    }
}

/** The parts joined by faint dots; spaces inside a part don't break, so a line breaks only after a dot. */
private fun dotted(parts: List<String>): AnnotatedString = buildAnnotatedString {
    parts.forEachIndexed { i, p ->
        if (i > 0) {
            append(' ')
            withStyle(SpanStyle(color = white(Op.FAINT))) { append('·') }
            append(' ')
        }
        append(p.replace(' ', ' '))
    }
}

/**
 * The lock chip (§3.2): an accent capsule 28 high, "Locked 240° · turn 12° right", and ✕ in a 48 dp target
 * (reaching into the gaps around it) to unlock.
 */
@Composable
private fun LockChip(nav: Navigator) {
    val l = nav.lock ?: return
    val night = LocalNight.current
    val label = nav.lockText ?: "Locked ${Math.round(l) % 360}°"
    val spoken = label.replace("°", " degrees").replace(" · ", ", ")
    Row(
        // A background in the capsule's shape rather than a clip, so the ✕'s 48 dp target isn't clipped to the chip.
        Modifier.heightIn(min = LayoutPlan.CHIP.dp)
            .background(Palette.accent.copy(alpha = if (night) 0.25f else 0.2f), CircleShape)
            .semantics(mergeDescendants = true) {
                contentDescription = spoken
                customActions = listOf(CustomAccessibilityAction("Unlock") { nav.lock = null; true })
            }
            .padding(start = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(Icons.Filled.Lock, null, tint = Color.White, modifier = Modifier.size(13.dp))
        Spacer(Modifier.width(6.dp))
        Text(label, style = text(13f, FontWeight.SemiBold).copy(lineHeight = 18.sp, fontFeatureSettings = "tnum"), maxLines = 1)
        Box(Modifier.width(34.dp).height(LayoutPlan.CHIP.dp), contentAlignment = Alignment.Center) {
            Box(
                Modifier.requiredSize(48.dp).clip(CircleShape).clickable(role = Role.Button) { nav.lock = null }
                    .semantics { contentDescription = "Unlock the bearing" },
                contentAlignment = Alignment.Center,
            ) { Icon(Icons.Filled.Close, null, tint = white(Op.SUB), modifier = Modifier.size(13.dp)) }
        }
    }
}

// ---------- The marked spot ----------

/**
 * The spot row (§3.2): a full-width tile with the pin, "Marked spot", "9.2 mi · 46° NE" at the trailing side
 * and ✕ 8 after it in a 48 dp target. The row opens a small menu: Lock to Spot, Clear Marked Spot.
 */
@Composable
private fun SpotRow(nav: Navigator, height: Dp, modifier: Modifier) {
    val label = nav.markText ?: return
    var open by remember { mutableStateOf(false) }
    val night = LocalNight.current
    Box(modifier) {
        Row(
            Modifier.fillMaxWidth().heightIn(min = height).clip(Look.shape)
                .clickable(role = Role.Button, onClickLabel = "Show what you can do with the marked spot") { open = true }
                .frostedTile()
                .semantics(mergeDescendants = true) {
                    contentDescription = spotSpoken(nav)
                    customActions = listOf(
                        CustomAccessibilityAction("Lock to Spot") { nav.lockToSpot(); true },
                        CustomAccessibilityAction("Clear") { nav.clearMark(); true },
                    )
                }
                .padding(start = 12.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Icon(Icons.Filled.Place, null, tint = Color.White, modifier = Modifier.size(17.dp))
            Spacer(Modifier.width(8.dp))
            Text("Marked spot", style = text(15f, FontWeight.Medium).copy(lineHeight = 20.sp), maxLines = 1)
            Spacer(Modifier.weight(1f).widthIn(min = 8.dp))
            Text(label, style = text(15f).copy(lineHeight = 20.sp, fontFeatureSettings = "tnum"), textAlign = TextAlign.End,
                modifier = Modifier.padding(vertical = 4.dp))
            // ✕ 8 after the text, in a 48 dp target at the trailing edge.
            Box(
                Modifier.size(48.dp).clip(CircleShape).clickable(role = Role.Button) { nav.clearMark() }
                    .semantics { contentDescription = "Clear the marked spot" },
                contentAlignment = Alignment.CenterStart,
            ) { Icon(Icons.Filled.Close, null, tint = secondary(), modifier = Modifier.padding(start = 8.dp).size(13.dp)) }
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

// ---------- The tile grid ----------

/** A tick every 15 seconds, for "fix age" and dimming a stale fix. */
@Composable
private fun rememberTick(): Long {
    var tick by remember { mutableLongStateOf(System.currentTimeMillis()) }
    LaunchedEffect(Unit) { while (true) { delay(15_000); tick = System.currentTimeMillis() } }
    return tick
}

/**
 * The tile grid (§3.2): 3 columns of unit u = (C − 16) / 3, 8 apart. Full: Position (2u) | Elevation, then
 * Sun | Moon | Map (Sun | Moon when the map is a card). Compact: Position (2u) | Elevation | Sun. In a pane
 * under 360 wide, 2 columns. In the scrolling list, full-width rows. Tiles in a row share the tallest one's
 * height, at least the planned height. Before a location is allowed, the request for it takes the grid's place.
 */
@Composable
private fun TileGrid(nav: Navigator, plan: Plan, width: Float, a: Actions) {
    val gridHeight = LayoutPlan.gridHeight(plan.grid, plan.tile, plan.gridColumns)
    if (nav.fix == null && nav.access != Access.ALLOWED) {
        AskForLocation(nav.access == Access.DENIED, a.useLocation, a.openSettings,
            Modifier.width(width.dp).heightIn(min = if (plan.grid == GridMode.ROWS) 0.dp else gridHeight.dp))
        return
    }
    var positionMenu by remember { mutableStateOf(false) }
    val tick = rememberTick()
    val fix = nav.fix
    val stale = !nav.sample && fix != null && tick - fix.time > 120_000
    val gap = LayoutPlan.ROW_GAP
    val u = (width - 2 * gap) / 3
    val half = (width - gap) / 2
    val tileH = plan.tile.dp
    val inner = { w: Float -> (w - 24f).dp }
    val night = LocalNight.current
    val position = @Composable { w: Float -> PositionTile(nav, stale, inner(w), { positionMenu = true }, a) }
    val elevation = @Composable { ElevationTile(nav, stale, a) }
    val sunTile = @Composable { w: Float -> SunTile(nav, inner(w), a) }
    val moonTile = @Composable { MoonTile(nav, a) }
    val mapTile = @Composable { MapTile(nav, a) }
    Box(Modifier.width(width.dp)) {
        Column(verticalArrangement = Arrangement.spacedBy(gap.dp)) {
            when {
                plan.grid == GridMode.ROWS -> {
                    for (tile in listOf<@Composable () -> Unit>({ position(width) }, elevation, { sunTile(width) }, moonTile)) {
                        TileRow(listOf(width.dp), 0.dp) { tile() }
                    }
                }
                plan.grid == GridMode.COMPACT -> TileRow(listOf((2 * u + gap).dp, u.dp, u.dp), tileH) {
                    position(2 * u + gap); elevation(); sunTile(u)
                }
                plan.gridColumns >= 3 -> {
                    TileRow(listOf((2 * u + gap).dp, u.dp), tileH) { position(2 * u + gap); elevation() }
                    if (plan.map == MapMode.TILE) {
                        TileRow(listOf(u.dp, u.dp, u.dp), tileH, mapIndex = 2) { sunTile(u); moonTile(); mapTile() }
                    } else {
                        TileRow(listOf(half.dp, half.dp), tileH) { sunTile(half); moonTile() }
                    }
                }
                else -> {
                    TileRow(listOf(width.dp), tileH) { position(width) }
                    TileRow(listOf(half.dp, half.dp), tileH) { elevation(); sunTile(half) }
                    if (plan.map == MapMode.TILE) TileRow(listOf(half.dp, half.dp), tileH, mapIndex = 1) { moonTile(); mapTile() }
                    else TileRow(listOf(width.dp), tileH) { moonTile() }
                }
            }
        }
        // Touch and hold on Position: Copy, Details… (outside the rows, which measure their tiles' heights).
        DropdownMenu(positionMenu, onDismissRequest = { positionMenu = false }) {
            Item("Copy", night, fix != null) { a.copy(); positionMenu = false }
            Item("Details…", night) { a.details(); positionMenu = false }
        }
    }
}

/**
 * One row of tiles at the given widths, 8 apart, all as tall as the tallest (at least [minHeight]): a tile
 * grows taller before anything in it is cut. The map tile ([mapIndex]) takes the row's height without being
 * asked for its own (a map has none).
 */
@Composable
private fun TileRow(widths: List<Dp>, minHeight: Dp, mapIndex: Int = -1, content: @Composable () -> Unit) {
    ComposeLayout(content) { measurables, _ ->
        val gap = LayoutPlan.ROW_GAP.dp.roundToPx()
        val ws = widths.map { it.roundToPx() }
        var h = minHeight.roundToPx()
        measurables.forEachIndexed { i, m -> if (i != mapIndex && i < ws.size) h = max(h, m.maxIntrinsicHeight(ws[i])) }
        val placeables = measurables.mapIndexed { i, m -> m.measure(Constraints.fixed(ws.getOrElse(i) { 0 }, h)) }
        val total = ws.sum() + gap * (ws.size - 1).coerceAtLeast(0)
        layout(total, h) {
            var x = 0
            placeables.forEachIndexed { i, p -> p.placeRelative(x, 0); x += ws.getOrElse(i) { 0 } + gap }
        }
    }
}

/**
 * One tile (§3.2), the widgets' pattern: a caption (11, caps, tracking 0.6, secondary) over the value (17,
 * tabular) and a secondary line (13), leading-aligned, 12 in at the sides and 10 at top and bottom. TalkBack
 * reads it as one element ([spoken]).
 */
@Composable
private fun Tile(caption: String, spoken: String, click: Modifier = Modifier, content: @Composable ColumnScope.() -> Unit) {
    // Clipped before the click, so the ripple keeps the rounded corners.
    Column(
        Modifier.fillMaxSize().clip(Look.shape).then(click).frostedTile()
            .semantics(mergeDescendants = true) { contentDescription = spoken }
            .padding(horizontal = Look.tilePaddingH, vertical = Look.tilePaddingV),
    ) {
        Text(caption.uppercase(), style = text(Look.TILE_CAPTION, FontWeight.SemiBold, secondary())
            .copy(letterSpacing = Look.TILE_CAPTION_TRACKING.sp, lineHeight = Look.TILE_CAPTION_LINE.sp), maxLines = 1, softWrap = false)
        content()
    }
}

@Composable
private fun valueStyle(dim: Boolean = false): TextStyle =
    text(Look.TILE_VALUE, FontWeight.Medium, if (dim) secondary() else Color.White)
        .copy(lineHeight = Look.TILE_VALUE_LINE.sp, fontFeatureSettings = "tnum")

@Composable
private fun secondaryStyle(): TextStyle =
    text(Look.TILE_SECONDARY, color = secondary()).copy(lineHeight = Look.TILE_SECONDARY_LINE.sp, fontFeatureSettings = "tnum")

/**
 * A value that never ellipsizes (§3.2): it shrinks to fit [width] down to 0.85 of its size, then wraps.
 * Measured with a text measurer rather than BoxWithConstraints, so a row can still ask the tile its height.
 */
@Composable
private fun FitWrapText(value: String, style: TextStyle, width: Dp) {
    val measurer = rememberTextMeasurer()
    val density = LocalDensity.current
    val max = with(density) { width.roundToPx() }.coerceAtLeast(1)
    val scale = remember(value, max, style, density) {
        var f = 1f
        while (f > Look.MIN_TEXT_SCALE + 0.001f &&
            measurer.measure(AnnotatedString(value), style.copy(fontSize = style.fontSize * f), softWrap = false, maxLines = 1).size.width > max) f -= 0.05f
        f.coerceAtLeast(Look.MIN_TEXT_SCALE)
    }
    Text(value, style = style.copy(fontSize = style.fontSize * scale), softWrap = true)
}

/** "39.09898° N" → "39.09898 north", for TalkBack. */
private fun spokenCoordinate(s: String): String {
    val words = mapOf('N' to "north", 'S' to "south", 'E' to "east", 'W' to "west")
    val t = s.replace("°", "")
    val last = t.lastOrNull()
    return if (t.length > 2 && t[t.length - 2] == ' ' && last != null && last in words) t.dropLast(1) + words.getValue(last) else t
}

/** "DD", "DMS", "DDM", "UTM", "MGRS", "PLUS": the format's short name in the Position caption. */
private fun shortName(f: Geo.Format) = f.id.uppercase(Locale.ROOT)

/** Before the first fix: "—" over "Finding position…", never blank. */
@Composable
private fun Pending(note: String) {
    Text("—", style = valueStyle(dim = true))
    Text(note, style = secondaryStyle())
}

/** Position (2u): the coordinates in the current format. Tap: the next format. Touch and hold: Copy, Details…. */
@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun PositionTile(nav: Navigator, stale: Boolean, inner: Dp, onLongPress: () -> Unit, a: Actions) {
    val fix = nav.fix
    val f = fix?.let { Geo.format(nav.format, it.latitude, it.longitude) }
    val spoken = when (f) {
        is Geo.Formatted.Pair -> "Position, ${spokenCoordinate(f.lat)}, ${spokenCoordinate(f.lon)}, ${nav.format.title.lowercase()}${if (stale) ", not recent" else ""}"
        is Geo.Formatted.Single -> "Position, ${f.text}, ${nav.format.title}${if (stale) ", not recent" else ""}"
        null -> "Position, not known yet"
    }
    val click = if (fix == null) Modifier else Modifier
        .combinedClickable(onClickLabel = "Change the coordinate format", onLongClickLabel = "Show Copy and Details",
            onLongClick = onLongPress, onClick = { nav.cycleFormat() })
        .semantics {
            customActions = listOf(
                CustomAccessibilityAction("Next Format") { nav.cycleFormat(); true },
                CustomAccessibilityAction("Copy") { a.copy(); true },
                CustomAccessibilityAction("Details") { a.details(); true },
            )
        }
    Tile("Position · ${shortName(nav.format)}", spoken, click) {
        val style = valueStyle(dim = stale)
        when (f) {
            is Geo.Formatted.Pair -> { FitWrapText(f.lat, style, inner); FitWrapText(f.lon, style, inner) }
            is Geo.Formatted.Single -> FitWrapText(f.text, style, inner)
            null -> Pending("Finding position…")
        }
    }
}

/** "9,587 ft" → "9,587 feet", for TalkBack. */
private fun spokenUnits(s: String) = s.removeSuffix(" ft").let { if (it != s) "$it feet" else s.removeSuffix(" m") + " metres" }

/** Elevation: "9,587 ft" over "2,922 m" (the order follows the units setting). Opens the Details sheet. */
@Composable
private fun ElevationTile(nav: Navigator, stale: Boolean, a: Actions) {
    val click = Modifier.clickable(role = Role.Button, onClickLabel = "Show the details", onClick = a.details)
    when (val e = nav.elevation) {
        is ElevationReading.Value -> {
            val (ft, m) = Geo.elevation(e.metres)
            val first = if (nav.feet) ft else m; val second = if (nav.feet) m else ft
            val spoken = "Elevation, ${spokenUnits(first)}, ${spokenUnits(second)}, ${if (e.fromGps) "from GPS" else "from terrain data"}"
            Tile("Elevation", spoken, click) {
                Text(first, style = valueStyle(dim = stale))
                Text(second, style = secondaryStyle())
            }
        }
        is ElevationReading.Pending -> {
            val note = if (nav.fix == null) "Finding position…" else e.note.ifBlank { "Looking it up…" }
            Tile("Elevation", "Elevation, $note", click) { Pending(note) }
        }
    }
}

/** Sun: "↑ 6:36 AM" over "↓ 5:08 PM" (the phone's 12- or 24-hour clock), or "Up all day" / "Down all day". */
@Composable
private fun SunTile(nav: Navigator, inner: Dp, a: Actions) {
    val click = Modifier.clickable(role = Role.Button, onClickLabel = "Show the details", onClick = a.details)
    val fix = nav.fix
    if (fix == null) {
        Tile("Sun", "Sun, not known yet", click) { Pending("Finding position…") }
        return
    }
    val times = Sky.sunTimes(nav.now.toDouble(), fix.latitude, fix.longitude)
    val rise = times.sunrise; val set = times.sunset
    if (rise != null && set != null && times.polar == null) {
        val up = nav.clock(rise.toLong()); val down = nav.clock(set.toLong())
        Tile("Sun", "Sun, rises $up, sets $down", click) {
            FitWrapText("↑ $up", valueStyle(), inner)
            FitWrapText("↓ $down", valueStyle(), inner)
        }
    } else {
        val allDay = if (times.polar == com.bradcowdrey.bearings.Polar.DAY) "Up all day" else "Down all day"
        Tile("Sun", "Sun, $allDay", click) { FitWrapText(allDay, valueStyle(), inner) }
    }
}

/** Moon: the phase's glyph and "53%" over "Last quarter". Opens the Details sheet. */
@Composable
private fun MoonTile(nav: Navigator, a: Actions) {
    val phase = nav.moonPhase
    val percent = "${Geo.jsRound(phase.fraction * 100)}%"
    val name = Sky.phaseName(phase)
    Tile("Moon", "Moon, ${Geo.jsRound(phase.fraction * 100)} percent, ${name.lowercase()}",
        Modifier.clickable(role = Role.Button, onClickLabel = "Show the details", onClick = a.details)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Canvas(Modifier.size(13.dp)) { moonGlyph(Offset(size.width / 2, size.height / 2), size.minDimension / 2, phase.phase, 1f) }
            Spacer(Modifier.width(6.dp))
            Text(percent, style = valueStyle())
        }
        Text(name, style = secondaryStyle())
    }
}

/**
 * Map (one cell): a live north-up thumbnail with the heading cone and no controls, "MAP" bottom-leading on a
 * 40% black scrim, and MapLibre's attribution where it always is. Tapping it opens the map sheet.
 */
@Composable
private fun MapTile(nav: Navigator, a: Actions) {
    Box(Modifier.fillMaxSize().clip(Look.shape)) {
        MapSnippet(
            nav.fix, nav.trueHeading, follow = false, night = nav.night, speed = null,
            onToggleFollow = {}, onOpen = a.openMap, modifier = Modifier.fillMaxSize(), controls = false,
        )
        Text("MAP", style = text(Look.TILE_CAPTION, FontWeight.SemiBold, Color.White)
            .copy(letterSpacing = Look.TILE_CAPTION_TRACKING.sp, lineHeight = Look.TILE_CAPTION_LINE.sp),
            modifier = Modifier.align(Alignment.BottomStart).padding(8.dp).clip(RoundedCornerShape(6.dp))
                .background(Color.Black.copy(alpha = 0.4f)).padding(horizontal = 6.dp, vertical = 2.dp))
        // Over the map, so the tap opens the sheet rather than reaching the map view.
        Box(Modifier.matchParentSize().clickable(role = Role.Button, onClickLabel = "Open the map", onClick = a.map)
            .semantics { contentDescription = "Map" })
    }
}

/** The map card: the whole map with its one control cluster, the speed chip and the attribution. */
@Composable
private fun MapCard(nav: Navigator, a: Actions, modifier: Modifier) {
    MapSnippet(
        nav.fix, nav.trueHeading, nav.followHeading, nav.night,
        speed = nav.speed?.let { Geo.speedText(it, nav.feet) },
        onToggleFollow = { nav.setFollowHeading(!nav.followHeading) },
        onOpen = a.openMap,
        modifier = modifier,
    )
}

@Composable
private fun AskForLocation(denied: Boolean, onUseLocation: () -> Unit, onOpenSettings: () -> Unit, modifier: Modifier) {
    Column(modifier.frostedTile().padding(horizontal = Look.padding, vertical = Look.paddingV),
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

// ---------- The sheets ----------

/** A sheet's content through night mode's red multiply (a sheet is a window of its own, outside the screen's). */
private fun Modifier.nightMultiply(night: Boolean): Modifier =
    this.drawWithContent { drawContent(); if (night) drawRect(Palette.nightRed, blendMode = BlendMode.Multiply) }

/** The sheet's title row: a heading and Done in a 48 dp target. */
@Composable
private fun SheetTitle(title: String, onDone: () -> Unit) {
    Row(Modifier.fillMaxWidth().padding(start = 16.dp, end = 4.dp), verticalAlignment = Alignment.CenterVertically) {
        Text(title, style = text(17f, FontWeight.SemiBold), modifier = Modifier.weight(1f).semantics { heading() })
        Text("Done", style = text(15f, FontWeight.SemiBold),
            modifier = Modifier.heightIn(min = 48.dp).clip(CircleShape).clickable(role = Role.Button, onClick = onDone).padding(12.dp))
    }
}

/** The map sheet (§3.2): full height, with the same control cluster and chip as the map card. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun MapSheet(nav: Navigator, night: Boolean, openMap: (Fix) -> Unit, onDismiss: () -> Unit) {
    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
        containerColor = Palette.menu.night(night),
    ) {
        Column(Modifier.fillMaxWidth().fillMaxHeight().nightMultiply(night)) {
            SheetTitle("Map", onDismiss)
            MapSnippet(
                nav.fix, nav.trueHeading, nav.followHeading, night,
                speed = nav.speed?.let { Geo.speedText(it, nav.feet) },
                onToggleFollow = { nav.setFollowHeading(!nav.followHeading) },
                onOpen = openMap,
                modifier = Modifier.fillMaxWidth().weight(1f).padding(start = 16.dp, end = 16.dp, bottom = 16.dp),
            )
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
 * The Details sheet (§3.2): what the old Details tiles showed, as one grouped list: the coordinates and their
 * format, accuracy, fix age, elevation and its source, pressure, sunrise and sunset with their directions,
 * and the moon's phase.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun DetailsSheet(nav: Navigator, night: Boolean, onDismiss: () -> Unit) {
    val tick = rememberTick()
    val fix = nav.fix
    val rows = buildList {
        if (fix != null) {
            add(nav.format.title to (nav.copyText ?: "—"))
            add("Accuracy" to Geo.accuracy(fix.accuracy, nav.feet))
            add("Fix age" to if (nav.sample) "Sample" else ago(tick - fix.time))
        } else add("Position" to "Finding position…")
        when (val e = nav.elevation) {
            is ElevationReading.Value -> {
                val (ft, m) = Geo.elevation(e.metres)
                add("Elevation" to if (nav.feet) "$ft · $m" else "$m · $ft")
                add("Elevation source" to e.source)
            }
            is ElevationReading.Pending -> add("Elevation" to e.note.ifBlank { "—" })
        }
        nav.pressure?.let { add("Pressure" to Geo.pressureText(it, nav.feet)) }
        if (fix != null) {
            val times = Sky.sunTimes(nav.now.toDouble(), fix.latitude, fix.longitude)
            fun at(ms: Double): String {
                val az = Sky.sunPosition(ms, fix.latitude, fix.longitude).azimuth
                return "${nav.clock(ms.toLong())} · ${Geo.jsRound(az) % 360}° ${Geo.point(az)}"
            }
            val rise = times.sunrise; val set = times.sunset
            if (rise != null) add("Sunrise" to at(rise))
            if (set != null) add("Sunset" to at(set))
            if (times.polar != null) add("Sun" to Sky.sunLine(times) { nav.clock(it) })
        }
        add("Moon" to Sky.moonWords(nav.moonPhase))
        nav.headingAccuracy?.let { add("Compass accuracy" to "±${Math.round(it)}°") }
    }
    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = rememberModalBottomSheetState(),
        containerColor = Palette.menu.night(night),
    ) {
        Column(Modifier.fillMaxWidth().nightMultiply(night).verticalScroll(rememberScrollState()).padding(bottom = 24.dp)) {
            SheetTitle("Details", onDismiss)
            Column(Modifier.padding(horizontal = 16.dp).fillMaxWidth().frostedTile()) {
                rows.forEachIndexed { i, (label, value) ->
                    if (i > 0) HorizontalDivider(color = Palette.tileStroke, modifier = Modifier.padding(start = 12.dp))
                    Row(Modifier.fillMaxWidth().heightIn(min = 48.dp).semantics(mergeDescendants = true) {}
                        .padding(horizontal = 12.dp, vertical = 10.dp), verticalAlignment = Alignment.CenterVertically) {
                        Text(label, style = text(15f, color = secondary()), modifier = Modifier.weight(1f))
                        Spacer(Modifier.width(12.dp))
                        Text(value, style = text(15f, FontWeight.Medium).copy(fontFeatureSettings = "tnum"), textAlign = TextAlign.End,
                            modifier = Modifier.weight(1.4f))
                    }
                }
            }
        }
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
                    style = text(13f, color = menuSecondary(night)))
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
