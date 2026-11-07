package com.bradcowdrey.bearings.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.systemBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Map
import androidx.compose.material.icons.outlined.NearMe
import androidx.compose.material.icons.outlined.WarningAmber
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.LinkAnnotation
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.text.withLink
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.bradcowdrey.bearings.Brand

/**
 * Terms of Use and Privacy: asked once, and again when Brand.TERMS_VERSION changes, at most once a month
 * (the same rule as the Mac and iPhone). It stays until the person agrees; Back leaves the app. Agreeing
 * then asks Android for location, which Bearings needs to show where you are. Laid out as docs/REFINE.md
 * §4.1, C2.3 #20 and C3.4 #18: the content centred in the space above the buttons (at least 48 under the safe
 * area), a 480 column, three short rows with 24 dp outlined symbols that wrap; "Next, Bearings asks for your
 * location." at 13 secondary 24 above the buttons, which are 12 apart and pinned 16 above the bottom.
 */
@Composable
fun TermsScreen(onAgree: () -> Unit) {
    val uri = androidx.compose.ui.platform.LocalUriHandler.current
    Box(Modifier.fillMaxSize().background(Palette.bg).systemBarsPadding(), contentAlignment = Alignment.TopCenter) {
        Column(Modifier.widthIn(max = 480.dp).fillMaxSize().padding(horizontal = 24.dp)) {
            BoxWithConstraints(Modifier.weight(1f).fillMaxWidth()) {
                val room = maxHeight
                Column(
                    Modifier.fillMaxWidth().verticalScroll(rememberScrollState()).heightIn(min = room).padding(top = 48.dp, bottom = 16.dp),
                    verticalArrangement = Arrangement.spacedBy(20.dp, Alignment.CenterVertically),
                ) {
                    Box(Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) { AppMark(80.dp) }
                    Text("Terms of Use and Privacy", style = text(28f, FontWeight.Bold).copy(letterSpacing = (-0.4).sp),
                        textAlign = TextAlign.Center, modifier = Modifier.fillMaxWidth().semantics { heading() })
                    Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
                        Point(Icons.Outlined.WarningAmber, "Not a navigation instrument")
                        Point(Icons.Outlined.NearMe, "Your location stays on this device")
                        Point(Icons.Outlined.Map, "Map from OpenStreetMap (OpenFreeMap)")
                    }
                    // 15 sp on the dark ground at well over 4.5:1, with the terms as an inline link.
                    val legal = buildAnnotatedString {
                        append("By choosing I Agree and using ${Brand.APP_NAME}, you agree to the Terms of Use and Privacy at ")
                        withLink(LinkAnnotation.Url(Brand.LEGAL)) {
                            withStyle(SpanStyle(color = Color.White, textDecoration = TextDecoration.Underline)) { append("bradcowdrey.com/legal") }
                        }
                        append(".")
                    }
                    Text(legal, style = text(15f, color = Palette.textSecondary).copy(lineHeight = 21.sp))
                }
            }
            // C3.4 #18: the note sits with the buttons it explains, 13 secondary, 24 above them.
            Text("Next, ${Brand.APP_NAME} asks for your location.", style = text(13f, color = Palette.textSecondary).copy(lineHeight = 18.sp),
                textAlign = TextAlign.Center, modifier = Modifier.fillMaxWidth())
            Spacer(Modifier.height(24.dp))
            Box(
                Modifier.fillMaxWidth().heightIn(min = 48.dp).clip(CircleShape).border(1.dp, Palette.border, CircleShape)
                    .clickable(role = Role.Button) { uri.openUri(Brand.LEGAL) },
                contentAlignment = Alignment.Center,
            ) { Text("Read the Terms", style = text(17f, FontWeight.Medium, Color.White)) }
            Spacer(Modifier.height(12.dp))
            Box(
                Modifier.fillMaxWidth().heightIn(min = 50.dp).clip(CircleShape).background(Palette.cream).clickable(role = Role.Button, onClick = onAgree),
                contentAlignment = Alignment.Center,
            ) { Text("I Agree", style = text(17f, FontWeight.SemiBold, Palette.bg)) }
            Spacer(Modifier.height(16.dp))
        }
    }
}

/** One of the three rows: a 24 dp outlined symbol and 17 sp text at 1.35 line height, wrapping within the column. */
@Composable
private fun Point(icon: ImageVector, words: String) {
    Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.Top) {
        // As tall as the 24 dp symbol, so it isn't squeezed into the text's 23 line.
        Box(Modifier.height(24.dp), contentAlignment = Alignment.Center) {
            Icon(icon, null, tint = Palette.cream, modifier = Modifier.size(24.dp))
        }
        Spacer(Modifier.width(12.dp))
        Text(words, style = text(17f, color = Color.White).copy(lineHeight = (17 * 1.35).sp), modifier = Modifier.weight(1f))
    }
}
