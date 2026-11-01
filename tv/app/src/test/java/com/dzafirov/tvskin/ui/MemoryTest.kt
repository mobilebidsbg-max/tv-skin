package com.dzafirov.tvskin.ui

import android.content.Context
import android.graphics.BitmapFactory
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.assertEquals
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

/** The TV has 2.4 GB of RAM: images are kept no bigger than they are shown. */
@RunWith(AndroidJUnit4::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(sdk = [34])
class MemoryTest {
    private val context = ApplicationProvider.getApplicationContext<Context>()

    @Test
    fun `banners are scaled to the tile, keeping their shape`() {
        assertEquals(256 to 144, fitWithin(640, 360, 256, 144))
        assertEquals(256 to 144, fitWithin(1280, 720, 256, 144))
        assertEquals(144 to 144, fitWithin(512, 512, 144, 144))
        assertEquals(100 to 50, fitWithin(100, 50, 256, 144)) // never scaled up
    }

    @Test
    fun `every wallpaper has a small thumbnail for Settings`() {
        Wallpaper.entries.forEach { w ->
            val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
            BitmapFactory.decodeResource(context.resources, w.thumb, bounds)
            assertTrue("$w thumbnail is ${bounds.outWidth} px wide", bounds.outWidth in 1..320)
        }
    }

    @Test
    fun `the blurred wallpaper is decoded once, at quarter size`() {
        val first = BlurCache.get(context, Wallpaper.DUNE)
        assertSame(first, BlurCache.get(context, Wallpaper.DUNE))
        assertTrue("width ${first.width}", first.width <= 480)
    }
}
