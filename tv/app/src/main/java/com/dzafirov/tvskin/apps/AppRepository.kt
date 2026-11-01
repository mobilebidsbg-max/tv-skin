package com.dzafirov.tvskin.apps

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.media.tv.TvInputInfo
import android.media.tv.TvInputManager
import com.dzafirov.tvskin.apps.AppEntry.Kind

/** What is installed on the TV. Reading it is slow on the TV: do it off the main thread and keep the result. */
interface InstalledApps {
    fun apps(): List<AppEntry>
    fun tvItems(): List<AppEntry>
}

/** Reads what is installed on the TV. */
class AppRepository(private val context: Context) : InstalledApps {
    private val pm: PackageManager = context.packageManager

    /** Every app with a TV launcher entry, minus this launcher and Live TV (Live TV is a TV item). */
    override fun apps(): List<AppEntry> {
        val intent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LEANBACK_LAUNCHER)
        return pm.queryIntentActivities(intent, 0)
            .map { it.activityInfo }
            .filter { it.packageName != context.packageName && it.packageName != AppArranger.LIVE_TV_PACKAGE }
            .distinctBy { it.packageName }
            .map { AppEntry(it.packageName, it.loadLabel(pm).toString(), Kind.APP) }
    }

    /** Live TV, the HDMI inputs, then the TV's own Settings. */
    override fun tvItems(): List<AppEntry> {
        val items = mutableListOf<AppEntry>()
        if (pm.getLaunchIntentForPackage(AppArranger.LIVE_TV_PACKAGE) != null ||
            pm.getLeanbackLaunchIntentForPackage(AppArranger.LIVE_TV_PACKAGE) != null
        ) {
            items += AppEntry(AppEntry.LIVE_TV_ID, "Live TV", Kind.LIVE_TV)
        }
        val inputs = context.getSystemService(TvInputManager::class.java)?.tvInputList.orEmpty()
        inputs.filter { it.type == TvInputInfo.TYPE_HDMI && it.isPassthroughInput }
            .sortedBy { it.loadLabel(context).toString() }
            .forEach { items += AppEntry(AppEntry.INPUT_PREFIX + it.id, it.loadLabel(context).toString(), Kind.INPUT) }
        items += AppEntry(AppEntry.SETTINGS_ID, "Settings", Kind.SETTINGS)
        return items
    }
}
