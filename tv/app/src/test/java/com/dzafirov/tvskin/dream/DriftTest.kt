package com.dzafirov.tvskin.dream

import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import kotlin.math.abs

class DriftTest {
    @Test
    fun `drift stays within 12dp`() {
        (0 until 1440).forEach { m ->
            val (x, y) = driftOffset(m)
            assertTrue("minute $m: ($x, $y)", abs(x) <= 12 && abs(y) <= 12)
        }
    }

    @Test
    fun `drift changes every minute`() {
        (0 until 1439).forEach { m -> assertNotEquals("minute $m", driftOffset(m), driftOffset(m + 1)) }
    }
}
