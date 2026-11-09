package com.bradcowdrey.bearings

import com.bradcowdrey.bearings.ui.MapBlocks
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * The map's picture check (review 2.3.0, 1): solid light rectangles where place names should be are found in the
 * pixels the map drew; real text, roads, water and the pale land patterns are not.
 */
class MapBlocksTest {
    private val land = 0xFF114140.toInt()
    private val white = 0xFFFFFFFF.toInt()
    private val label = 0xFFC9D3D6.toInt()
    private val w = 400
    private val h = 240
    /** 7 dp at the emulator's 2.625 px per dp. */
    private val side = 18

    private fun picture() = IntArray(w * h) { land }

    private fun IntArray.rect(x: Int, y: Int, width: Int, height: Int, color: Int) {
        for (py in y until y + height) for (px in x until x + width) this[py * w + px] = color
    }

    /** A word as the broken GPU draws it: one solid white rectangle per glyph run, 60 × 24 px. */
    @Test fun findsBlocks() {
        val p = picture()
        p.rect(100, 80, 60, 24, white)
        p.rect(164, 80, 30, 24, white)
        val r = MapBlocks.find(p, w, h, side)
        assertTrue(r.blocks)
        assertFalse(r.washed)
        assertEquals(117, r.x)
        assertEquals(97, r.y)
        // The label grey as a block is a block too.
        val q = picture()
        q.rect(20, 20, 40, 20, label)
        assertTrue(MapBlocks.find(q, w, h, side).blocks)
    }

    /** Real text: strokes 3 to 4 px wide in the label colour, however many, are never a block. */
    @Test fun textIsNotBlocks() {
        val p = picture()
        for (i in 0 until 12) {
            val x = 60 + i * 14
            p.rect(x, 100, 4, 23, label)      // a stem
            p.rect(x, 100, 10, 3, label)      // a bar at the cap height
            p.rect(x, 110, 9, 3, label)       // a bar in the middle
            p.rect(x, 120, 10, 3, label)      // a bar at the baseline
        }
        val r = MapBlocks.find(p, w, h, side)
        assertFalse("${r.squares} at ${r.x}, ${r.y}", r.blocks)
        assertTrue(r.light > 0f)
    }

    /** Roads, water, a pale green land pattern and a thin white line are not light blocks. */
    @Test fun mapFeaturesAreNotBlocks() {
        val p = picture()
        p.rect(0, 40, w, 14, 0xFF5A6470.toInt())
        p.rect(40, 150, 200, 60, 0xFF22348A.toInt())
        p.rect(260, 150, 80, 40, 0xFFB4BEA4.toInt())
        p.rect(0, 10, w, 6, white)
        // A road shield: a white plate 20 dp (52 px) wide and tall with its number dark in the middle.
        p.rect(300, 70, 52, 52, white)
        p.rect(312, 86, 28, 20, 0xFF333333.toInt())
        assertFalse(MapBlocks.find(p, w, h, side).blocks)
        assertFalse(MapBlocks.isLight(0xFFB4BEA4.toInt()))
        assertFalse(MapBlocks.isLight(0xFF5A6470.toInt()))
        assertTrue(MapBlocks.isLight(white))
        assertTrue(MapBlocks.isLight(label))
    }

    /** A picture that is mostly light is not the dark map: reported as washed out, never as a reason to hide labels. */
    @Test fun aLightPictureIsWashed() {
        val p = IntArray(w * h) { white }
        val r = MapBlocks.find(p, w, h, side)
        assertTrue(r.washed)
        assertEquals(1f, r.light, 0.001f)
    }

    @Test fun emptyOrOddInputFindsNothing() {
        assertFalse(MapBlocks.find(IntArray(0), 0, 0, side).blocks)
        assertFalse(MapBlocks.find(IntArray(10), 400, 240, side).blocks)
        assertFalse(MapBlocks.find(picture(), w, h, side).blocks)
    }
}
