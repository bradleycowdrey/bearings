package com.bradcowdrey.bearings.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.systemBarsPadding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.bradcowdrey.bearings.Brand

/**
 * Terms of Use and Privacy: asked once, and again when Brand.TERMS_VERSION changes, at most once a month
 * (the same rule as the Mac and iPhone). It stays until the person agrees; Back leaves the app. Agreeing
 * then asks Android for location, which Bearings needs to show where you are.
 */
@Composable
fun TermsScreen(onAgree: () -> Unit) {
    val uri = LocalUriHandler.current
    Box(Modifier.fillMaxSize().background(Palette.bg).systemBarsPadding(), contentAlignment = Alignment.Center) {
        Column(Modifier.widthIn(max = 520.dp).fillMaxSize().padding(horizontal = 24.dp, vertical = 12.dp), verticalArrangement = Arrangement.spacedBy(18.dp)) {
            Spacer(Modifier.weight(1f))
            AppMark(56.dp)
            Text("Terms of Use and Privacy", style = text(28f, FontWeight.SemiBold))
            Text(Brand.TERMS_SUMMARY, style = text(16f, color = Palette.textSecondary))
            Text("By choosing I Agree and using ${Brand.APP_NAME}, you agree to the Terms of Use and Privacy at bradcowdrey.com/legal.",
                style = text(14f, color = Palette.textMuted))
            Spacer(Modifier.weight(1f))
            Box(
                Modifier.fillMaxWidth().heightIn(min = 50.dp).clip(CircleShape).background(Palette.cream).clickable(role = Role.Button, onClick = onAgree),
                contentAlignment = Alignment.Center,
            ) { Text("I Agree", style = text(17f, FontWeight.SemiBold, Palette.bg)) }
            Box(
                Modifier.fillMaxWidth().heightIn(min = 44.dp).clickable(role = Role.Button) { uri.openUri(Brand.LEGAL) },
                contentAlignment = Alignment.Center,
            ) { Text("Read the Terms", style = text(17f, FontWeight.Medium, Color.White)) }
        }
    }
}
