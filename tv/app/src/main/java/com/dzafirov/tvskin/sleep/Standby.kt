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

/**
 * The undo for the device admin. Android refuses `dpm remove-active-admin` for this app and won't uninstall an app
 * whose admin is on, so the app switches its own admin off when started with [EXTRA_REMOVE_ADMIN]:
 * `adb shell am start -n com.dzafirov.tvskin/.MainActivity --ez remove_admin true`
 */
object AdminSwitch {
    const val EXTRA_REMOVE_ADMIN = "remove_admin"

    /** Returns true when the intent asked for the admin to be removed (and it was). */
    fun handle(context: Context, intent: android.content.Intent?): Boolean {
        if (intent?.getBooleanExtra(EXTRA_REMOVE_ADMIN, false) != true) return false
        val dpm = context.getSystemService(DevicePolicyManager::class.java) ?: return false
        val admin = ComponentName(context, AdminReceiver::class.java)
        if (dpm.isAdminActive(admin)) dpm.removeActiveAdmin(admin)
        Log.i("Standby", "Device admin removed on request")
        return true
    }
}
