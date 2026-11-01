package com.dzafirov.tvskin.sleep

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/** Keeps the sleep timer and its alarm. The alarm fires [SleepReceiver] even when another app is open. */
class SleepScheduler(private val context: Context) {
    private val prefs = context.getSharedPreferences("sleep", Context.MODE_PRIVATE)

    fun current(): SleepTimer = SleepTimer(prefs.getLong(KEY_END, 0L).takeIf { it > 0 })

    fun set(timer: SleepTimer) {
        val alarms = context.getSystemService(AlarmManager::class.java)
        val pending = PendingIntent.getBroadcast(
            context, 0, Intent(context, SleepReceiver::class.java),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val end = timer.endsAtMillis
        if (end == null) {
            prefs.edit().remove(KEY_END).apply()
            alarms?.cancel(pending)
            return
        }
        prefs.edit().putLong(KEY_END, end).apply()
        if (alarms == null) return
        if (alarms.canScheduleExactAlarms()) alarms.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, end, pending)
        else alarms.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, end, pending)
    }

    private companion object {
        const val KEY_END = "ends_at"
    }
}

/** The timer ran out: standby, then clear the timer. */
class SleepReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        DeviceAdminStandby(context).now()
        SleepScheduler(context).set(SleepTimer(null))
    }
}

/** After a restart the alarm is gone; clear the timer so it can't fire late. */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED) SleepScheduler(context).set(SleepTimer(null))
    }
}
