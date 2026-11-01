package com.dzafirov.tvskin.ui

import androidx.compose.runtime.mutableStateOf
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onAllNodesWithText
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.tv.material3.Text
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config

@RunWith(AndroidJUnit4::class)
@Config(sdk = [34])
class LoadedTest {
    @get:Rule
    val compose = createComposeRule()

    private fun seen(text: String) =
        compose.waitUntil(3_000) { compose.onAllNodesWithText(text).fetchSemanticsNodes().isNotEmpty() }

    @Test
    fun `when the key changes, the new value replaces the old one`() {
        // The "Back to" button showed Prime Video's logo after it switched to YouTube.
        val key = mutableStateOf("prime")
        compose.setContent {
            val v = rememberLoaded(key.value, cached = { null }) { k -> "logo of $k" }
            Text(v ?: "nothing")
        }
        seen("logo of prime")
        key.value = "youtube"
        seen("logo of youtube")
    }
}
