package com.dzafirov.tvskin.sleep

import android.app.admin.DeviceAdminReceiver
import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.util.Log

/** Puts the TV in standby. Plan 2 adds a shell-based way and picks whichever works on this TV. */
interface Standby {
    /** Returns false when this way isn't available. */
    fun now(): Boolean
}

/** `lockNow()` as a device admin (activated once over adb: `dpm set-active-admin …/.sleep.AdminReceiver`). */
class DeviceAdminStandby(private val context: Context) : Standby {
    override fun now(): Boolean {
        val dpm = context.getSystemService(DevicePolicyManager::class.java) ?: return false
        val admin = ComponentName(context, AdminReceiver::class.java)
        if (!dpm.isAdminActive(admin)) {
            Log.w("Standby", "Device admin not active; can't turn the TV off")
            return false
        }
        dpm.lockNow()
        return true
    }
}

class AdminReceiver : DeviceAdminReceiver()
