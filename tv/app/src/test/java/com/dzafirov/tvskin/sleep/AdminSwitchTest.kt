package com.dzafirov.tvskin.sleep

import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Intent
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config

@RunWith(AndroidJUnit4::class)
@Config(sdk = [34])
class AdminSwitchTest {
    private val context = ApplicationProvider.getApplicationContext<android.content.Context>()
    private val dpm = context.getSystemService(DevicePolicyManager::class.java)
    private val admin = ComponentName(context, AdminReceiver::class.java)

    @Test
    fun `the remove-admin extra switches the device admin off`() {
        shadowOf(dpm).setActiveAdmin(admin)
        assertTrue(dpm.isAdminActive(admin))
        assertTrue(AdminSwitch.handle(context, Intent().putExtra(AdminSwitch.EXTRA_REMOVE_ADMIN, true)))
        assertFalse(dpm.isAdminActive(admin))
    }

    @Test
    fun `a normal launch leaves the device admin alone`() {
        shadowOf(dpm).setActiveAdmin(admin)
        assertFalse(AdminSwitch.handle(context, Intent()))
        assertTrue(dpm.isAdminActive(admin))
    }
}
