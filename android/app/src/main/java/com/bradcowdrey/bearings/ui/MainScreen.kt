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
import androidx.compose.foundation.layout.PaddingValues
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
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.Map
import androidx.compose.material.icons.filled.MoreVert
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
 * Bearings' one screen, the instrument panel of Concept A (docs/REFINE.md "Concept A (chosen)", in docs/LOOK.md's
 * look: black, white type, the sky, frosted tiles). The compass leads: top to bottom, the dial (18 under the status
 * bar, nothing pinned above it), the readout, the status line, the location card (the sky card: place, date and
 * time, the map button where a layout has one, and the ⋯ menu), the Targets card (the locked bearing and the marked
 * spot, only when there is one) and the layout's tiles or map. [LayoutPlan] sizes everything for the chosen layout
 * so nothing is cut and nothing is left empty. Wide windows and phones in landscape use two panes; accessibility
 * text sizes scroll as one list. [showMapSheet] opens the map sheet at launch (CI).
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
                    val bigText = fontScale >= 1.5f
                    val w = maxWidth.value; val s = maxHeight.value; val h = fullHeight.value
                    val noCompass = nav.compass == CompassStatus.UNAVAILABLE && nav.heading == null
                    val locked = nav.lock != null && !noCompass
                    val landscapePhone = w > h && s < LayoutPlan.LANDSCAPE_PHONE
                    // What the planner can't know by itself, measured with the screen's own type: whether the status
                    // line wraps, and whether the location card's place name or date runs to a second line.
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
                    val twoPane = landscapePhone || (w > h && w >= LayoutPlan.TWO_PANE_WIDTH)
                    // The location bar's room for its text: the column (the full width inside the 24 margins in two
                    // panes) less its fixed parts and, where it has one, the map button's slot.
                    val wraps = { _: Layout, button: Boolean ->
                        val card = if (twoPane) w - 2 * LayoutPlan.PANE_MARGIN else column
                        val px = with(density) { (card - LOCATION_FIXED - (if (button) 48f else 0f)).dp.toPx() }
                        val titleWraps = measurer.measure(AnnotatedString(title), tStyle, softWrap = false, maxLines = 1).size.width > px
                        val dateWraps = TextFit.headerLines(dates.first, dates.second, dates.third) {
                            measurer.measure(AnnotatedString(it), dStyle, softWrap = false, maxLines = 1).size.width <= px - pill
                        }.size > 1
                        titleWraps to dateWraps
                    }
                    // Large's sixth tile: Speed while moving, Pressure when still (the sample is still).
                    val moving = !nav.sample && LayoutPlan.sixth(nav.speed) == Sixth.SPEED
                    // The planner clamps the multiplier at 1.3 for the panel; the list uses the real one. Large and
                    // Extra Large keep the map button's slot; Small and Medium gain it when they give up their map
                    // for the owner's floor, so the card is measured again with it.
                    val planWith = { l: Layout, button: Boolean ->
                        val (titleWraps, dateWraps) = wraps(l, button)
                        LayoutPlan.plan(w, h, s, l, fontScale.coerceAtLeast(1f), bigText, locked = locked, hasSpot = nav.markText != null,
                            isLandscapePhone = landscapePhone, statusLines = statusLines, noHeading = noCompass,
                            titleWraps = titleWraps, dateWraps = dateWraps, moving = moving, decimal = nav.format == Geo.Format.DD)
                    }
                    val planFor = { l: Layout ->
                        val button = l == Layout.LARGE || l == Layout.EXTRA_LARGE
                        planWith(l, button).let { if (it.mapButtonSlot != button) planWith(l, it.mapButtonSlot) else it }
                    }
                    val plan = planFor(nav.layout)
                    val acts = actions
                    SideEffect { LayoutPlan.last = plan; LayoutPlan.lastWidth = w; LayoutPlan.lastHeight = h; LayoutPlan.lastSafeHeight = s }
                    val spec: AnimationSpec<Dp> = if (reduceMotion) snap<Dp>() else spring<Dp>(stiffness = Spring.StiffnessMediumLow)
                    val dial by animateDpAsState(plan.dial.dp, spec, label = "dial")
                    when {
                        plan.twoPane -> TwoPanes(nav, plan, dial, noCompass, acts)
                        plan.list -> ListScreen(nav, plan, dial, noCompass, acts)
                        else -> SingleColumn(nav, plan, dial, noCompass, acts)
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
 * One fixed column (A.1, owner's mod): the slim location bar 8 under the status bar, the dial 12 under it
 * ([Plan.dialTop]), then the readout, the status line, the Targets card and the layout's tiles or map, each at the
 * planner's size with the frozen gaps;
 * what step 4 left (24 at most) sits at the bottom. It sits in a scroll view only as a guard: when the plan fits
 * (it always does at font scales up to 1.3) nothing moves, and if text ever runs taller than planned the last
 * block scrolls into view instead of being cut, with a fade and an indicator to say so.
 */
@Composable
private fun SingleColumn(nav: Navigator, plan: Plan, dial: Dp, noCompass: Boolean, a: Actions) {
    val column = plan.column.dp
    val scroll = rememberScrollState()
    val cue = rememberScrollCue(scroll, flash = false)
    Column(
        Modifier.fillMaxSize().scrollCue(scroll, cue).verticalScroll(scroll)
            .padding(top = plan.locationTop.dp, bottom = (plan.endGap + plan.bottomSpare).dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        LocationCard(nav, plan, a, wrap = false, Modifier.width(column))
        Spacer(Modifier.height(plan.barGap.dp))
        DialBlock(nav, dial, noCompass)
        Spacer(Modifier.height(plan.dialGap.dp))
        ReadoutGroup(nav, plan, noCompass, Modifier.width(column))
        Spacer(Modifier.height(plan.cardGap.dp))
        if (plan.targetsRows > 0) {
            TargetsCard(nav, plan, noCompass, Modifier.width(column))
            Spacer(Modifier.height(plan.gridGap.dp))
        }
        PanelGrid(nav, plan, a)
    }
}

/**
 * Two panes (A.8, owner's mod): the location bar (with ⋯) full width 8 under the status bar, as in one column; 12
 * under it the panes: the dial, readout and status line top-aligned in the leading pane; in the trailing pane,
 * top-aligned with the dial, the Targets card, the grid and a map card to the bottom.
 */
@Composable
private fun TwoPanes(nav: Navigator, plan: Plan, dial: Dp, noCompass: Boolean, a: Actions) {
    Column(
        Modifier.fillMaxSize().padding(start = LayoutPlan.PANE_MARGIN.dp, end = LayoutPlan.PANE_MARGIN.dp,
            top = plan.locationTop.dp, bottom = plan.endGap.dp),
    ) {
        LocationCard(nav, plan, a, wrap = false, Modifier.fillMaxWidth())
        Spacer(Modifier.height(plan.barGap.dp))
        Row(Modifier.fillMaxWidth().weight(1f)) {
            Column(Modifier.weight(1f).fillMaxHeight().verticalScroll(rememberScrollState()), horizontalAlignment = Alignment.CenterHorizontally) {
                DialBlock(nav, dial, noCompass)
                Spacer(Modifier.height(plan.dialGap.dp))
                ReadoutGroup(nav, plan, noCompass, Modifier.fillMaxWidth())
            }
            Spacer(Modifier.width(LayoutPlan.PANE_GAP.dp))
            Column(Modifier.width(plan.trailingWidth.dp).fillMaxHeight().verticalScroll(rememberScrollState())) {
                if (plan.targetsRows > 0) {
                    TargetsCard(nav, plan, noCompass, Modifier.fillMaxWidth())
                    Spacer(Modifier.height(plan.gridGap.dp))
                }
                PanelGrid(nav, plan, a)
            }
        }
    }
}

/**
 * Accessibility text sizes (A.7): the whole screen is one list. The location bar (wrapped, first, as everywhere),
 * the dial (still at least 40% of the screen), the readout, the status line, the Targets card with the cue on line 2, one row per tile
 * (caption leading, value trailing) and a 176 Map tile. A 24 fade at the bottom and an indicator shown when the
 * list appears say there is more below.
 */
@Composable
private fun ListScreen(nav: Navigator, plan: Plan, dial: Dp, noCompass: Boolean, a: Actions) {
    val scroll = rememberScrollState()
    val cue = rememberScrollCue(scroll, flash = true)
    val column = plan.column.dp
    Column(
        Modifier.fillMaxSize().scrollCue(scroll, cue).verticalScroll(scroll)
            .padding(top = plan.locationTop.dp, bottom = 24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        LocationCard(nav, plan, a, wrap = true, Modifier.width(column))
        Spacer(Modifier.height(plan.barGap.dp))
        DialBlock(nav, dial, noCompass)
        Spacer(Modifier.height(plan.dialGap.dp))
        ReadoutGroup(nav, plan, noCompass, Modifier.width(column))
        Spacer(Modifier.height(plan.cardGap.dp))
        if (plan.targetsRows > 0) {
            TargetsCard(nav, plan, noCompass, Modifier.width(column))
            Spacer(Modifier.height(plan.gridGap.dp))
        }
        PanelGrid(nav, plan, a)
    }
}

/**
 * The layout's tiles and map: Small's map card with its band along the bottom; otherwise the tile grid, then (iPad
 * Medium, two panes, Small at large text) a map card, or (the list) the 176 Map tile. Before a location is allowed,
 * the request for it takes the whole block's place.
 */
@Composable
private fun PanelGrid(nav: Navigator, plan: Plan, a: Actions) {
    val width = plan.column.dp
    val card = plan.map == MapMode.CARD || plan.list
    if (nav.fix == null && nav.access != Access.ALLOWED) {
        val block = if (plan.grid == GridMode.BAND) plan.mapHeight
            else plan.gridHeight + (if (card) plan.mapGap + plan.mapHeight else 0f)
        AskForLocation(nav.access == Access.DENIED, a.useLocation, a.openSettings,
            Modifier.width(width).heightIn(min = if (plan.list) 0.dp else block.dp))
        return
    }
    if (plan.grid == GridMode.BAND) {
        Box(Modifier.width(width).height(plan.mapHeight.dp).clip(Look.shape)) {
            MapCard(nav, a, Modifier.fillMaxSize(), bottomInset = plan.tile.dp)
            Band(nav, plan, a, Modifier.align(Alignment.BottomCenter).fillMaxWidth().height(plan.tile.dp))
        }
        return
    }
    TileGrid(nav, plan, a)
    if (plan.list) {
        Spacer(Modifier.height(plan.mapGap.dp))
        Box(Modifier.width(width).height(plan.mapHeight.dp)) { MapTile(nav, a, scrim = 32.dp) }
    } else if (plan.map == MapMode.CARD) {
        Spacer(Modifier.height(plan.mapGap.dp))
        MapCard(nav, a, Modifier.width(width).height(plan.mapHeight.dp))
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

// ---------- The location bar ----------

/**
 * The location bar's fixed parts beside the text: its 12 inset, 8, the sky glyph's 24 slot, ⋯'s 48 slot and 2
 * trailing (so ⋯'s 28 circle sits 12 from the bar's edge). The map button, where there is one, adds its 48 slot.
 */
private const val LOCATION_FIXED = 12f + 8f + 24f + 48f + 2f
/** A button's slot in the bar: 48 wide, its 28 circle centred, its 48 × 48 touch area overhanging the 40 bar. */
private const val BAR_BUTTON_SLOT = 48f
/** The bar's corners (the owner's mod: radius 12). */
private val BAR_SHAPE = RoundedCornerShape(12.dp)

@Composable private fun titleStyle(): TextStyle = text(15f, FontWeight.SemiBold).copy(lineHeight = LayoutPlan.TITLE_LINE.sp)
@Composable private fun dateStyle(): TextStyle = text(12f, color = headerSecondary()).copy(lineHeight = LayoutPlan.DATE_LINE.sp, fontFeatureSettings = "tnum")
@Composable private fun pillStyle(): TextStyle = text(10f, FontWeight.SemiBold).copy(lineHeight = 12.sp)
@Composable private fun statusStyle(): TextStyle = text(13f, color = secondary()).copy(lineHeight = 18.sp)

/** The Sample pill's width in px: "Sample" at 10 semibold and 6 each side. */
@Composable
private fun pillWidth(measurer: TextMeasurer): Float {
    val style = pillStyle()
    val density = LocalDensity.current
    return measurer.measure(AnnotatedString("Sample"), style, softWrap = false, maxLines = 1).size.width + with(density) { 12.dp.toPx() }
}

/**
 * The location bar (A.2 with the owner's mod): first on the screen in every layout, 8 under the status bar (full
 * width in two panes), 40 high with radius 12 on the sky: the whole place name, "Maroon Bells, Colorado" at 15
 * semibold (wrapped to a second line rather than shortened or cut), over "Sun, Nov 1 · 9:41 AM" at 12, white 75%,
 * and the Sample pill (10) trailing it; then, at fixed places at the trailing end, the sky's 16 symbol, the map
 * button (Large and Extra Large; its slot kept but empty in two panes, where a map card shows the map) and the ⋯
 * menu, both 28 circles whose 48 × 48 touch areas overhang the bar. Read as one heading, the buttons after it. The
 * time is never cut: the date shortens to "Nov 1", then line 2 wraps at the "·". At larger text the bar grows to fit.
 * Only at accessibility sizes does the pill move up to line 1.
 */
@Composable
private fun LocationCard(nav: Navigator, plan: Plan, a: Actions, wrap: Boolean, modifier: Modifier) {
    val sun = nav.fix?.let { Sky.sunPosition(nav.now.toDouble(), it.latitude, it.longitude) }
    val night = LocalNight.current
    val pillUp = nav.sample && wrap
    Row(
        // In the list the bar takes what its wrapped lines need (the planner's figure is only a minimum there). The
        // sky is drawn, not clipped, so the buttons' 48 touch areas can reach past the bar's 40.
        modifier.heightIn(min = plan.location.dp).background(SkyTone.brush(sun?.altitude), BAR_SHAPE).padding(start = 12.dp, end = 2.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(
            Modifier.weight(1f).padding(vertical = LayoutPlan.BAR_PAD.dp).semantics(mergeDescendants = true) {
                heading()
                contentDescription = "${nav.title}, ${nav.dateTimeText.replace(" · ", ", ")}${if (nav.sample) ", sample data" else ""}"
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
        Box(Modifier.width(24.dp), contentAlignment = Alignment.Center) {
            Icon(skyIcon(sun?.altitude, sun?.azimuth), null, tint = white(Op.BODY), modifier = Modifier.size(16.dp))
        }
        when {
            plan.mapButton -> HeaderButton(Icons.Filled.Map, "Map", "Open the map", a.map)
            plan.mapButtonSlot -> Spacer(Modifier.width(BAR_BUTTON_SLOT.dp))
        }
        MenuButton(nav, night, a)
    }
}

/**
 * A bar button's slot: 48 wide and only 28 high in the bar's layout (so the bar stays 40), with its 48 × 48 touch
 * area centred on it (10 past the 28 slot, so 4 past the 40 bar above and below). Nothing clips the bar, so the overhang is hit.
 */
private fun Modifier.barButtonSlot(): Modifier = layout { measurable, _ ->
    val touch = BAR_BUTTON_SLOT.dp.roundToPx()
    val circle = 28.dp.roundToPx()
    val p = measurable.measure(Constraints.fixed(touch, touch))
    layout(touch, circle) { p.place(0, (circle - touch) / 2) }
}

/** Line 2: the date and time on one line where they fit, otherwise shortened, then wrapped; never "…". */
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
        Text(lines.joinToString("\n").replace(time, TextFit.time(time)), style = style)
    }
}

/**
 * The Sample pill (A.2): 12 semibold in a 20 high capsule, 8 each side; amber with black text by day, and at night
 * a black capsule with a white outline and white text (red through the screen's multiply), never red on red.
 */
@Composable
private fun SampleBadge(night: Boolean) {
    val shape = CircleShape
    val m = if (night) Modifier.clip(shape).background(Color.Black).border(1.5.dp, Color.White, shape)
        else Modifier.clip(shape).background(Palette.notice)
    Text("Sample", style = pillStyle().copy(color = if (night) Color.White else Color.Black), maxLines = 1,
        modifier = m.heightIn(min = 14.dp).padding(horizontal = 6.dp, vertical = 1.dp))
}

/** The sun by day, sunrise or sunset in twilight, the moon at night, a pin before a fix (SkyTone.phase). */
private fun skyIcon(altitude: Double?, azimuth: Double?): ImageVector = when (SkyTone.phase(altitude, azimuth)) {
    SkyTone.Phase.DAY -> Icons.Filled.WbSunny
    SkyTone.Phase.TWILIGHT_MORNING, SkyTone.Phase.TWILIGHT_EVENING -> Icons.Filled.WbTwilight
    SkyTone.Phase.NIGHT -> Icons.Filled.NightsStay
    SkyTone.Phase.UNKNOWN -> Icons.Filled.LocationOn
}

/** A faint white 28 dp circle with a 48 × 48 touch target that overhangs the bar, as the ⋯ menu. */
@Composable
private fun HeaderButton(icon: ImageVector, label: String, clickLabel: String, onClick: () -> Unit) {
    Box(
        Modifier.barButtonSlot().clip(CircleShape).clickable(role = Role.Button, onClickLabel = clickLabel, onClick = onClick)
            .semantics { contentDescription = label },
        contentAlignment = Alignment.Center,
    ) {
        Box(Modifier.size(28.dp).clip(CircleShape).background(Palette.chipOff), contentAlignment = Alignment.Center) {
            Icon(icon, null, tint = Color.White, modifier = Modifier.size(18.dp))
        }
    }
}

/** The ⋯ menu (more_vert), at the trailing end of the location bar on every layout, with everything Bearings can do or change. */
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
            Modifier.barButtonSlot().clip(CircleShape).clickable(role = Role.Button, onClickLabel = "Open the menu") { open = true }
                .semantics { contentDescription = "Settings and more" },
            contentAlignment = Alignment.Center,
        ) {
            Box(Modifier.size(28.dp).clip(CircleShape).background(Palette.chipOff), contentAlignment = Alignment.Center) {
                Icon(Icons.Filled.MoreVert, null, tint = Color.White, modifier = Modifier.size(18.dp))
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

// ---------- The dial, the readout and the status line ----------

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
 * The readout in its planned slot ([Plan.readout]) and the status line 6 × k below (read with it). The slot keeps
 * its height with no heading too, so nothing below it moves.
 */
@Composable
private fun ReadoutGroup(nav: Navigator, plan: Plan, noCompass: Boolean, modifier: Modifier) {
    Column(modifier.semantics(mergeDescendants = true) {}, horizontalAlignment = Alignment.CenterHorizontally) {
        Box(Modifier.fillMaxWidth().height(plan.readout.dp), contentAlignment = Alignment.TopCenter) {
            Readout(nav, plan.headingSize, noCompass)
        }
        Spacer(Modifier.height(plan.statusGap.dp))
        StatusLine(nav, plan.statusLines, noCompass)
    }
}

/**
 * "228° SW", exactly as before (Inter at Normal weight, tabular, the point in secondary), or with no heading the
 * words "No heading" (A.2): 34 sp semibold on a 40 line, tracking −0.2, centred, white 55%. TalkBack hears "Heading
 * unavailable". Each line box is trimmed to the cap height, so the 12 above runs from the dial's edge to the ink.
 */
@Composable
private fun Readout(nav: Navigator, baseSize: Float, noCompass: Boolean) {
    val h = nav.heading
    // The number follows the font size only up to 1.3 times, like the layout's heights.
    val density = LocalDensity.current
    val fs = density.fontScale
    val capped = { size: Float -> if (fs > LayoutPlan.MAX_K) size * LayoutPlan.MAX_K / fs else size }
    if (h == null && !noCompass) {
        // Still waiting for a first heading (the compass is there): the slot stays empty, as on Apple.
        Box(Modifier.fillMaxWidth().clearAndSetSemantics { contentDescription = "Heading not known yet" })
        return
    }
    if (h == null) {
        val sz = capped(LayoutPlan.NO_HEADING_SIZE)
        val style = text(sz, FontWeight.SemiBold, white(Op.NO_HEADING))
            .copy(letterSpacing = (-0.2).sp, lineHeight = (LayoutPlan.NO_HEADING_LINE * sz / LayoutPlan.NO_HEADING_SIZE).sp)
        CapTrimmed(style, sz, Modifier.clearAndSetSemantics { contentDescription = LayoutPlan.NO_HEADING_SPOKEN }) { m ->
            Text(LayoutPlan.NO_HEADING_TEXT, style = style, textAlign = TextAlign.Center, maxLines = 1, softWrap = false, modifier = m)
        }
        return
    }
    val sz = capped(baseSize)
    // Tabular figures, so the number doesn't jiggle as it changes. Light in Two Degrees; Inter has no Light here, so Normal.
    val big = text(sz, FontWeight.Normal, Color.White)
        .copy(letterSpacing = (-2).sp, lineHeight = (sz * LayoutPlan.READOUT_LINE).sp, fontFeatureSettings = "tnum")
    CapTrimmed(big, sz, Modifier) { m ->
        Row(m, horizontalArrangement = Arrangement.Center) {
            Text("${Math.round(h) % 360}°", style = big, modifier = Modifier.alignByBaseline())
            Spacer(Modifier.width(10.dp))
            Text(Geo.point(h), style = text(sz / 2, FontWeight.Medium, secondary()),
                modifier = Modifier.alignByBaseline().widthIn(min = (sz * 1.1f).dp))
        }
    }
}

/**
 * [content] full width with the top of its line box trimmed down to the cap height of [style] at [size] (Inter's
 * cap height, 0.7275 em, above the first baseline), so the ink starts where the planner put the slot's top.
 */
@Composable
private fun CapTrimmed(style: TextStyle, size: Float, semantics: Modifier, content: @Composable (Modifier) -> Unit) {
    val density = LocalDensity.current
    val measurer = rememberTextMeasurer()
    val trim = remember(style, density) {
        val baseline = measurer.measure(AnnotatedString("0"), style).firstBaseline
        with(density) { (baseline - (size * LayoutPlan.CAP_HEIGHT).sp.toPx()).roundToInt().coerceAtLeast(0) }
    }
    content(
        Modifier.fillMaxWidth()
            .layout { measurable, constraints ->
                val p = measurable.measure(constraints)
                val t = trim.coerceAtMost(p.height)
                layout(p.width, p.height - t) { p.place(0, -t) }
            }
            .then(semantics),
    )
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
        noCompass -> AnnotatedString(LayoutPlan.NO_COMPASS_STATUS) to
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
            append('\u00A0')
            withStyle(SpanStyle(color = white(Op.FAINT))) { append('·') }
            append(' ')
        }
        append(p.replace(' ', '\u00A0'))
    }
}

// ---------- The Targets card ----------

/** The Targets card's type size by layout (A.2, A.9): Small 16, Medium and Large 17, Extra Large 19, tablet 19. */
private fun targetsSize(plan: Plan): Float = when {
    plan.tablet || plan.layout == Layout.EXTRA_LARGE -> 19f
    plan.layout == Layout.SMALL -> 16f
    else -> 17f
}

/**
 * The Targets card (A.2): one card, only when a bearing is locked or a spot is marked, with only the rows that
 * exist, each [Plan.targetsRowHeight] high. The lock row comes first, on the maroon tint (#3D2128, a 1 dp #5A2C38
 * edge; red at night through the multiply), its top corners rounded (all four when it is alone): the lock glyph,
 * "Locked 240°" leading and "turn 12° right" trailing in semibold, ✕. A 1 dp hairline (white 8%), then the spot row
 * on the card's own fill: the pin, "Marked spot", "9.2 mi · 46° NE", ✕. In the list the cue drops to line 2.
 */
@Composable
private fun TargetsCard(nav: Navigator, plan: Plan, noCompass: Boolean, modifier: Modifier) {
    val locked = nav.lock != null && !noCompass
    val spot = nav.markText != null
    val size = targetsSize(plan)
    val twoLines = plan.list
    val shape = Look.shape
    Column(modifier.clip(shape).background(Palette.tileFill).border(Look.stroke, Palette.tileStroke, shape)) {
        if (locked) {
            val lockShape = if (spot) RoundedCornerShape(topStart = Look.radius, topEnd = Look.radius) else shape
            Box(Modifier.fillMaxWidth().clip(lockShape).background(Palette.lockFill).border(Look.stroke, Palette.lockStroke, lockShape)) {
                LockLine(nav, plan, size, twoLines)
            }
        }
        if (spot) SpotLine(nav, plan, size, twoLines, hairline = locked)
    }
}

/** A Targets row's height: exactly the planned height on the panel, at least it in the list (where the text decides). */
private fun Modifier.targetsRow(plan: Plan): Modifier =
    if (plan.list) heightIn(min = plan.targetsRowHeight.dp) else height(plan.targetsRowHeight.dp)

@Composable
private fun LockLine(nav: Navigator, plan: Plan, size: Float, twoLines: Boolean) {
    val l = nav.lock ?: return
    val label = nav.lockText ?: "Locked ${Math.round(l) % 360}°"
    val (full, cue) = TextFit.lockParts(label)
    // Only below a 320 column does "Locked 240°" shorten to "240°".
    val lead = if (LayoutPlan.shortLock(plan.column)) TextFit.shortLock(full) else full
    val spoken = label.replace("°", " degrees").replace(" · ", ", ")
    Row(
        Modifier.fillMaxWidth().targetsRow(plan)
            .semantics(mergeDescendants = true) {
                contentDescription = spoken
                customActions = listOf(CustomAccessibilityAction("Clear lock") { nav.lock = null; true })
            }
            .padding(start = 16.dp, end = 4.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        RowGlyph(Icons.Filled.Lock)
        TwoColumns(lead, cue, size, twoLines, Modifier.weight(1f), shortLead = TextFit.shortLock(full))
        CloseButton("Clear lock") { nav.lock = null }
    }
}

/** The lock or pin glyph, 14 × 16 at white 85% (90% at night) in an 18 column, 8 before the text. Decorative. */
@Composable
private fun RowGlyph(icon: ImageVector) {
    val night = LocalNight.current
    Box(Modifier.width(18.dp), contentAlignment = Alignment.CenterStart) {
        Icon(icon, null, tint = white(if (night) Op.STRONG else Op.BODY), modifier = Modifier.size(16.dp))
    }
    Spacer(Modifier.width(8.dp))
}

/**
 * A Targets row's two columns: [lead] regular, [trail] semibold pushed to the trailing edge, 12 or more between, at
 * [size]. Values never split or ellipsize: where room runs short the lead scales down to 0.85 first, then (the lock
 * row) takes its short form [shortLead], "240°", and only then does [trail] scale down to 0.85 too. With [twoLines]
 * (the list), [trail] goes under [lead], 3 smaller.
 */
@Composable
private fun TwoColumns(lead: String, trail: String?, size: Float, twoLines: Boolean, modifier: Modifier, shortLead: String? = null) {
    val leadStyle = text(size).copy(lineHeight = (size + 5f).sp, fontFeatureSettings = "tnum")
    val trailStyle = text(if (twoLines) size - 3f else size, FontWeight.SemiBold).copy(lineHeight = (size + 5f).sp, fontFeatureSettings = "tnum")
    if (twoLines || trail == null) {
        Column(modifier.padding(vertical = 6.dp)) {
            Text(lead, style = leadStyle)
            if (trail != null) Text(trail, style = trailStyle)
        }
        return
    }
    val measurer = rememberTextMeasurer()
    val density = LocalDensity.current
    BoxWithConstraints(modifier) {
        val max = constraints.maxWidth
        val gap = with(density) { 12.dp.roundToPx() }
        val (shown, leadScale, trailScale) = remember(lead, shortLead, trail, max, leadStyle, trailStyle, density) {
            fun w(t: String, st: TextStyle, f: Float) =
                measurer.measure(AnnotatedString(t), st.copy(fontSize = st.fontSize * f), softWrap = false, maxLines = 1).size.width
            val room = (max - w(trail, trailStyle, 1f) - gap).coerceAtLeast(1)
            val whole = fitScale(measurer, lead, leadStyle, room)
            val short = shortLead ?: lead
            val shortScale = if (whole == null) fitScale(measurer, short, leadStyle, room) else null
            when {
                whole != null -> Triple(lead, whole, 1f)
                shortScale != null -> Triple(short, shortScale, 1f)
                else -> Triple(short, Look.MIN_TEXT_SCALE, fitScale(measurer, trail, trailStyle,
                    (max - w(short, leadStyle, Look.MIN_TEXT_SCALE) - gap).coerceAtLeast(1)) ?: Look.MIN_TEXT_SCALE)
            }
        }
        Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
            Text(shown, style = leadStyle.copy(fontSize = leadStyle.fontSize * leadScale), softWrap = false, maxLines = 1)
            Spacer(Modifier.weight(1f).widthIn(min = 12.dp))
            Text(trail, style = trailStyle.copy(fontSize = trailStyle.fontSize * trailScale), softWrap = false, maxLines = 1, textAlign = TextAlign.End)
        }
    }
}

/**
 * ✕: a 16 dp rounded glyph at white 60% (90% at night), centred in a 48 dp target 4 in from the row's trailing edge.
 * The target may overlap the hairline.
 */
@Composable
private fun CloseButton(label: String, target: Dp = 48.dp, onClick: () -> Unit) {
    val night = LocalNight.current
    Box(
        Modifier.size(target).clip(CircleShape).clickable(role = Role.Button, onClick = onClick)
            .semantics { contentDescription = label },
        contentAlignment = Alignment.Center,
    ) {
        Icon(Icons.Rounded.Close, null, tint = white(if (night) Op.NIGHT_SECONDARY else Op.CAPTION), modifier = Modifier.size(16.dp))
    }
}

/** "Marked spot", with a no-break space. */
private const val SPOT_LABEL = "Marked\u00A0spot"

/** "9.2 mi · 46° NE" with no-break spaces inside "9.2 mi" and "46° NE", so a value never splits; it may break only at the "·". */
private fun spotValue(label: String): String = label.split(" · ").joinToString(" · ") { it.replace(' ', '\u00A0') }

/** The spot row: the pin, "Marked spot", "9.2 mi · 46° NE", ✕; tapping it opens Lock to Spot and Clear Marked Spot. */
@Composable
private fun SpotLine(nav: Navigator, plan: Plan, type: Float, twoLines: Boolean, hairline: Boolean) {
    val label = nav.markText ?: return
    var open by remember { mutableStateOf(false) }
    val night = LocalNight.current
    val value = spotValue(label)
    Box(
        Modifier.fillMaxWidth().drawWithContent {
            drawContent()
            if (hairline) drawRect(white(Op.TILE), size = Size(size.width, 1.dp.toPx()))
        },
    ) {
        Row(
            Modifier.fillMaxWidth().targetsRow(plan)
                .clickable(role = Role.Button, onClickLabel = "Show what you can do with the marked spot") { open = true }
                .semantics(mergeDescendants = true) {
                    contentDescription = spotSpoken(nav)
                    customActions = listOf(
                        CustomAccessibilityAction("Lock to Spot") { nav.lockToSpot(); true },
                        CustomAccessibilityAction("Clear marked spot") { nav.clearMark(); true },
                    )
                }
                .padding(start = 16.dp, end = 4.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            RowGlyph(Icons.Filled.LocationOn)
            TwoColumns(SPOT_LABEL, value, type, twoLines, Modifier.weight(1f))
            CloseButton("Clear marked spot") { nav.clearMark() }
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

// ---------- The tiles ----------

/** A tick every 15 seconds, for "fix age" and dimming a stale fix. */
@Composable
private fun rememberTick(): Long {
    var tick by remember { mutableLongStateOf(System.currentTimeMillis()) }
    LaunchedEffect(Unit) { while (true) { delay(15_000); tick = System.currentTimeMillis() } }
    return tick
}

/**
 * A tile's type ramp (A.2, A.8): caption 11 on a 13 line, values 17 (Large's compact tiles 16), secondary 13, 10 × 12
 * padding; the tablet's regular-width ramp (caption 13, value 22, secondary 15, 12 × 16); the list's rows (caption
 * 15, value 22, secondary 17). [position] is the two Position lines' size.
 */
private data class Ramp(
    val caption: Float, val captionLine: Float, val value: Float, val valueLine: Float, val secondary: Float,
    val secondaryLine: Float, val padH: Dp, val padV: Dp, val position: Float,
)

private fun ramp(plan: Plan): Ramp = when {
    plan.list -> Ramp(15f, 18f, 22f, 26f, 17f, 21f, 16.dp, 12.dp, 22f)
    plan.tablet -> Ramp(13f, 16f, 22f, 26f, 15f, 19f, 16.dp, 12.dp, 22f)
    plan.grid == GridMode.SIX -> Ramp(11f, 13f, 16f, 20f, 13f, 16f, 10.dp, 10.dp, 16f)
    plan.grid == GridMode.QUAD_COMPACT -> Ramp(11f, 13f, 15f, 19f, 13f, 16f, 12.dp, 6.dp, 15f)
    else -> Ramp(Look.TILE_CAPTION, Look.TILE_CAPTION_LINE, Look.TILE_VALUE, Look.TILE_VALUE_LINE, Look.TILE_SECONDARY,
        Look.TILE_SECONDARY_LINE, Look.tilePaddingH, Look.tilePaddingV, 15f)
}

/** Whether the Sun tile's caption carries the moon, "SUN · ◐ 53%": where no Moon tile or section shows it (A.3, A.7). */
private fun sunCarriesMoon(plan: Plan, rowHeight: Float): Boolean = when {
    plan.list || plan.k >= LayoutPlan.TWO_ROW_K - 0.001f -> false
    plan.grid == GridMode.QUAD -> plan.map == MapMode.TILE && rowHeight < LayoutPlan.SUN_MOON_FROM
    else -> plan.grid == GridMode.ROW || plan.grid == GridMode.QUAD_COMPACT || plan.grid == GridMode.BAND
}

/**
 * The tile grid (A.3): the planner's rows, whose widths and 8 dp gaps add up to the column, [Plan.rowGap] apart,
 * row 1 [Plan.tile] and row 2 [Plan.tile2] high. Quad (Medium): Position | Elevation, Sun | Map (Sun | Moon over
 * a map card). Six (Large): Latitude | Longitude | Elevation, Sun | Moon | Pressure or Speed. Quad compact, the
 * compact row, two rows, the list's rows, and Extra Large's one summary strip. Tiles in a row share the tallest
 * one's height, at least the planned height.
 */
@Composable
private fun TileGrid(nav: Navigator, plan: Plan, a: Actions) {
    val width = plan.column
    var positionMenu by remember { mutableStateOf(false) }
    val tick = rememberTick()
    val fix = nav.fix
    val stale = !nav.sample && fix != null && tick - fix.time > 120_000
    val night = LocalNight.current
    val r = ramp(plan)
    val listRow = plan.grid == GridMode.ROWS
    val openPositionMenu = { positionMenu = true }
    Box(Modifier.width(width.dp)) {
        if (plan.grid == GridMode.STRIP) {
            Strip(nav, plan, stale, openPositionMenu, a)
        } else {
            Column(verticalArrangement = Arrangement.spacedBy(plan.rowGap.dp)) {
                plan.rows.forEachIndexed { index, row ->
                    val height = if (index == 0 || listRow) plan.tile else plan.tile2
                    TileRow(row, width, height, mapIndex = row.tiles.indexOf(TileKind.MAP)) {
                        row.tiles.forEachIndexed { i, kind ->
                            // The value's room: the tile less its insets; in a list row, the trailing 60%.
                            val inner = (if (listRow) (row.widths[i] - 2 * r.padH.value) * 0.6f else row.widths[i] - 2 * r.padH.value).coerceAtLeast(1f).dp
                            // The tile's whole width inside its insets (where a list row's Sun times go when the 60% is too narrow).
                            val full = (row.widths[i] - 2 * r.padH.value).coerceAtLeast(1f).dp
                            when (kind) {
                                TileKind.POSITION -> PositionTile(nav, r, stale, inner, listRow, openPositionMenu, a)
                                TileKind.LATITUDE, TileKind.LONGITUDE -> AxisTile(nav, r, kind == TileKind.LATITUDE, stale, inner, openPositionMenu, a)
                                TileKind.ELEVATION -> ElevationTile(nav, plan, r, stale, inner, listRow, a)
                                TileKind.SUN -> SunTile(nav, plan, r, inner, full, height, listRow, a)
                                TileKind.MOON -> MoonTile(nav, r, inner, listRow, a)
                                TileKind.PRESSURE -> PressureTile(nav, r, inner, listRow, a)
                                TileKind.SPEED -> SpeedTile(nav, r, inner, listRow)
                                TileKind.MAP -> MapTile(nav, a, speedChip = height >= LayoutPlan.SUN_MOON_FROM)
                            }
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
 * One row of tiles at the planner's widths, [TileRowPlan.gap] apart inside its insets, exactly [total] wide (the
 * widths, gaps and insets add up to the column; checked in debug builds), all as tall as the tallest (at least
 * [minHeight]): a tile grows taller before anything in it is cut. Every width but the last rounds to whole pixels
 * and the last takes what is left. The map tile ([mapIndex]) takes the row's height without being asked for its own.
 */
@Composable
private fun TileRow(row: TileRowPlan, total: Float, minHeight: Float, mapIndex: Int = -1, content: @Composable () -> Unit) {
    if (BuildConfig.DEBUG) {
        check(abs(row.total - total) < 0.5f) { "Tile row ${row.widths} adds up to ${row.total}, not $total" }
    }
    ComposeLayout(content) { measurables, _ ->
        val gap = row.gap.dp.roundToPx()
        val inset = row.inset.dp.roundToPx()
        val totalPx = total.dp.roundToPx()
        val ws = row.widths.map { it.dp.roundToPx() }.toMutableList()
        if (ws.isNotEmpty()) ws[ws.size - 1] = (totalPx - 2 * inset - (ws.sum() - ws.last()) - gap * (ws.size - 1)).coerceAtLeast(0)
        var h = minHeight.dp.roundToPx()
        measurables.forEachIndexed { i, m -> if (i != mapIndex && i < ws.size) h = max(h, m.maxIntrinsicHeight(ws[i])) }
        val placeables = measurables.mapIndexed { i, m -> m.measure(Constraints.fixed(ws.getOrElse(i) { 0 }, h)) }
        layout(totalPx, h) {
            var x = inset
            placeables.forEachIndexed { i, p -> p.placeRelative(x, 0); x += ws.getOrElse(i) { 0 } + gap }
        }
    }
}

/**
 * One tile (A.2): radius 16, the tile fill and a 1 dp edge; the caption (caps, tracking 0.6, secondary, text only)
 * at the top inset and the value block with its last baseline at the bottom inset, so a grown tile is never half
 * empty at the bottom. With [listRow] (the scrolling list) the caption leads and the value block trails; with [stacked]
 * too, the value block goes under the caption at the tile's full width, still trailing. TalkBack reads it as one
 * element ([spoken]).
 */
@Composable
private fun Tile(caption: @Composable () -> Unit, spoken: String, r: Ramp, click: Modifier = Modifier, listRow: Boolean = false,
                 stacked: Boolean = false, content: @Composable ColumnScope.() -> Unit) {
    // Clipped before the click, so the ripple keeps the rounded corners.
    val base = Modifier.fillMaxSize().clip(Look.shape).then(click).frostedTile()
        .semantics(mergeDescendants = true) { contentDescription = spoken }
        .padding(horizontal = r.padH, vertical = r.padV)
    if (listRow && stacked) {
        Column(base) {
            caption()
            Spacer(Modifier.height(4.dp))
            Column(Modifier.fillMaxWidth(), horizontalAlignment = Alignment.End, content = content)
        }
        return
    }
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

@Composable
private fun captionStyle(r: Ramp, color: Color = secondary()): TextStyle =
    text(r.caption, FontWeight.SemiBold, color).copy(letterSpacing = Look.TILE_CAPTION_TRACKING.sp, lineHeight = r.captionLine.sp)

/**
 * A tile's caption, text only: [title] in caps, shrunk to 0.85 and then wrapped rather than cut (POSITION · MGRS in
 * a narrow tile); with [moon], " · ◐ 53%" follows, the moon drawn for its phase.
 */
@Composable
private fun TileCaption(title: String, inner: Dp, r: Ramp, moon: com.bradcowdrey.bearings.MoonPhase? = null) {
    val style = captionStyle(r)
    if (moon == null) {
        FitWrapText(title.uppercase(), style, inner)
        return
    }
    val glyph = "moon"
    val caption = buildAnnotatedString {
        append(title.uppercase()); append(" · ")
        appendInlineContent(glyph, "◐")
        append("\u00A0${Geo.jsRound(moon.fraction * 100)}%")
    }
    val inline = mapOf(glyph to InlineTextContent(Placeholder(1.em, 1.em, PlaceholderVerticalAlign.TextCenter)) {
        Canvas(Modifier.fillMaxSize()) { moonGlyph(Offset(size.width / 2, size.height / 2), size.minDimension / 2, moon.phase, 1f) }
    })
    // Like every other caption it shrinks (to 0.85) before it wraps, so the row stays as tall as planned.
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
private fun secondaryStyle(r: Ramp? = null): TextStyle =
    text(r?.secondary ?: Look.TILE_SECONDARY, color = secondary())
        .copy(lineHeight = (r?.secondaryLine ?: Look.TILE_SECONDARY_LINE).sp, fontFeatureSettings = "tnum")

/** "21.04 inHg" → "21.04" at the value's size and " inHg" at 12, white 70% (A.3). */
@Composable
private fun withSmallUnit(value: String): AnnotatedString {
    val i = value.lastIndexOf(' ')
    if (i <= 0) return AnnotatedString(value)
    return buildAnnotatedString {
        append(value.substring(0, i))
        append('\u202F')
        withStyle(SpanStyle(fontSize = 12.sp, color = white(if (LocalNight.current) Op.NIGHT_SECONDARY else Op.SUB))) { append(value.substring(i + 1)) }
    }
}

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
 * A value that never ellipsizes: it shrinks to fit [width] down to 0.85 of its size, then wraps.
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
 * Lines that share one size: the largest scale from 1 down to 0.85 at which every line fits [width] (the longer
 * line decides), so "39.09898° N" and "106.94117° W" are never drawn at two sizes; past 0.85 they wrap.
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
 * A sunrise or sunset line, "↑ 6:36 AM", with a no-break space after the arrow and a narrow no-break space before
 * AM, so it never breaks (A.7): shrunk to fit down to 0.85; where even that is too wide, the AM or PM drops to 11
 * on the same line. Never cut with "…".
 */
@Composable
private fun SunTime(arrow: String, time: String, style: TextStyle, width: Dp) {
    val measurer = rememberTextMeasurer()
    val density = LocalDensity.current
    val max = with(density) { width.roundToPx() }.coerceAtLeast(1)
    val whole = TextFit.sunLine(arrow, time)
    val (main, suffix) = remember(time) { TextFit.splitClock(time) }
    val scale = remember(whole, max, style, density) { fitScale(measurer, whole, style, max) }
    if (scale != null || suffix == null) {
        Text(whole, style = style.copy(fontSize = style.fontSize * (scale ?: Look.MIN_TEXT_SCALE)), softWrap = false, maxLines = 1)
        return
    }
    val small = SpanStyle(fontSize = 11.sp, fontWeight = FontWeight.Medium, color = secondary())
    val first = "$arrow\u00A0$main"
    val s2 = remember(first, suffix, max, style, density) {
        val tail = measurer.measure(AnnotatedString("\u202F$suffix"), style.merge(small), softWrap = false, maxLines = 1).size.width
        fitScale(measurer, first, style, (max - tail).coerceAtLeast(1)) ?: Look.MIN_TEXT_SCALE
    }
    val shown = buildAnnotatedString {
        append(first)
        append('\u202F')
        withStyle(small) { append(suffix) }
    }
    Text(shown, style = style.copy(fontSize = style.fontSize * s2), softWrap = false, maxLines = 1)
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
private fun Pending(note: String, r: Ramp? = null) {
    Text("—", style = valueStyle(dim = true, size = r?.value ?: Look.TILE_VALUE))
    Text(note, style = secondaryStyle(r))
}

/** The Position text in the current format, or null before a fix. */
private fun positionText(nav: Navigator): Geo.Formatted? = nav.fix?.let { Geo.format(nav.format, it.latitude, it.longitude) }

private fun positionSpoken(nav: Navigator, f: Geo.Formatted?, stale: Boolean): String = when (f) {
    is Geo.Formatted.Pair -> "Position, ${spokenCoordinate(f.lat)}, ${spokenCoordinate(f.lon)}, ${nav.format.title.lowercase()}${if (stale) ", not recent" else ""}"
    is Geo.Formatted.Single -> "Position, ${f.text}, ${nav.format.title}${if (stale) ", not recent" else ""}"
    null -> "Position, not known yet"
}

/** Tap: the next format. Touch and hold: Copy, Details…. With TalkBack, the same as actions. */
@OptIn(ExperimentalFoundationApi::class)
private fun positionClick(nav: Navigator, onLongPress: () -> Unit, a: Actions): Modifier = if (nav.fix == null) Modifier else Modifier
    .combinedClickable(onClickLabel = "Change the coordinate format", onLongClickLabel = "Show Copy and Details",
        onLongClick = onLongPress, onClick = { nav.cycleFormat() })
    .semantics {
        customActions = listOf(
            CustomAccessibilityAction("Next Format") { nav.cycleFormat(); true },
            CustomAccessibilityAction("Copy") { a.copy(); true },
            CustomAccessibilityAction("Details") { a.details(); true },
        )
    }

/**
 * Position: the coordinates in the current format, both lines at one size (15, 22 on a tablet); a one-line format
 * (MGRS, Plus Code, UTM) at the tile's value size, and the tile never grows for it. Tap: the next format. Touch and
 * hold: Copy, Details….
 */
@Composable
private fun PositionTile(nav: Navigator, r: Ramp, stale: Boolean, inner: Dp, listRow: Boolean, onLongPress: () -> Unit, a: Actions) {
    val f = positionText(nav)
    Tile({ TileCaption("Position · ${shortName(nav.format)}", inner, r) }, positionSpoken(nav, f, stale), r, positionClick(nav, onLongPress, a), listRow) {
        when (f) {
            is Geo.Formatted.Pair -> FitWrapLines(listOf(f.lat, f.lon), valueStyle(dim = stale, size = r.position), inner)
            is Geo.Formatted.Single -> FitWrapText(f.text, valueStyle(dim = stale, size = r.value), inner)
            null -> Pending("Finding position…", r)
        }
    }
}

/** Large's Latitude or Longitude (decimal degrees): "39.09898°" over "North". Same gestures as Position. */
@Composable
private fun AxisTile(nav: Navigator, r: Ramp, latitude: Boolean, stale: Boolean, inner: Dp, onLongPress: () -> Unit, a: Actions) {
    val f = positionText(nav) as? Geo.Formatted.Pair
    val line = f?.let { if (latitude) it.lat else it.lon }
    val title = if (latitude) "Latitude" else "Longitude"
    val (value, word) = line?.let { TextFit.hemisphere(it) } ?: ("—" to null)
    val spoken = if (line == null) "$title, not known yet" else "$title, ${spokenCoordinate(line)}${if (stale) ", not recent" else ""}"
    Tile({ TileCaption(title, inner, r) }, spoken, r, positionClick(nav, onLongPress, a)) {
        FitWrapText(value, valueStyle(dim = stale || line == null, size = r.value).copy(letterSpacing = (-0.2).sp), inner)
        Text(word ?: if (line == null) "Finding position…" else "", style = secondaryStyle(r))
    }
}

/** "9,587 ft" → "9,587 feet", for TalkBack. */
private fun spokenUnits(s: String) = s.removeSuffix(" ft").let { if (it != s) "$it feet" else s.removeSuffix(" m") + " metres" }

/**
 * Elevation: "9,587 ft" over "2,922 m" (the order follows the units setting); in Medium's 2 × 2 the pressure
 * follows, "2,922 m · 21.04 inHg". Opens the Details sheet.
 */
@Composable
private fun ElevationTile(nav: Navigator, plan: Plan, r: Ramp, stale: Boolean, inner: Dp, listRow: Boolean, a: Actions) {
    val click = Modifier.clickable(role = Role.Button, onClickLabel = "Show the details", onClick = a.details)
    val caption = @Composable { TileCaption("Elevation", inner, r) }
    when (val e = nav.elevation) {
        is ElevationReading.Value -> {
            val (ft, m) = Geo.elevation(e.metres)
            val first = if (nav.feet) ft else m; val second = if (nav.feet) m else ft
            val pressure = nav.pressure?.takeIf { plan.grid == GridMode.QUAD && !listRow }?.let { Geo.pressureText(it, nav.feet) }
            val spoken = "Elevation, ${spokenUnits(first)}, ${spokenUnits(second)}, ${if (e.fromGps) "from GPS" else "from terrain data"}" +
                (pressure?.let { ", pressure $it" } ?: "")
            Tile(caption, spoken, r, click, listRow) {
                FitWrapText(first.replace(' ', '\u00A0'), valueStyle(dim = stale, size = r.value), inner)
                FitWrapText(listOfNotNull(second, pressure).joinToString(" · ") { it.replace(' ', '\u00A0') }, secondaryStyle(r), inner)
            }
        }
        is ElevationReading.Pending -> {
            val note = if (nav.fix == null) "Finding position…" else e.note.ifBlank { "Looking it up…" }
            Tile(caption, "Elevation, $note", r, click, listRow) { Pending(note, r) }
        }
    }
}

/** Sunrise and sunset for the fix: the two clock times, or "Up all day" / "Down all day", with the spoken form. */
private class SunText(val rise: String?, val set: String?, val allDay: String?, val daylight: String?, val spoken: String)

private fun sunText(nav: Navigator): SunText? {
    val fix = nav.fix ?: return null
    val times = Sky.sunTimes(nav.now.toDouble(), fix.latitude, fix.longitude)
    val rise = times.sunrise; val set = times.sunset
    if (rise != null && set != null && times.polar == null) {
        val up = nav.clock(rise.toLong()); val down = nav.clock(set.toLong())
        val minutes = Math.round((set - rise) / 60_000.0)
        val daylight = "${minutes / 60}\u00A0h ${minutes % 60}\u00A0m of daylight"
        return SunText(up, down, null, daylight, "Sun, rises $up, sets $down")
    }
    val allDay = if (times.polar == com.bradcowdrey.bearings.Polar.DAY) "Up all day" else "Down all day"
    return SunText(null, null, allDay, null, "Sun, $allDay")
}

private fun moonSpoken(phase: com.bradcowdrey.bearings.MoonPhase) =
    "Moon, ${Geo.jsRound(phase.fraction * 100)} percent, ${Sky.phaseName(phase).lowercase()}"

/**
 * Sun (A.3): "↑ 6:36 AM" over "↓ 5:08 PM" (the phone's 12- or 24-hour clock) at 15, or "Up all day" / "Down all
 * day". Where no Moon tile shows the moon, the caption carries it, "SUN · ◐ 53%". Large's compact tile is SUNRISE:
 * "↑ 6:36 AM" (AM at 12, white 70%) over "Sets 5:08 PM". Medium with no Targets card, once row 2 is 150 or more:
 * SUN with the daylight, a hairline, then a MOON section. Opens the Details sheet, which has the moon in full.
 */
@Composable
private fun SunTile(nav: Navigator, plan: Plan, r: Ramp, inner: Dp, full: Dp, rowHeight: Float, listRow: Boolean, a: Actions) {
    val click = Modifier.clickable(role = Role.Button, onClickLabel = "Show the details", onClick = a.details)
    val phase = nav.moonPhase
    val withMoon = sunCarriesMoon(plan, rowHeight)
    val tall = plan.grid == GridMode.QUAD && plan.map == MapMode.TILE && rowHeight >= LayoutPlan.SUN_MOON_FROM && !listRow
    val six = plan.grid == GridMode.SIX
    val moonSpoken = if (withMoon || tall) ". ${moonSpoken(phase)}" else ""
    val caption = @Composable { TileCaption(if (six) "Sunrise" else "Sun", inner, r, moon = if (withMoon) phase else null) }
    val size = when {
        plan.tablet || listRow || six -> r.value
        else -> 15f
    }
    val style = valueStyle(size = size, weight = if (plan.grid == GridMode.ROW) FontWeight.SemiBold else FontWeight.Medium)
    val t = sunText(nav)
    if (t == null) {
        Tile(caption, "Sun, not known yet$moonSpoken", r, click, listRow) { Pending("Finding position…", r) }
        return
    }
    if (t.rise == null || t.set == null) {
        Tile(caption, "${t.spoken}$moonSpoken", r, click, listRow) { FitWrapText(t.allDay ?: "", style, inner) }
        return
    }
    when {
        six -> Tile(caption, "${t.spoken}$moonSpoken", r, click) {
            val (main, suffix) = TextFit.splitClock(t.rise)
            val night = LocalNight.current
            Text(buildAnnotatedString {
                append("↑\u00A0$main")
                if (suffix != null) {
                    append('\u202F')
                    withStyle(SpanStyle(fontSize = 12.sp, color = white(if (night) Op.NIGHT_SECONDARY else Op.SUB))) { append(suffix) }
                }
            }, style = style.copy(letterSpacing = (-0.2).sp), softWrap = false, maxLines = 1)
            FitWrapText("Sets\u00A0${TextFit.time(t.set)}", secondaryStyle(r), inner)
        }
        tall -> Tile({ TileCaption("Sun", inner, r) }, "${t.spoken}, ${t.daylight}$moonSpoken", r, click) {
            SunTime("↑", t.rise, style, inner)
            SunTime("↓", t.set, style, inner)
            t.daylight?.let { FitWrapText(it, secondaryStyle(r), inner) }
            Spacer(Modifier.weight(1f))
            Box(Modifier.fillMaxWidth().height(1.dp).background(white(Op.TILE)))
            Spacer(Modifier.height(8.dp))
            TileCaption("Moon", inner, r)
            Spacer(Modifier.height(4.dp))
            MoonValue(phase, r)
            Text(Sky.phaseName(phase), style = secondaryStyle(r))
        }
        else -> {
            // The scrolling list: where a time can't stay whole at 0.85 in the trailing 60% (font scale 2 on a 360 dp
            // phone), the times go under the caption at the tile's full width, each still whole on its own line.
            val stacked = listRow && !sunLinesFit(listOf(t.rise, t.set), style, inner)
            val room = if (stacked) full else inner
            Tile(caption, "${t.spoken}$moonSpoken", r, click, listRow, stacked) {
                SunTime("↑", t.rise, style, room)
                SunTime("↓", t.set, style, room)
            }
        }
    }
}

/** Whether every "↑ 6:36 AM" line fits [width] on one line at 0.85 of its size or more. */
@Composable
private fun sunLinesFit(times: List<String>, style: TextStyle, width: Dp): Boolean {
    val measurer = rememberTextMeasurer()
    val density = LocalDensity.current
    val max = with(density) { width.roundToPx() }.coerceAtLeast(1)
    return remember(times, max, style, density) { times.all { fitScale(measurer, TextFit.sunLine("↑", it), style, max) != null } }
}

/** The moon's glyph, drawn for its phase, and "53%". */
@Composable
private fun MoonValue(phase: com.bradcowdrey.bearings.MoonPhase, r: Ramp) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Canvas(Modifier.size((r.value * 0.9f).dp)) { moonGlyph(Offset(size.width / 2, size.height / 2), size.minDimension / 2, phase.phase, 1f) }
        Spacer(Modifier.width(6.dp))
        Text("${Geo.jsRound(phase.fraction * 100)}%", style = valueStyle(size = r.value))
    }
}

/** Moon: the phase's glyph and "53%" over "Last quarter". Opens the Details sheet. */
@Composable
private fun MoonTile(nav: Navigator, r: Ramp, inner: Dp, listRow: Boolean, a: Actions) {
    val phase = nav.moonPhase
    Tile({ TileCaption("Moon", inner, r) }, moonSpoken(phase), r,
        Modifier.clickable(role = Role.Button, onClickLabel = "Show the details", onClick = a.details), listRow) {
        MoonValue(phase, r)
        Text(Sky.phaseName(phase), style = secondaryStyle(r))
    }
}

/**
 * Large's sixth tile when still (A.3): PRESSURE, "21.04 inHg" (the unit at 12, white 70%) over "721 hPa" (the order
 * follows the units setting); "—" on a phone with no barometer. Opens the Details sheet.
 */
@Composable
private fun PressureTile(nav: Navigator, r: Ramp, inner: Dp, listRow: Boolean, a: Actions) {
    val p = nav.pressure
    val click = Modifier.clickable(role = Role.Button, onClickLabel = "Show the details", onClick = a.details)
    if (p == null) {
        Tile({ TileCaption("Pressure", inner, r) }, "Pressure, no barometer", r, click, listRow) {
            Text("—", style = valueStyle(dim = true, size = r.value))
        }
        return
    }
    val first = Geo.pressureText(p, nav.feet); val second = Geo.pressureText(p, !nav.feet)
    Tile({ TileCaption("Pressure", inner, r) }, "Pressure, $first, $second", r, click, listRow) {
        Text(withSmallUnit(first), style = valueStyle(size = r.value).copy(letterSpacing = (-0.2).sp), softWrap = false, maxLines = 1)
        Text(second.replace(' ', '\u00A0'), style = secondaryStyle(r), softWrap = false, maxLines = 1)
    }
}

/** Large's sixth tile while moving (A.3): SPEED, "3.2 mph" over "5.1 km/h" (the order follows the units setting). */
@Composable
private fun SpeedTile(nav: Navigator, r: Ramp, inner: Dp, listRow: Boolean) {
    val v = if (nav.sample) null else nav.speed
    Tile({ TileCaption("Speed", inner, r) }, if (v == null) "Speed, not moving" else "Speed, ${Geo.speedText(v, nav.feet)}", r, listRow = listRow) {
        if (v == null) Text("—", style = valueStyle(dim = true, size = r.value)) else {
            Text(withSmallUnit(Geo.speedText(v, nav.feet)), style = valueStyle(size = r.value).copy(letterSpacing = (-0.2).sp), softWrap = false, maxLines = 1)
            Text(Geo.speedText(v, !nav.feet).replace(' ', '\u00A0'), style = secondaryStyle(r), softWrap = false, maxLines = 1)
        }
    }
}

/**
 * Map (A.2): the snapshot full bleed (the dark style, labels at 70%), no controls, under one [scrim] band (black
 * 60%) holding the expand glyph and "MAP" leading and "© OpenStreetMap" (9 sp, white 60%) trailing. With
 * [speedChip] (a tall tile) the speed shows top-leading while moving. Tapping it opens the map sheet.
 */
@Composable
private fun MapTile(nav: Navigator, a: Actions, speedChip: Boolean = false, scrim: Dp = 24.dp) {
    Box(Modifier.fillMaxSize().clip(Look.shape)) {
        MapSnippet(
            nav.fix, nav.trueHeading, follow = false, night = nav.night, speed = null,
            onToggleFollow = {}, onOpen = a.openMap, modifier = Modifier.fillMaxSize(), controls = false, attribution = false,
        )
        Row(
            Modifier.align(Alignment.BottomStart).fillMaxWidth().height(scrim).background(Color.Black.copy(alpha = 0.6f))
                .padding(horizontal = 8.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Icon(Icons.Filled.ZoomOutMap, null, tint = Color.White, modifier = Modifier.size(11.dp))
            Spacer(Modifier.width(4.dp))
            Text("MAP", style = text(Look.TILE_CAPTION, FontWeight.SemiBold, Color.White)
                .copy(letterSpacing = Look.TILE_CAPTION_TRACKING.sp, lineHeight = Look.TILE_CAPTION_LINE.sp), maxLines = 1, softWrap = false)
            Spacer(Modifier.weight(1f).widthIn(min = 6.dp))
            Text("© OpenStreetMap", style = text(9f, FontWeight.Medium, white(Op.CAPTION)), maxLines = 1, softWrap = false,
                modifier = Modifier.semantics { contentDescription = "Map data from OpenStreetMap contributors" })
        }
        val speed = if (nav.sample) null else nav.speed
        if (speedChip && speed != null) {
            Text(Geo.speedText(speed, nav.feet).replace(' ', '\u00A0'), style = text(13f, FontWeight.SemiBold, Color.White).copy(fontFeatureSettings = "tnum"),
                modifier = Modifier.align(Alignment.TopStart).padding(start = 12.dp, top = 12.dp).clip(RoundedCornerShape(14.dp))
                    .background(Palette.speedChip).padding(horizontal = 10.dp, vertical = 5.dp))
        }
        // Over the map, so the tap opens the sheet rather than reaching the map view.
        Box(Modifier.matchParentSize().clickable(role = Role.Button, onClickLabel = "Open the map", onClick = a.map)
            .semantics { contentDescription = "Map, opens full map" })
    }
}

/**
 * The map card (Small, a tablet's Medium, two panes): the whole map with its control stack, the speed chip while
 * moving (hidden in the sample, which is still) and the attribution pill, [bottomInset] above the bottom (over
 * Small's band).
 */
@Composable
private fun MapCard(nav: Navigator, a: Actions, modifier: Modifier, bottomInset: Dp = 0.dp) {
    MapSnippet(
        nav.fix, nav.trueHeading, nav.followHeading, nav.night,
        speed = (if (nav.sample) null else nav.speed)?.let { Geo.speedText(it, nav.feet) },
        onToggleFollow = { nav.setFollowHeading(!nav.followHeading) },
        onOpen = a.openMap,
        modifier = modifier,
        bottomInset = bottomInset,
    )
}

/**
 * Small's band along the map card's bottom (A.3): a solid #16191A strip under a 1 dp edge, 10 × 12 padding, three
 * columns 1.2 | 1 | 1, 8 apart: POSITION · DD | ELEVATION | SUN · ◐ 53%, values 13 semibold on a 17 line, 3 under
 * the caption.
 */
@Composable
private fun Band(nav: Navigator, plan: Plan, a: Actions, modifier: Modifier) {
    val row = plan.rows.single()
    val edge = Palette.tileStroke
    Row(
        modifier.background(Palette.band).drawWithContent { drawContent(); drawRect(edge, size = Size(size.width, 1.dp.toPx())) }
            .padding(horizontal = row.inset.dp),
        horizontalArrangement = Arrangement.spacedBy(row.gap.dp),
    ) {
        row.tiles.forEachIndexed { i, kind ->
            Summary(nav, plan, kind, band = true, a, Modifier.width(row.widths[i].dp).fillMaxHeight(), PaddingValues(vertical = 10.dp))
        }
    }
}

/**
 * Extra Large's one summary strip (A.3): one tile [Plan.tile] high, three columns 1.25 | 1 | 1 separated by 1 dp
 * dividers, each with 12 × 14 padding: POSITION (two lines, 15 medium) | ELEVATION | SUN.
 */
@Composable
private fun Strip(nav: Navigator, plan: Plan, stale: Boolean, onLongPress: () -> Unit, a: Actions) {
    val row = plan.rows.single()
    Row(Modifier.fillMaxWidth().height(plan.tile.dp).frostedTile()) {
        row.tiles.forEachIndexed { i, kind ->
            if (i > 0) Box(Modifier.width(row.gap.dp).fillMaxHeight().background(Palette.tileStroke))
            Summary(nav, plan, kind, band = false, a, Modifier.width(row.widths[i].dp).fillMaxHeight(),
                PaddingValues(horizontal = LayoutPlan.STRIP_INSET.dp, vertical = 14.dp), stale, onLongPress)
        }
    }
}

/**
 * One column of the band or the strip: the caption, then the two value lines. Position cycles the format on a tap
 * (touch and hold: Copy, Details…); Elevation and Sun open the Details sheet. One TalkBack element each.
 */
@Composable
private fun Summary(nav: Navigator, plan: Plan, kind: TileKind, band: Boolean, a: Actions, modifier: Modifier, padding: PaddingValues,
                    stale: Boolean = false, onLongPress: (() -> Unit)? = null) {
    val night = LocalNight.current
    var menu by remember { mutableStateOf(false) }
    val r = ramp(plan)
    val value = if (band) text(13f, FontWeight.SemiBold).copy(lineHeight = 17.sp, fontFeatureSettings = "tnum")
        else valueStyle(dim = stale && kind == TileKind.POSITION, size = 15f)
    val second = if (band) value.copy(color = secondary()) else secondaryStyle(r)
    val captionGap = if (band) 3.dp else 6.dp
    val details = Modifier.clickable(role = Role.Button, onClickLabel = "Show the details", onClick = a.details)
    BoxWithConstraints(modifier) {
        val inner = (maxWidth - padding.calculateLeftPadding(androidx.compose.ui.unit.LayoutDirection.Ltr) -
            padding.calculateRightPadding(androidx.compose.ui.unit.LayoutDirection.Ltr)).coerceAtLeast(1.dp)
        val (caption, spoken, click) = when (kind) {
            TileKind.POSITION -> {
                val f = positionText(nav)
                Triple((if (band) "Position · ${shortName(nav.format)}" else "Position"), positionSpoken(nav, f, stale),
                    positionClick(nav, onLongPress ?: { menu = true }, a))
            }
            TileKind.ELEVATION -> Triple("Elevation", "", details)
            else -> Triple("Sun", "", details)
        }
        val e = nav.elevation
        val sun = sunText(nav)
        val said = when (kind) {
            TileKind.POSITION -> spoken
            TileKind.ELEVATION -> if (e is ElevationReading.Value) Geo.elevation(e.metres).let { (ft, m) ->
                val first = if (nav.feet) ft else m; val other = if (nav.feet) m else ft
                "Elevation, ${spokenUnits(first)}, ${spokenUnits(other)}"
            } else "Elevation, not known yet"
            else -> (sun?.spoken ?: "Sun, not known yet") + if (band) ". ${moonSpoken(nav.moonPhase)}" else ""
        }
        Column(Modifier.fillMaxSize().then(click).semantics(mergeDescendants = true) { contentDescription = said }.padding(padding)) {
            TileCaption(caption, inner, r, moon = if (band && kind == TileKind.SUN) nav.moonPhase else null)
            Spacer(Modifier.height(captionGap))
            when (kind) {
                TileKind.POSITION -> when (val f = positionText(nav)) {
                    is Geo.Formatted.Pair -> FitWrapLines(listOf(f.lat, f.lon), value, inner)
                    is Geo.Formatted.Single -> FitWrapText(f.text, value, inner)
                    null -> Text("—", style = second)
                }
                TileKind.ELEVATION -> if (e is ElevationReading.Value) {
                    val (ft, m) = Geo.elevation(e.metres)
                    FitWrapText((if (nav.feet) ft else m).replace(' ', '\u00A0'), value, inner)
                    FitWrapText((if (nav.feet) m else ft).replace(' ', '\u00A0'), second, inner)
                } else Text("—", style = second)
                else -> when {
                    sun == null -> Text("—", style = second)
                    sun.rise != null && sun.set != null -> {
                        SunTime("↑", sun.rise, value, inner)
                        SunTime("↓", sun.set, value, inner)
                    }
                    else -> FitWrapText(sun.allDay ?: "", value, inner)
                }
            }
        }
        if (kind == TileKind.POSITION && onLongPress == null) {
            DropdownMenu(menu, onDismissRequest = { menu = false }) {
                Item("Copy", night, nav.fix != null) { a.copy(); menu = false }
                Item("Details…", night) { a.details(); menu = false }
            }
        }
    }
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
