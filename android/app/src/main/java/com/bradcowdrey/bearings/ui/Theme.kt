package com.bradcowdrey.bearings.ui

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp
import com.bradcowdrey.bearings.R

/** The Mac and iPhone apps' colours (Palette.swift): warm near-black, cream, crimson. */
object Palette {
    val bg = Color(0xFF1A1816)
    val tile = Color(0xFF23201D)
    val dial = Color(0xFF201D1A)
    val border = Color(0xFF3A3530)
    val cream = Color(0xFFFFF1E5)
    val textSecondary = Color(0xFFE0D8D0)
    val textMuted = Color(0xFFB0A898)
    val textFaint = Color(0xFF9A9286)
    val tickMinor = Color(0xFF5A534B)
    val crimson = Color(0xFF990F3D)
    val accent = Color(0xFFE04A7A)
    val level = Color(0xFF8FC89A)
    val warn = Color(0xFFF2A65A)
    /** The sun on the dial and the widget's rose. */
    val sun = Color(0xFFF5B841)
    /** Night mode multiplies everything by this, so only red is left (and night vision is kept). */
    val nightRed = Color(0xFFFF2E1F)
}

/** For what night mode's multiply can't reach (menus and dialogs, in windows of their own): the same tint, by hand. */
fun Color.night(on: Boolean): Color =
    if (!on) this else Color(red * Palette.nightRed.red, green * Palette.nightRed.green, blue * Palette.nightRed.blue, alpha)

val Inter = FontFamily(
    Font(R.font.inter_regular, FontWeight.Normal),
    Font(R.font.inter_medium, FontWeight.Medium),
    Font(R.font.inter_semibold, FontWeight.SemiBold),
)

fun text(size: Float, weight: FontWeight = FontWeight.Normal, color: Color = Color.White) =
    TextStyle(fontFamily = Inter, fontSize = size.sp, fontWeight = weight, color = color, letterSpacing = (-0.01 * size).sp)
