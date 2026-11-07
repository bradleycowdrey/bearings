package com.bradcowdrey.bearings

import com.bradcowdrey.bearings.ui.Layout
import com.bradcowdrey.bearings.ui.LayoutPlan
import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * The layout planner's golden table (docs/REFINE.md §4.7; docs/LAYOUTS.md §8): nothing more than 24 empty
 * at the bottom, nothing cut, every dial at its floor or more, map cards at least 140. The same table runs
 * in the emulator self-test (SelfTest.kt) and, on Apple, in Tests/BearingsTests/LayoutPlanTests.swift.
 */
class LayoutPlanTest {
    @Test fun goldenTable() {
        assertEquals(emptyList<String>(), LayoutPlan.tableFailures())
    }

    @Test fun layoutIds() {
        // CI passes these ids as the "layout" extra; they are the stored values.
        assertEquals(listOf("small", "medium", "large", "extraLarge"), Layout.entries.map { it.id })
        assertEquals(Layout.MEDIUM, Layout.of(null))
        assertEquals(Layout.MEDIUM, Layout.of("bogus"))
        assertEquals(Layout.EXTRA_LARGE, Layout.of("extraLarge"))
    }
}
