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
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.snap
import androidx.compose.animation.core.spring
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.ScrollState
import androidx.compose.foundation.background
import androidx.compose.foundation.border
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
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawing
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.InlineTextContent
import androidx.compose.foundation.text.appendInlineContent
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Dashboard
import androidx.compose.material.icons.filled.Explore
import androidx.compose.material.icons.filled.LocationOn
import androidx.compose.material.icons.filled.Map
import androidx.compose.material.icons.filled.MoreHoriz
import androidx.compose.material.icons.filled.NightsStay
import androidx.compose.material.icons.filled.WbSunny
import androidx.compose.material.icons.filled.WbTwilight
import androidx.compose.material.icons.filled.ZoomOutMap
import androidx.compose.material.icons.rounded.Close
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
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.BlendMode
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.RectangleShape
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.layout.Layout as ComposeLayout
import androidx.compose.ui.layout.layout
import androidx.compose.ui.platform.LocalClipboardManager
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.semantics.CustomAccessibilityAction
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.customActions
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.paneTitle
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.Placeholder
import androidx.compose.ui.text.PlaceholderVerticalAlign
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.TextMeasurer
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.Constraints
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
import com.bradcowdrey.bearings.Sky
import java.util.Locale
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt
import kotlinx.coroutines.delay

/**
 * Bearings' one screen, the "instrument panel" (docs/REFINE.md §3, in docs/LOOK.md's look: black, white type,
 * the sky, frosted tiles). Top to bottom: the header bar (place, date and time, the ⋯ menu), the dial, the
 * readout, the status line and lock row, the marked spot's row, the labelled tile grid (Position, Elevation,
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
        website = { uri.openUri(Brand.WEBSITE) },
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
                    val locked = nav.lock != null && !noCompass
                    val landscapePhone = w > h && s < LayoutPlan.LANDSCAPE_PHONE
                    // What the planner can't know by itself, measured with the screen's own type (C3.4 #4, C3.2 #3):
                    // whether the status line wraps, and whether the header's place name or date runs to a second line.
                    val measurer = rememberTextMeasurer()
                    val density = LocalDensity.current
                    val column = LayoutPlan.columnWidth(w, h, landscapePhone)
                    val statusText = status(nav, noCompass).first
                    val sStyle = statusStyle(); val tStyle = titleStyle(); val dStyle = dateStyle()
                    val pill = if (nav.sample && !bigText) pillWidth(measurer) + with(density) { 6.dp.toPx() } else 0f
                    val statusLines = remember(statusText.text, column, density, noCompass, sStyle) {
                        // Every number as 88, so the line count doesn't flicker as the accuracy changes.
                        val probe = statusText.text.replace(Regex("[0-9]+"), "88")
                        val px = with(density) { (column - if (noCompass) 32f else 0f).dp.roundToPx() }.coerceAtLeast(1)
                        measurer.measure(AnnotatedString(probe), sStyle, constraints = Constraints(maxWidth = px)).lineCount.coerceIn(1, 2)
                    }
                    val title = nav.title
                    val dates = Triple(nav.dateText(), nav.dateText(short = true), nav.clock(nav.now))
                    // The header's room for its text: the bar (the column, or the full width less the margins in two
                    // panes) less its fixed parts and, for Large and Extra Large, the map button.
                    val twoPane = landscapePhone || (w > h && w >= LayoutPlan.TWO_PANE_WIDTH)
                    val tablet = min(w, h) >= LayoutPlan.TABLET_WIDTH && !landscapePhone
                    val bar = if (twoPane) w - 2 * (if (tablet) LayoutPlan.MARGIN_TABLET else LayoutPlan.MARGIN) else column
                    val wraps = { button: Boolean ->
                        val px = with(density) { (bar - HEADER_FIXED - (if (button) 48f else 0f)).dp.toPx() }
                        val titleWraps = measurer.measure(AnnotatedString(title), tStyle, softWrap = false, maxLines = 1).size.width > px
                        val dateWraps = TextFit.headerLines(dates.first, dates.second, dates.third) {
                            measurer.measure(AnnotatedString(it), dStyle, softWrap = false, maxLines = 1).size.width <= px - pill
                        }.size > 1
                        titleWraps to dateWraps
                    }
                    // The lock and spot rows' two columns side by side, or the second under the first (C3.4 #7): the
                    // widest lock ("Locked 360°", "turn 180° right") and this spot, in the row less 14 + 48 + 4 and 12 between.
                    val leadStyle = rowLeadStyle(); val trailStyle = rowTrailStyle(false)
                    val markValue = nav.markText?.let(::spotValue)
                    val twoLines = { l: Layout, value: String, lead: String ->
                        val row = if (twoPane) LayoutPlan.trailingWidth(l, w) else column
                        val px = with(density) { (row - 66f - 12f).dp.toPx() }
                        measurer.measure(AnnotatedString(lead), leadStyle, softWrap = false, maxLines = 1).size.width +
                            measurer.measure(AnnotatedString(value), trailStyle, softWrap = false, maxLines = 1).size.width > px
                    }
                    // The planner clamps the multiplier at 1.3 for the panel; the list estimates with the real one.
                    // Large and Extra Large have the header's map button; Small and Medium gain it when they give up
                    // their map surface for the owner's floor, so the header is measured again with it.
                    val planWith = { l: Layout, button: Boolean ->
                        val (titleWraps, dateWraps) = wraps(button)
                        LayoutPlan.plan(w, h, s, l, fontScale.coerceAtLeast(1f), bigText, locked = locked, hasSpot = nav.markText != null,
                            isLandscapePhone = landscapePhone, statusLines = statusLines, noHeading = noCompass,
                            titleWraps = titleWraps, dateWraps = dateWraps,
                            lockTwoLines = twoLines(l, TextFit.lockParts("Locked 360° · turn 180° right").second ?: "", "Locked\u00A0360°"),
                            spotTwoLines = markValue?.let { twoLines(l, it, SPOT_LABEL) } ?: false)
                    }
                    val planFor = { l: Layout ->
                        val button = l == Layout.LARGE || l == Layout.EXTRA_LARGE
                        planWith(l, button).let { if (it.mapButton != button) planWith(l, it.mapButton) else it }
                    }
                    val plan = planFor(nav.layout)
                    val acts = actions
                    SideEffect { LayoutPlan.last = plan; LayoutPlan.lastWidth = w; LayoutPlan.lastHeight = h; LayoutPlan.lastSafeHeight = s }
                    val spec: AnimationSpec<Dp> = if (reduceMotion) snap<Dp>() else spring<Dp>(stiffness = Spring.StiffnessMediumLow)
                    val dial by animateDpAsState(plan.dial.dp, spec, label = "dial")
                    when {
                        plan.twoPane -> TwoPanes(nav, plan, dial, k, noCompass, acts)
                        plan.list -> ListScreen(nav, plan, dial, k, noCompass, acts)
                        else -> SingleColumn(nav, plan, dial, k, noCompass, acts)
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
    val website: () -> Unit,
)

// ---------- The three arrangements ----------

/**
 * One fixed column (C3.3): the header pinned 8 under the status bar, then every block at the planner's size
 * with the planner's frozen gaps (tokens × k, never widened); step 4's spare sits only over the dial and at the
 * bottom. It sits in a scroll view only as a guard: when the plan fits (it always does at font scales up to 1.3)
 * nothing moves, and if text ever runs taller than planned the last block scrolls into view instead of being
 * cut, with a fade and an indicator to say so.
 */
@Composable
private fun SingleColumn(nav: Navigator, plan: Plan, dial: Dp, k: Float, noCompass: Boolean, a: Actions) {
    val column = plan.column.dp
    val scroll = rememberScrollState()
    val cue = rememberScrollCue(scroll, flash = false)
    Column(
        Modifier.fillMaxSize().scrollCue(scroll, cue).verticalScroll(scroll)
            .padding(top = LayoutPlan.TOP.dp, bottom = plan.bottom.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        HeaderBar(nav, plan, k, a, wrap = false, Modifier.width(column))
        Spacer(Modifier.height(plan.headerGap.dp))
        DialBlock(nav, dial, noCompass)
        Spacer(Modifier.height(plan.dialGap.dp))
        ReadoutGroup(nav, plan, k, noCompass, withLock = !plan.mergedRows, Modifier.width(column))
        if (plan.mergedRows) {
            // The owner's floor's last give-up before the list: the lock and the spot share one 44 row.
            Spacer(Modifier.height(plan.lockGap.dp))
            MergedRow(nav, noCompass, plan.mergedHeight.dp, Modifier.width(column))
        } else if (nav.markText != null) {
            Spacer(Modifier.height(plan.spotGap.dp))
            SpotRow(nav, plan.spotHeight.dp, plan.spotTwoLines, Modifier.width(column))
        }
        Spacer(Modifier.height(plan.gridGap.dp))
        TileGrid(nav, plan, a)
        // Small's map card, or the map tile it shrinks to under the owner's floor (a strip under the compact row).
        if (plan.map == MapMode.CARD || plan.mapStrip) {
            Spacer(Modifier.height(plan.mapGap.dp))
            MapCard(nav, a, Modifier.width(column).height(plan.mapHeight.dp))
        }
    }
}

/**
 * Two panes (C3.4 #5): one full-width header; the dial and readout centred in the leading pane, 12 between
 * them; in the trailing pane the lock row, the spot row, the tile rows at a fixed 80 and the map card with the
 * rest (top-aligned), or, with no card, the pane's stack centred.
 */
@Composable
private fun TwoPanes(nav: Navigator, plan: Plan, dial: Dp, k: Float, noCompass: Boolean, a: Actions) {
    val margin = plan.margin.dp
    Column(Modifier.fillMaxSize().padding(top = LayoutPlan.TOP.dp, bottom = plan.bottom.dp)) {
        HeaderBar(nav, plan, k, a, wrap = false, Modifier.padding(horizontal = margin).fillMaxWidth())
        Spacer(Modifier.height(plan.headerGap.dp))
        Row(Modifier.fillMaxWidth().weight(1f).padding(horizontal = margin)) {
            Box(Modifier.weight(1f).fillMaxHeight(), contentAlignment = Alignment.Center) {
                Column(Modifier.fillMaxWidth().verticalScroll(rememberScrollState()), horizontalAlignment = Alignment.CenterHorizontally) {
                    DialBlock(nav, dial, noCompass)
                    Spacer(Modifier.height(plan.dialGap.dp))
                    ReadoutGroup(nav, plan, k, noCompass, withLock = false, Modifier.fillMaxWidth())
                }
            }
            Spacer(Modifier.width(margin))
            Column(Modifier.width(plan.trailingWidth.dp).fillMaxHeight().verticalScroll(rememberScrollState())) {
                if (plan.trailingTop > 0f) Spacer(Modifier.height(plan.trailingTop.dp))
                if (nav.lock != null && !noCompass) {
                    LockRow(nav, plan.lockHeight.dp, plan.lockTwoLines, Modifier.fillMaxWidth())
                    Spacer(Modifier.height(plan.rowGap.dp))
                }
                if (nav.markText != null) {
                    SpotRow(nav, plan.spotHeight.dp, plan.spotTwoLines, Modifier.fillMaxWidth())
                    Spacer(Modifier.height(plan.rowGap.dp))
                }
                TileGrid(nav, plan, a)
                if (plan.map == MapMode.CARD) {
                    Spacer(Modifier.height(plan.mapGap.dp))
                    MapCard(nav, a, Modifier.fillMaxWidth().height(plan.mapHeight.dp))
                }
            }
        }
    }
}

/**
 * Accessibility text sizes (§3.6, C3.4 #6): the whole screen is one list. The header wraps, the dial is
 * min(C − 48, 36% of H) (less where Position and Elevation would not be whole on the first screen), the lock
 * and the spot share one two-line Targets card, the tiles are 64 high rows (caption leading, value trailing)
 * whose values wrap, and the map card is 200. A 24 fade at the bottom and an indicator shown when the list
 * appears say there is more below (C2.3 #15, C3.4 #20).
 */
@Composable
private fun ListScreen(nav: Navigator, plan: Plan, dial: Dp, k: Float, noCompass: Boolean, a: Actions) {
    val scroll = rememberScrollState()
    val cue = rememberScrollCue(scroll, flash = true)
    Column(
        Modifier.fillMaxSize().scrollCue(scroll, cue).verticalScroll(scroll)
            .padding(start = plan.margin.dp, end = plan.margin.dp, top = LayoutPlan.TOP.dp, bottom = 24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        HeaderBar(nav, plan, k, a, wrap = true, Modifier.fillMaxWidth())
        Spacer(Modifier.height(plan.headerGap.dp))
        DialBlock(nav, dial, noCompass)
        Spacer(Modifier.height(plan.dialGap.dp))
        ReadoutGroup(nav, plan, k, noCompass, withLock = false, Modifier.fillMaxWidth())
        if ((nav.lock != null && !noCompass) || nav.markText != null) {
            Spacer(Modifier.height(plan.spotGap.dp))
            TargetsCard(nav, noCompass, Modifier.fillMaxWidth())
        }
        Spacer(Modifier.height(plan.gridGap.dp))
        TileGrid(nav, plan, a)
        Spacer(Modifier.height(plan.mapGap.dp))
        MapCard(nav, a, Modifier.fillMaxWidth().height(LayoutPlan.LIST_MAP.dp))
    }
}

/** The scroll indicator's strength: shown for a moment when the screen appears ([flash]) and while it scrolls. */
@Composable
private fun rememberScrollCue(state: ScrollState, flash: Boolean): androidx.compose.runtime.State<Float> {
    var shown by remember { mutableStateOf(flash) }
    if (flash) LaunchedEffect(Unit) { delay(1500); shown = false }
    return animateFloatAsState(if (shown || state.isScrollInProgress) 1f else 0f, label = "scroll cue")
}

/**
 * Over a scrolling column (put before verticalScroll, so it draws on the viewport): a 24 dp fade to black at the
 * bottom while there is more below, and a thin indicator at the trailing edge at [cue]'s strength.
 */
private fun Modifier.scrollCue(state: ScrollState, cue: androidx.compose.runtime.State<Float>): Modifier = drawWithContent {
    drawContent()
    val range = state.maxValue
    if (range <= 0 || range == Int.MAX_VALUE) return@drawWithContent
    val fade = 24.dp.toPx()
    if (state.canScrollForward) {
        drawRect(Brush.verticalGradient(listOf(Color.Transparent, Palette.screen), startY = size.height - fade, endY = size.height),
            topLeft = Offset(0f, size.height - fade), size = Size(size.width, fade))
    }
    val alpha = cue.value
    if (alpha > 0f) {
        val thumb = (size.height * size.height / (size.height + range)).coerceAtLeast(24.dp.toPx())
        val y = (size.height - thumb) * state.value / range
        drawRoundRect(white(0.5f * alpha), topLeft = Offset(size.width - 5.dp.toPx(), y), size = Size(3.dp.toPx(), thumb),
            cornerRadius = CornerRadius(1.5.dp.toPx()))
    }
}

// ---------- The header bar ----------

/** The header's fixed parts beside the text: its 14 inset, 8, the sky symbol 20, 4 and the ⋯ menu's 48. */
private const val HEADER_FIXED = 14f + 8f + 20f + 4f + 48f

@Composable private fun titleStyle(): TextStyle = text(17f, FontWeight.SemiBold).copy(lineHeight = 22.sp)
@Composable private fun dateStyle(): TextStyle = text(13f, color = headerSecondary()).copy(lineHeight = 16.sp, fontFeatureSettings = "tnum")
@Composable private fun pillStyle(): TextStyle = text(13f, FontWeight.SemiBold).copy(lineHeight = 16.sp)
@Composable private fun statusStyle(): TextStyle = text(13f, color = secondary()).copy(lineHeight = 18.sp)

/** The Sample pill's width in px: "Sample" at 13 semibold and 8 each side. */
@Composable
private fun pillWidth(measurer: TextMeasurer): Float {
    val style = pillStyle()
    val density = LocalDensity.current
    return measurer.measure(AnnotatedString("Sample"), style, softWrap = false, maxLines = 1).size.width + with(density) { 16.dp.toPx() }
}

/**
 * The header bar (§3.2, C3.4 #4), pinned 8 under the status bar in every layout and state: on the sky, the whole
 * place name, "Maroon Bells, Colorado" (wrapped to a second line rather than shortened or cut), over "Sun, Nov 1
 * · 9:41 AM" and the Sample pill trailing it; then, at a fixed place at the trailing end, the sky's symbol, the
 * map button (Large and Extra Large) and the ⋯ menu. Read as one heading. The time is never cut (C2.3 #14): the
 * date shortens to "Nov 1", then line 2 wraps at the "·". Only at accessibility sizes does the pill move up to
 * line 1.
 */
@Composable
private fun HeaderBar(nav: Navigator, plan: Plan, k: Float, a: Actions, wrap: Boolean, modifier: Modifier) {
    val sun = nav.fix?.let { Sky.sunPosition(nav.now.toDouble(), it.latitude, it.longitude) }
    val night = LocalNight.current
    val pillUp = nav.sample && wrap
    Row(
        // In the list the header takes what its wrapped lines need (the planner's figure is only an estimate there).
        modifier.heightIn(min = (if (wrap) LayoutPlan.headerHeight(k, plan.tablet) else plan.header).dp)
            .skyCard(sun?.altitude, Look.headerShape).padding(start = 14.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(
            Modifier.weight(1f).padding(vertical = 3.dp).semantics(mergeDescendants = true) {
                heading()
                contentDescription = "${nav.title}, ${nav.dateTimeText}${if (nav.sample) ", sample place" else ""}"
            },
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(nav.title, style = titleStyle(), modifier = Modifier.weight(1f, fill = false))
                if (pillUp) {
                    Spacer(Modifier.width(6.dp))
                    SampleBadge(night)
                }
            }
            Row(verticalAlignment = Alignment.CenterVertically) {
                DateTimeLines(nav, Modifier.weight(1f, fill = false))
                if (nav.sample && !pillUp) {
                    Spacer(Modifier.width(6.dp))
                    SampleBadge(night)
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

/** Header line 2: the date and time on one line where they fit, otherwise shortened, then wrapped; never "…". */
@Composable
private fun DateTimeLines(nav: Navigator, modifier: Modifier) {
    val style = dateStyle()
    val measurer = rememberTextMeasurer()
    val time = nav.clock(nav.now)
    val long = nav.dateText()
    val short = nav.dateText(short = true)
    BoxWithConstraints(modifier) {
        val max = constraints.maxWidth
        val lines = remember(long, short, time, max, style) {
            TextFit.headerLines(long, short, time) { measurer.measure(AnnotatedString(it), style, softWrap = false, maxLines = 1).size.width <= max }
        }
        Text(lines.joinToString("\n"), style = style)
    }
}

/**
 * The Sample pill (C3.4 #4, #15): 13 semibold in a 20 high capsule; amber with black text by day, and at night
 * a black capsule with a red outline and red text (white through the screen's red multiply), never red on red.
 */
@Composable
private fun SampleBadge(night: Boolean) {
    val shape = CircleShape
    val m = if (night) Modifier.clip(shape).background(Color.Black).border(1.dp, Color.White, shape)
        else Modifier.clip(shape).background(Palette.notice)
    Text("Sample", style = pillStyle().copy(color = if (night) Color.White else Color.Black), maxLines = 1,
        modifier = m.heightIn(min = 20.dp).padding(horizontal = 8.dp, vertical = 2.dp))
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
            for (l in Layout.entries) LayoutItem(l, l.subtitle, nav.layout == l, night) { nav.setLayout(l); open = false }
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
            // The footer the Mac and iPad showed in two panes lives here on every layout (C2.3 #8).
            Item("Made by Bradley Cowdrey ↗", night) { a.website(); open = false }
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

/**
 * A layout in the menu (§4.4): its symbol, its name over a one-line subtitle that says what changes (C3.2 #2:
 * "Compass + big map", "Balanced · map tile", "Bigger compass · map in header", "Biggest compass · one row"),
 * and a check on the current one.
 */
@Composable private fun LayoutItem(layout: Layout, result: String, on: Boolean, night: Boolean, onClick: () -> Unit) =
    DropdownMenuItem(
        text = {
            Column {
                Text(layout.title, style = text(15f, color = Color.White.night(night)))
                Text(result, style = text(13f, color = menuSecondary(night)).copy(fontFeatureSettings = "tnum"))
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

// ---------- The dial, the readout, the status line and the lock row ----------

@Composable
private fun DialBlock(nav: Navigator, side: Dp, noCompass: Boolean) {
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
    Box(Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
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

/**
 * The readout, the status line (read with it) 6 × k below and, when a bearing is locked and [withLock], the lock
 * row 8 × k below that (C3.2 #1). Status stays centred; the lock row is a full-width two-column row.
 */
@Composable
private fun ReadoutGroup(nav: Navigator, plan: Plan, k: Float, noCompass: Boolean, withLock: Boolean, modifier: Modifier) {
    Column(modifier, horizontalAlignment = Alignment.CenterHorizontally) {
        Column(Modifier.fillMaxWidth().semantics(mergeDescendants = true) {}) {
            Readout(nav, plan.headingSize, noCompass)
            Spacer(Modifier.height(plan.statusGap.dp))
            StatusLine(nav, plan.statusLines, noCompass)
        }
        if (withLock && nav.lock != null && !noCompass) {
            Spacer(Modifier.height(plan.lockGap.dp))
            LockRow(nav, plan.lockHeight.dp, plan.lockTwoLines, Modifier.fillMaxWidth())
        }
    }
}

/**
 * "228° SW", or with no heading the no-heading readout (C3.2 #3): a dash drawn as a shape, not a glyph, a rounded
 * bar 0.5 em × 0.08 em at white 40%, in an inline placeholder that is cap height tall and stands on the baseline,
 * so the bar's centre is on the digits' cap-height midline whatever the font does with "—"; then "°" at the same
 * size and weight, where it sits after "228". TalkBack hears "Heading unavailable". The line box is trimmed to the
 * digits' cap height, so the 12 above the readout runs from the dial's edge to the digits (C2.2 #3).
 */
@Composable
private fun Readout(nav: Navigator, baseSize: Float, noCompass: Boolean) {
    val h = nav.heading
    // The number follows the font size only up to 1.3 times, like the layout's heights.
    val density = LocalDensity.current
    val fs = density.fontScale
    val sz = if (fs > LayoutPlan.MAX_K) baseSize * LayoutPlan.MAX_K / fs else baseSize
    // Tabular figures, so the number doesn't jiggle as it changes. Light in Two Degrees; Inter has no Light here, so Normal.
    val faint = white(Op.NO_HEADING)
    val big = text(sz, FontWeight.Normal, if (h == null) faint else Color.White)
        .copy(letterSpacing = (-2).sp, lineHeight = (sz * LayoutPlan.READOUT_LINE).sp, fontFeatureSettings = "tnum")
    val measurer = rememberTextMeasurer()
    // From the top of the line box to the top of the digits.
    val trim = remember(big, density) {
        val baseline = measurer.measure(AnnotatedString("0"), big).firstBaseline
        with(density) { (baseline - (sz * LayoutPlan.CAP_HEIGHT).sp.toPx()).roundToInt().coerceAtLeast(0) }
    }
    Row(
        Modifier.fillMaxWidth()
            .layout { measurable, constraints ->
                val p = measurable.measure(constraints)
                val t = trim.coerceAtMost(p.height)
                layout(p.width, p.height - t) { p.place(0, -t) }
            }
            .then(if (h == null) Modifier.clearAndSetSemantics { contentDescription = LayoutPlan.NO_HEADING_SPOKEN } else Modifier),
        horizontalArrangement = Arrangement.Center,
    ) {
        if (h == null) {
            val dash = "dash"
            // The placeholder: the bar's width and a little air before "°", cap height tall, on the baseline.
            val air = 0.08f
            val content = buildAnnotatedString { appendInlineContent(dash, "\u2014"); append("°") }
            val inline = mapOf(dash to InlineTextContent(
                Placeholder((LayoutPlan.DASH_WIDTH + air).em, LayoutPlan.CAP_HEIGHT.em, PlaceholderVerticalAlign.AboveBaseline),
            ) {
                Canvas(Modifier.fillMaxSize()) {
                    // In the placeholder's own units: it is CAP_HEIGHT em tall, so one em is this many px.
                    val em = size.height / LayoutPlan.CAP_HEIGHT
                    val bar = LayoutPlan.DASH_HEIGHT * em
                    val wide = LayoutPlan.DASH_WIDTH * em
                    drawRoundRect(faint, topLeft = Offset((size.width - wide) / 2f, (size.height - bar) / 2f),
                        size = Size(wide, bar), cornerRadius = CornerRadius(bar / 2f))
                }
            })
            Text(content, style = big, inlineContent = inline, modifier = Modifier.alignByBaseline())
        } else {
            Text("${Math.round(h) % 360}°", style = big, modifier = Modifier.alignByBaseline())
            Spacer(Modifier.width(10.dp))
            Text(Geo.point(h), style = text(sz / 2, FontWeight.Medium, secondary()),
                modifier = Modifier.alignByBaseline().widthIn(min = (sz * 1.1f).dp))
        }
    }
}

/**
 * The status line (§3.2): "True north · 8° E declination · ±8° accuracy", on as many lines as the planner keeps
 * for it ([lines], measured), breaking only after a dot. Warnings in amber take its place; with no compass, "No
 * compass · position, sun and map still work" within C − 32 (C3.2 #3: the only line under the dash). It wraps
 * rather than end in "…".
 */
@Composable
private fun StatusLine(nav: Navigator, lines: Int, noCompass: Boolean) {
    val (line, spoken) = status(nav, noCompass)
    Text(line, style = statusStyle(), textAlign = TextAlign.Center,
        // As many lines as the planner keeps for it, so the blocks under it stay where it put them.
        minLines = lines.coerceAtLeast(1),
        modifier = Modifier.fillMaxWidth().padding(horizontal = if (noCompass) 16.dp else 0.dp).heightIn(min = 18.dp).semantics {
            contentDescription = spoken
            // Said once, politely, when the phone turns out to have no compass.
            if (noCompass) liveRegion = LiveRegionMode.Polite
        })
}

private fun status(nav: Navigator, noCompass: Boolean): Pair<AnnotatedString, String> {
    val warn = SpanStyle(color = Palette.notice, fontWeight = FontWeight.SemiBold)
    return when {
        noCompass -> dotted(listOf("No compass", "position, sun and map still work")) to
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
 * The lock row (C3.4 #7), one component on both ports: 52 high, maroon (#3D2128, a 1 dp #5A2C38 edge; red at
 * night through the multiply), "Locked 240°" leading at 17 regular and "turn 12° right" trailing at 17
 * semibold, at least 12 apart, with no-break spaces inside each value so neither splits; ✕ 18 dp in a 48 dp
 * target 4 in from the trailing edge. With [twoLines] (accessibility sizes) the cue drops to a second line at 15.
 */
@Composable
private fun LockRow(nav: Navigator, height: Dp, twoLines: Boolean, modifier: Modifier) {
    Box(modifier.clip(Look.shape).background(Palette.lockFill).border(Look.stroke, Palette.lockStroke, Look.shape)) {
        LockLine(nav, height, twoLines)
    }
}

@Composable
private fun LockLine(nav: Navigator, height: Dp, twoLines: Boolean) {
    val l = nav.lock ?: return
    val label = nav.lockText ?: "Locked ${Math.round(l) % 360}°"
    val (locked, cue) = TextFit.lockParts(label)
    val spoken = label.replace("°", " degrees").replace(" · ", ", ")
    Row(
        Modifier.fillMaxWidth().heightIn(min = height)
            .semantics(mergeDescendants = true) {
                contentDescription = spoken
                customActions = listOf(CustomAccessibilityAction("Unlock") { nav.lock = null; true })
            }
            .padding(start = 14.dp, end = 4.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        TwoColumns(locked, cue, twoLines, Modifier.weight(1f))
        CloseButton("Unlock the bearing") { nav.lock = null }
    }
}

/**
 * The lock and spot rows' two columns: [lead] at 17 regular, [trail] at 17 semibold pushed to the trailing edge
 * with 12 or more between; with [twoLines], [trail] under [lead] at 15.
 */
@Composable
private fun TwoColumns(lead: String, trail: String?, twoLines: Boolean, modifier: Modifier) {
    val leadStyle = rowLeadStyle()
    val trailStyle = rowTrailStyle(twoLines)
    if (twoLines || trail == null) {
        Column(modifier.padding(vertical = 6.dp)) {
            Text(lead, style = leadStyle)
            if (trail != null) Text(trail, style = trailStyle)
        }
    } else {
        Row(modifier.padding(vertical = 4.dp), verticalAlignment = Alignment.CenterVertically) {
            Text(lead, style = leadStyle)
            Spacer(Modifier.weight(1f).widthIn(min = 12.dp))
            Text(trail, style = trailStyle, textAlign = TextAlign.End)
        }
    }
}

/**
 * The lock and spot rows merged into one row [height] high (44 at text size 1.0): what the planner gives up last
 * before the list, to keep the dial at 40% of the screen. The lock (maroon) and the spot (tile fill) each take
 * half, or the whole row when there is only one: the label at 15 over the cue or distance at 13, ✕ in a 44 target.
 * The spot half opens the same menu as the spot row.
 */
@Composable
private fun MergedRow(nav: Navigator, noCompass: Boolean, height: Dp, modifier: Modifier) {
    val l = nav.lock?.takeIf { !noCompass }
    val mark = nav.markText
    Row(modifier.height(height), horizontalArrangement = Arrangement.spacedBy(LayoutPlan.ROW_GAP.dp)) {
        if (l != null) {
            val label = nav.lockText ?: "Locked ${Math.round(l) % 360}°"
            val (locked, cue) = TextFit.lockParts(label)
            Row(
                Modifier.weight(1f).fillMaxHeight().clip(Look.shape).background(Palette.lockFill)
                    .border(Look.stroke, Palette.lockStroke, Look.shape)
                    .semantics(mergeDescendants = true) {
                        contentDescription = label.replace("°", " degrees").replace(" · ", ", ")
                        customActions = listOf(CustomAccessibilityAction("Unlock") { nav.lock = null; true })
                    }
                    .padding(start = 12.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                MergedText(locked, cue, Modifier.weight(1f))
                CloseButton("Unlock the bearing", 44.dp) { nav.lock = null }
            }
        }
        if (mark != null) {
            var open by remember { mutableStateOf(false) }
            val night = LocalNight.current
            Box(Modifier.weight(1f).fillMaxHeight()) {
                Row(
                    Modifier.fillMaxSize().clip(Look.shape).frostedTile()
                        .clickable(role = Role.Button, onClickLabel = "Show what you can do with the marked spot") { open = true }
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
                    MergedText(SPOT_LABEL, spotValue(mark), Modifier.weight(1f))
                    CloseButton("Clear the marked spot", 44.dp) { nav.clearMark() }
                }
                DropdownMenu(open, onDismissRequest = { open = false }) {
                    Item("Lock to Spot", night, nav.markBearing != null) { nav.lockToSpot(); open = false }
                    Item("Clear Marked Spot", night) { nav.clearMark(); open = false }
                }
            }
        }
    }
}

/** The merged row's half: [lead] at 15 over [trail] at 13 semibold, each on one line. */
@Composable
private fun MergedText(lead: String, trail: String?, modifier: Modifier) {
    Column(modifier, verticalArrangement = Arrangement.Center) {
        Text(lead, style = text(15f).copy(lineHeight = 18.sp, fontFeatureSettings = "tnum"), softWrap = false, maxLines = 1)
        if (trail != null) Text(trail, style = text(13f, FontWeight.SemiBold, white(Op.BODY)).copy(lineHeight = 16.sp, fontFeatureSettings = "tnum"),
            softWrap = false, maxLines = 1)
    }
}

/**
 * ✕ (C2.3 #18): an 18 dp rounded glyph at full strength (onSurfaceVariant; white at night, which the red
 * multiply leaves at about 5.7:1), centred in a 48 dp target 4 in from the row's trailing edge.
 */
@Composable
private fun CloseButton(label: String, target: Dp = 48.dp, onClick: () -> Unit) {
    val night = LocalNight.current
    Box(
        Modifier.size(target).clip(CircleShape).clickable(role = Role.Button, onClick = onClick)
            .semantics { contentDescription = label },
        contentAlignment = Alignment.Center,
    ) {
        Icon(Icons.Rounded.Close, null, tint = if (night) Color.White else MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.size(18.dp))
    }
}

// ---------- The marked spot ----------

/**
 * The spot row (§3.2, C3.4 #7): the lock row's two-column form on the neutral tile fill, 52 high: "Marked spot"
 * leading, "9.2 mi · 46° NE" trailing, ✕ in a 48 dp target 4 in from the edge. The row opens a small menu: Lock
 * to Spot, Clear Marked Spot.
 */
@Composable
private fun SpotRow(nav: Navigator, height: Dp, twoLines: Boolean, modifier: Modifier) {
    Box(modifier.clip(Look.shape).frostedTile()) { SpotLine(nav, height, twoLines) }
}

/** "Marked spot", with a no-break space. */
private const val SPOT_LABEL = "Marked\u00A0spot"

/** "9.2 mi · 46° NE" with no-break spaces inside "9.2 mi" and "46° NE", so a value never splits; it may break only at the "·". */
private fun spotValue(label: String): String = label.split(" · ").joinToString(" · ") { it.replace(' ', '\u00A0') }

@Composable private fun rowLeadStyle(): TextStyle = text(17f).copy(lineHeight = 22.sp, fontFeatureSettings = "tnum")
@Composable private fun rowTrailStyle(twoLines: Boolean): TextStyle =
    text(if (twoLines) 15f else 17f, FontWeight.SemiBold).copy(lineHeight = (if (twoLines) 20f else 22f).sp, fontFeatureSettings = "tnum")

@Composable
private fun SpotLine(nav: Navigator, height: Dp, twoLines: Boolean) {
    val label = nav.markText ?: return
    var open by remember { mutableStateOf(false) }
    val night = LocalNight.current
    val value = spotValue(label)
    Box(Modifier.fillMaxWidth()) {
        Row(
            Modifier.fillMaxWidth().heightIn(min = height)
                .clickable(role = Role.Button, onClickLabel = "Show what you can do with the marked spot") { open = true }
                .semantics(mergeDescendants = true) {
                    contentDescription = spotSpoken(nav)
                    customActions = listOf(
                        CustomAccessibilityAction("Lock to Spot") { nav.lockToSpot(); true },
                        CustomAccessibilityAction("Clear") { nav.clearMark(); true },
                    )
                }
                .padding(start = 14.dp, end = 4.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            TwoColumns(SPOT_LABEL, value, twoLines, Modifier.weight(1f))
            CloseButton("Clear the marked spot") { nav.clearMark() }
        }
        DropdownMenu(open, onDismissRequest = { open = false }) {
            Item("Lock to Spot", night, nav.markBearing != null) { nav.lockToSpot(); open = false }
            Item("Clear Marked Spot", night) { nav.clearMark(); open = false }
        }
    }
}

/**
 * Accessibility sizes (C3.4 #6): the lock and the marked spot in one "Targets" card, each on two lines (the cue
 * or the distance under the label at 15), a rule between.
 */
@Composable
private fun TargetsCard(nav: Navigator, noCompass: Boolean, modifier: Modifier) {
    val locked = nav.lock != null && !noCompass
    Column(modifier.clip(Look.shape).frostedTile()) {
        if (locked) {
            Box(Modifier.fillMaxWidth().background(Palette.lockFill)) { LockLine(nav, LayoutPlan.LOCK.dp, twoLines = true) }
        }
        if (locked && nav.markText != null) HorizontalDivider(color = Palette.tileStroke)
        if (nav.markText != null) SpotLine(nav, LayoutPlan.SPOT.dp, twoLines = true)
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
 * The tile grid (§3.2, C3.3): the planner's rows, whose widths and 8 dp gaps add up to the column, rows
 * [Plan.rowGap] apart. Full (Medium): Position (2u) | Elevation, then Sun | Moon | Map (Sun | Moon at half each
 * when the map is a card). Quad (Large): Position | Elevation, Sun | Moon at half each. Compact (Small, Extra
 * Large): Position (C − 16 − 2w) | Elevation (w) | Sun (w), w = max(104, 0.27 C), with the moon in the Sun
 * caption. In the scrolling list, 64 high rows with the caption leading and the value trailing. Tiles in a row
 * share the tallest one's height, at least the planned height. Before a location is allowed, the request for it
 * takes the grid's place.
 */
@Composable
private fun TileGrid(nav: Navigator, plan: Plan, a: Actions) {
    val width = plan.column
    if (nav.fix == null && nav.access != Access.ALLOWED) {
        val gridHeight = LayoutPlan.gridHeight(plan.grid, plan.tile, plan.gridColumns, plan.k)
        AskForLocation(nav.access == Access.DENIED, a.useLocation, a.openSettings,
            Modifier.width(width.dp).heightIn(min = if (plan.grid == GridMode.ROWS) 0.dp else gridHeight.dp))
        return
    }
    var positionMenu by remember { mutableStateOf(false) }
    val tick = rememberTick()
    val fix = nav.fix
    val stale = !nav.sample && fix != null && tick - fix.time > 120_000
    val night = LocalNight.current
    val compact = plan.grid == GridMode.COMPACT
    val listRow = plan.grid == GridMode.ROWS
    Box(Modifier.width(width.dp)) {
        Column(verticalArrangement = Arrangement.spacedBy(plan.rowGap.dp)) {
            for (row in plan.rows) {
                TileRow(row.widths, width, plan.tile, mapIndex = row.tiles.indexOf(TileKind.MAP)) {
                    row.tiles.forEachIndexed { i, kind ->
                        // The value's room: the tile less its 12 insets; in a list row, the trailing 60%.
                        val inner = (if (listRow) (row.widths[i] - 36f) * 0.6f else row.widths[i] - 24f).coerceAtLeast(1f).dp
                        when (kind) {
                            TileKind.POSITION -> PositionTile(nav, stale, inner, compact, listRow, { positionMenu = true }, a)
                            TileKind.ELEVATION -> ElevationTile(nav, stale, inner, listRow, a)
                            TileKind.SUN -> SunTile(nav, inner, compact, listRow, a)
                            TileKind.MOON -> MoonTile(nav, inner, listRow, a)
                            TileKind.MAP -> MapTile(nav, a)
                        }
                    }
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
 * One row of tiles at the given widths in dp, 8 apart, exactly [total] wide (C2.2 #1: the widths and gaps add
 * up to the column; checked in debug builds), all as tall as the tallest (at least [minHeight]): a tile grows
 * taller before anything in it is cut. Every width but the last rounds to whole pixels and the last takes what
 * is left, so the row never runs past the column. The map tile ([mapIndex]) takes the row's height without
 * being asked for its own (a map has none).
 */
@Composable
private fun TileRow(widths: List<Float>, total: Float, minHeight: Float, mapIndex: Int = -1, content: @Composable () -> Unit) {
    if (BuildConfig.DEBUG) {
        val sum = widths.sum() + LayoutPlan.ROW_GAP * (widths.size - 1)
        check(abs(sum - total) < 0.5f) { "Tile row $widths adds up to $sum, not $total" }
    }
    ComposeLayout(content) { measurables, _ ->
        val gap = LayoutPlan.ROW_GAP.dp.roundToPx()
        val totalPx = total.dp.roundToPx()
        val ws = widths.map { it.dp.roundToPx() }.toMutableList()
        if (ws.isNotEmpty()) ws[ws.size - 1] = (totalPx - (ws.sum() - ws.last()) - gap * (ws.size - 1)).coerceAtLeast(0)
        var h = minHeight.dp.roundToPx()
        measurables.forEachIndexed { i, m -> if (i != mapIndex && i < ws.size) h = max(h, m.maxIntrinsicHeight(ws[i])) }
        val placeables = measurables.mapIndexed { i, m -> m.measure(Constraints.fixed(ws.getOrElse(i) { 0 }, h)) }
        layout(totalPx, h) {
            var x = 0
            placeables.forEachIndexed { i, p -> p.placeRelative(x, 0); x += ws.getOrElse(i) { 0 } + gap }
        }
    }
}

/**
 * One tile (§3.2, C3.4 #13), the widgets' pattern: the caption (11, caps, tracking 0.6, secondary, text only) pinned
 * 10 from the top and the value block (17, tabular, over a 13 secondary line) with its last baseline 10 from the
 * bottom, 12 in at the sides, so a grown tile is never half empty at the bottom. With [listRow] (the scrolling
 * list) the caption leads and the value block trails, centred in a 64 high row. TalkBack reads it as one
 * element ([spoken]).
 */
@Composable
private fun Tile(caption: @Composable () -> Unit, spoken: String, click: Modifier = Modifier, listRow: Boolean = false,
                 content: @Composable ColumnScope.() -> Unit) {
    // Clipped before the click, so the ripple keeps the rounded corners.
    val base = Modifier.fillMaxSize().clip(Look.shape).then(click).frostedTile()
        .semantics(mergeDescendants = true) { contentDescription = spoken }
        .padding(horizontal = Look.tilePaddingH, vertical = Look.tilePaddingV)
    if (listRow) {
        Row(base, verticalAlignment = Alignment.CenterVertically) {
            Box(Modifier.weight(0.4f)) { caption() }
            Spacer(Modifier.width(12.dp))
            Column(Modifier.weight(0.6f), horizontalAlignment = Alignment.End, content = content)
        }
        return
    }
    Column(base) {
        caption()
        Spacer(Modifier.weight(1f))
        content()
    }
}

/**
 * A tile's caption, text only (C3.4 #13): [title] in caps, shrunk to 0.85 and then wrapped rather than cut
 * (POSITION · MGRS in a narrow tile); with [moon], " · ◐ 53%" follows (the compact row's Sun tile, C2.3 #3),
 * the moon drawn for its phase.
 */
@Composable
private fun TileCaption(title: String, inner: Dp, moon: com.bradcowdrey.bearings.MoonPhase? = null) {
    val style = text(Look.TILE_CAPTION, FontWeight.SemiBold, secondary())
        .copy(letterSpacing = Look.TILE_CAPTION_TRACKING.sp, lineHeight = Look.TILE_CAPTION_LINE.sp)
    if (moon == null) {
        FitWrapText(title.uppercase(), style, inner)
        return
    }
    val glyph = "moon"
    val caption = buildAnnotatedString {
        append(title.uppercase()); append(" · ")
        appendInlineContent(glyph, "◐")
        append(" ${Geo.jsRound(moon.fraction * 100)}%")
    }
    val inline = mapOf(glyph to InlineTextContent(Placeholder(1.em, 1.em, PlaceholderVerticalAlign.TextCenter)) {
        Canvas(Modifier.fillMaxSize()) { moonGlyph(Offset(size.width / 2, size.height / 2), size.minDimension / 2, moon.phase, 1f) }
    })
    // Like every other caption it shrinks (to 0.85) before it wraps: at text size 1.3 "SUN · ◐ 53%" is a few dp
    // wider than a 104 tile, and a second caption line would make the row taller than planned.
    val measurer = rememberTextMeasurer()
    val density = LocalDensity.current
    val max = with(density) { inner.roundToPx() }.coerceAtLeast(1)
    val probe = "${title.uppercase()} · M ${Geo.jsRound(moon.fraction * 100)}%"
    val scale = remember(probe, max, style, density) { fitScale(measurer, probe, style, max) ?: Look.MIN_TEXT_SCALE }
    Text(caption, style = style.copy(fontSize = style.fontSize * scale), inlineContent = inline)
}

@Composable
private fun valueStyle(dim: Boolean = false, size: Float = Look.TILE_VALUE, weight: FontWeight = FontWeight.Medium): TextStyle =
    text(size, weight, if (dim) secondary() else Color.White)
        .copy(lineHeight = (size + Look.TILE_VALUE_LINE - Look.TILE_VALUE).sp, fontFeatureSettings = "tnum")

@Composable
private fun secondaryStyle(): TextStyle =
    text(Look.TILE_SECONDARY, color = secondary()).copy(lineHeight = Look.TILE_SECONDARY_LINE.sp, fontFeatureSettings = "tnum")

/** The largest scale from 1 down to 0.85 (in 0.05 steps) at which [value] fits [max] px on one line, or null. */
private fun fitScale(measurer: TextMeasurer, value: String, style: TextStyle, max: Int): Float? {
    var f = 1f
    while (f > Look.MIN_TEXT_SCALE - 0.001f) {
        val w = measurer.measure(AnnotatedString(value), style.copy(fontSize = style.fontSize * f), softWrap = false, maxLines = 1).size.width
        if (w <= max) return f
        f -= 0.05f
    }
    return null
}

/**
 * A value that never ellipsizes (§3.2): it shrinks to fit [width] down to 0.85 of its size, then wraps.
 * Measured with a text measurer rather than BoxWithConstraints, so a row can still ask the tile its height.
 */
@Composable
private fun FitWrapText(value: String, style: TextStyle, width: Dp) {
    val measurer = rememberTextMeasurer()
    val density = LocalDensity.current
    val max = with(density) { width.roundToPx() }.coerceAtLeast(1)
    val scale = remember(value, max, style, density) { fitScale(measurer, value, style, max) ?: Look.MIN_TEXT_SCALE }
    Text(value, style = style.copy(fontSize = style.fontSize * scale), softWrap = true)
}

/**
 * Lines that share one size (C3.4 #12): the largest scale from 1 down to 0.85 at which every line fits [width]
 * (the longer line decides), so "39.09898° N" and "106.94117° W" are never drawn at two sizes; past 0.85 they wrap.
 */
@Composable
private fun FitWrapLines(lines: List<String>, style: TextStyle, width: Dp) {
    val measurer = rememberTextMeasurer()
    val density = LocalDensity.current
    val max = with(density) { width.roundToPx() }.coerceAtLeast(1)
    val scale = remember(lines, max, style, density) {
        TextFit.sharedScale(lines) { fitScale(measurer, it, style, max) ?: Look.MIN_TEXT_SCALE }
    }
    for (line in lines) Text(line, style = style.copy(fontSize = style.fontSize * scale), softWrap = true)
}

/**
 * A sunrise or sunset line (C2.2 #1): "↑ 6:36 AM" shrunk to fit down to 0.85; where even that is too wide, the
 * AM or PM drops to 11 on the same line, and where that is still too wide it wraps under the time ("↑ 6:36"
 * over "AM"). Never cut.
 */
@Composable
private fun SunTime(arrow: String, time: String, style: TextStyle, width: Dp) {
    val measurer = rememberTextMeasurer()
    val density = LocalDensity.current
    val max = with(density) { width.roundToPx() }.coerceAtLeast(1)
    val whole = "$arrow $time"
    val (main, suffix) = remember(time) { TextFit.splitClock(time) }
    val scale = remember(whole, max, style, density) { fitScale(measurer, whole, style, max) }
    if (scale != null || suffix == null) {
        Text(whole, style = style.copy(fontSize = style.fontSize * (scale ?: Look.MIN_TEXT_SCALE)), softWrap = true)
        return
    }
    val small = SpanStyle(fontSize = 11.sp, fontWeight = FontWeight.Medium, color = secondary())
    val first = "$arrow $main"
    val s2 = remember(first, suffix, max, style, density) {
        val tail = measurer.measure(AnnotatedString(" $suffix"), style.merge(small), softWrap = false, maxLines = 1).size.width
        fitScale(measurer, first, style, (max - tail).coerceAtLeast(1)) ?: Look.MIN_TEXT_SCALE
    }
    val shown = buildAnnotatedString {
        append(first)
        append(' ')
        withStyle(small) { append(suffix) }
    }
    Text(shown, style = style.copy(fontSize = style.fontSize * s2), softWrap = true)
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

/**
 * Position: the coordinates in the current format, both lines at one size (15 in the compact row, 17
 * elsewhere); a one-line format (MGRS, Plus Code, UTM) at 20 (17 in the compact row), and the tile never grows
 * for it (C3.4 #12). Tap: the next format. Touch and hold: Copy, Details….
 */
@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun PositionTile(nav: Navigator, stale: Boolean, inner: Dp, compact: Boolean, listRow: Boolean, onLongPress: () -> Unit, a: Actions) {
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
    Tile({ TileCaption("Position · ${shortName(nav.format)}", inner) }, spoken, click, listRow) {
        when (f) {
            is Geo.Formatted.Pair -> FitWrapLines(listOf(f.lat, f.lon), valueStyle(dim = stale, size = if (compact) 15f else Look.TILE_VALUE), inner)
            is Geo.Formatted.Single -> FitWrapText(f.text, valueStyle(dim = stale, size = if (compact) Look.TILE_VALUE else Look.TILE_VALUE_SINGLE), inner)
            null -> Pending("Finding position…")
        }
    }
}

/** "9,587 ft" → "9,587 feet", for TalkBack. */
private fun spokenUnits(s: String) = s.removeSuffix(" ft").let { if (it != s) "$it feet" else s.removeSuffix(" m") + " metres" }

/** Elevation: "9,587 ft" over "2,922 m" (the order follows the units setting). Opens the Details sheet. */
@Composable
private fun ElevationTile(nav: Navigator, stale: Boolean, inner: Dp, listRow: Boolean, a: Actions) {
    val click = Modifier.clickable(role = Role.Button, onClickLabel = "Show the details", onClick = a.details)
    val caption = @Composable { TileCaption("Elevation", inner) }
    when (val e = nav.elevation) {
        is ElevationReading.Value -> {
            val (ft, m) = Geo.elevation(e.metres)
            val first = if (nav.feet) ft else m; val second = if (nav.feet) m else ft
            val spoken = "Elevation, ${spokenUnits(first)}, ${spokenUnits(second)}, ${if (e.fromGps) "from GPS" else "from terrain data"}"
            Tile(caption, spoken, click, listRow) {
                FitWrapText(first, valueStyle(dim = stale), inner)
                Text(second, style = secondaryStyle())
            }
        }
        is ElevationReading.Pending -> {
            val note = if (nav.fix == null) "Finding position…" else e.note.ifBlank { "Looking it up…" }
            Tile(caption, "Elevation, $note", click, listRow) { Pending(note) }
        }
    }
}

/**
 * Sun: "↑ 6:36 AM" over "↓ 5:08 PM" (the phone's 12- or 24-hour clock), or "Up all day" / "Down all day". The
 * caption is text only (C3.4 #13). In the compact row the value is 15 semibold and the caption carries the moon,
 * "SUN · ◐ 53%", so the moon is never dropped (C2.3 #3). Opens the Details sheet, which has the moon in full.
 */
@Composable
private fun SunTile(nav: Navigator, inner: Dp, compact: Boolean, listRow: Boolean, a: Actions) {
    val click = Modifier.clickable(role = Role.Button, onClickLabel = "Show the details", onClick = a.details)
    val phase = nav.moonPhase
    val moonSpoken = if (compact) ". Moon, ${Geo.jsRound(phase.fraction * 100)} percent, ${Sky.phaseName(phase).lowercase()}" else ""
    val caption = @Composable { TileCaption("Sun", inner, moon = if (compact) phase else null) }
    val style = if (compact) valueStyle(size = 15f, weight = FontWeight.SemiBold) else valueStyle()
    val fix = nav.fix
    if (fix == null) {
        Tile(caption, "Sun, not known yet$moonSpoken", click, listRow) { Pending("Finding position…") }
        return
    }
    val times = Sky.sunTimes(nav.now.toDouble(), fix.latitude, fix.longitude)
    val rise = times.sunrise; val set = times.sunset
    if (rise != null && set != null && times.polar == null) {
        val up = nav.clock(rise.toLong()); val down = nav.clock(set.toLong())
        Tile(caption, "Sun, rises $up, sets $down$moonSpoken", click, listRow) {
            SunTime("↑", up, style, inner)
            SunTime("↓", down, style, inner)
        }
    } else {
        val allDay = if (times.polar == com.bradcowdrey.bearings.Polar.DAY) "Up all day" else "Down all day"
        Tile(caption, "Sun, $allDay$moonSpoken", click, listRow) { FitWrapText(allDay, style, inner) }
    }
}

/** Moon: the phase's glyph and "53%" over "Last quarter", its last baseline 10 from the bottom like every tile. Opens the Details sheet. */
@Composable
private fun MoonTile(nav: Navigator, inner: Dp, listRow: Boolean, a: Actions) {
    val phase = nav.moonPhase
    val percent = "${Geo.jsRound(phase.fraction * 100)}%"
    val name = Sky.phaseName(phase)
    Tile({ TileCaption("Moon", inner) }, "Moon, ${Geo.jsRound(phase.fraction * 100)} percent, ${name.lowercase()}",
        Modifier.clickable(role = Role.Button, onClickLabel = "Show the details", onClick = a.details), listRow) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Canvas(Modifier.size(13.dp)) { moonGlyph(Offset(size.width / 2, size.height / 2), size.minDimension / 2, phase.phase, 1f) }
            Spacer(Modifier.width(6.dp))
            Text(percent, style = valueStyle())
        }
        Text(name, style = secondaryStyle())
    }
}

/**
 * Map (one cell, C3.4 #8): a live north-up thumbnail with the heading cone and no controls, its labels at 70%,
 * under one 24 dp bottom scrim band holding "MAP" (11 caps, 10 in) leading and "© OSM" (10) trailing. It is
 * the one caption at the bottom, because it labels an image (C3.4 #13). Tapping it opens the map sheet.
 */
@Composable
private fun MapTile(nav: Navigator, a: Actions) {
    Box(Modifier.fillMaxSize().clip(Look.shape)) {
        MapSnippet(
            nav.fix, nav.trueHeading, follow = false, night = nav.night, speed = null,
            onToggleFollow = {}, onOpen = a.openMap, modifier = Modifier.fillMaxSize(), controls = false, attribution = false,
        )
        Box(Modifier.align(Alignment.BottomStart).fillMaxWidth().height(24.dp).background(Color.Black.copy(alpha = 0.5f))) {
            Text("MAP", style = text(Look.TILE_CAPTION, FontWeight.SemiBold, Color.White)
                .copy(letterSpacing = Look.TILE_CAPTION_TRACKING.sp, lineHeight = Look.TILE_CAPTION_LINE.sp),
                modifier = Modifier.align(Alignment.CenterStart).padding(start = 10.dp))
            Text("© OSM", style = text(10f, FontWeight.Medium, white(Op.STRONG)),
                modifier = Modifier.align(Alignment.CenterEnd).padding(end = 10.dp)
                    .semantics { contentDescription = "Map data from OpenStreetMap contributors" })
        }
        // Over the map, so the tap opens the sheet rather than reaching the map view.
        Box(Modifier.matchParentSize().clickable(role = Role.Button, onClickLabel = "Open the map", onClick = a.map)
            .semantics { contentDescription = "Map, opens full map" })
    }
}

/** The map card: the whole map with its one control stack, the speed chip and the attribution. */
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

/**
 * The map sheet (§3.2, C2.3 #11, C3.4 #16): full height under the status bar, which stays visible (black, its
 * icons light), the map full-bleed under a translucent bar with a 32 × 4 grabber and "Map" 20 and Done 16 on one
 * baseline, with the same control stack, speed chip, heading cone and attribution as the map card, the
 * attribution above the navigation bar.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun MapSheet(nav: Navigator, night: Boolean, openMap: (Fix) -> Unit, onDismiss: () -> Unit) {
    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
        shape = RectangleShape,
        containerColor = Color.Black,
        dragHandle = null,
        contentWindowInsets = { WindowInsets(0, 0, 0, 0) },
    ) {
        val top = WindowInsets.statusBars.asPaddingValues().calculateTopPadding()
        val bottom = WindowInsets.navigationBars.asPaddingValues().calculateBottomPadding()
        // The status bar's band stays black, so the bar (and its icons) is never covered by the map.
        Column(Modifier.fillMaxSize().nightMultiply(night)) {
            Spacer(Modifier.height(top))
            Box(Modifier.fillMaxWidth().weight(1f)) {
                MapSnippet(
                    nav.fix, nav.trueHeading, nav.followHeading, night,
                    speed = nav.speed?.let { Geo.speedText(it, nav.feet) },
                    onToggleFollow = { nav.setFollowHeading(!nav.followHeading) },
                    onOpen = openMap,
                    modifier = Modifier.fillMaxSize(),
                    shape = RectangleShape, edge = false, topInset = 76.dp, bottomInset = bottom,
                )
                Column(Modifier.fillMaxWidth().background(Color.Black.copy(alpha = 0.6f))) {
                    Box(Modifier.fillMaxWidth().padding(top = 8.dp), contentAlignment = Alignment.Center) {
                        Box(Modifier.size(width = 32.dp, height = 4.dp).clip(CircleShape).background(white(Op.FAINT)))
                    }
                    Row(
                        Modifier.fillMaxWidth().padding(start = 16.dp, end = 4.dp, top = 4.dp, bottom = 4.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Text("Map", style = text(20f, FontWeight.SemiBold), modifier = Modifier.weight(1f).alignByBaseline().semantics { heading() })
                        Text("Done", style = text(16f, FontWeight.SemiBold),
                            modifier = Modifier.alignByBaseline().heightIn(min = 48.dp).clip(CircleShape)
                                .clickable(role = Role.Button, onClick = onDismiss).padding(horizontal = 12.dp, vertical = 13.dp))
                    }
                }
            }
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
