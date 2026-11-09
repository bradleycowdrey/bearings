package com.bradcowdrey.bearings.ui

/**
 * Looks at the picture the map actually drew (review 2.3.0, 1). A GPU stack that can't draw the map's text draws
 * every label as solid light rectangles, one per word; the emulator CI runs on does. Nothing about the style or a
 * probe says so, so the picture itself is checked: real 12 sp text never has a solid light square 7 dp on a side
 * (its strokes are about 1.5 dp), and nothing else on the dark map is near-white, so any such square is a block.
 * Pure Kotlin on ARGB pixels, so the unit tests run it on made-up pictures.
 */
object MapBlocks {
    /** A pixel counts as light from this value in every channel, with the channels within [SPREAD] (white or the label grey, not a pale green). */
    const val LIGHT = 190
    const val SPREAD = 30
    /**
     * The side of the solid square that makes a block, in dp: a word drawn as a block is about 11 dp tall at the
     * labels' 12 sp, while a road shield (a white plate, the one light thing the style draws) has its number in the
     * middle and no clear square this large around it.
     */
    const val SIDE_DP = 7f
    /** More light than this share of the picture is not a dark map with blocks on it: the picture is washed out. */
    const val WASHED = 0.35f

    /**
     * What [find] saw: [squares] counts the pixels that end a solid light square (0: no blocks), [x] and [y] the first
     * one, [light] the share of light pixels.
     */
    data class Result(val squares: Int, val x: Int, val y: Int, val light: Float) {
        val washed: Boolean get() = light > WASHED
        val blocks: Boolean get() = squares > 0
    }

    fun isLight(argb: Int): Boolean {
        val r = (argb shr 16) and 0xFF
        val g = (argb shr 8) and 0xFF
        val b = argb and 0xFF
        val lo = minOf(r, g, b)
        val hi = maxOf(r, g, b)
        return lo >= LIGHT && hi - lo <= SPREAD
    }

    /** Every solid light square [side] px on a side in [pixels] ([width] × [height], row by row). */
    fun find(pixels: IntArray, width: Int, height: Int, side: Int): Result {
        if (width <= 0 || height <= 0 || pixels.size < width * height || side <= 0) return Result(0, -1, -1, 0f)
        // up[x]: how many light pixels end at this row in column x; a run of [side] columns with up ≥ side is a square.
        val up = IntArray(width)
        var squares = 0
        var firstX = -1
        var firstY = -1
        var light = 0
        for (y in 0 until height) {
            var run = 0
            val row = y * width
            for (x in 0 until width) {
                if (isLight(pixels[row + x])) {
                    up[x] = up[x] + 1
                    light++
                } else {
                    up[x] = 0
                }
                if (up[x] >= side) {
                    run++
                    if (run >= side) {
                        squares++
                        if (firstX < 0) { firstX = x; firstY = y }
                    }
                } else {
                    run = 0
                }
            }
        }
        return Result(squares, firstX, firstY, light.toFloat() / (width.toFloat() * height.toFloat()))
    }
}
