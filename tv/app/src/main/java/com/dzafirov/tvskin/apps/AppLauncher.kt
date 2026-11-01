package com.dzafirov.tvskin.apps

import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.media.tv.TvContract
import android.provider.Settings
import android.util.Log
import com.dzafirov.tvskin.apps.AppEntry.Kind

/**
 * Opens a tile. [onLaunched] gets the package of every app opened (Task 6 passes LastAppStore::record).
 * Returns false when nothing could be opened.
 */
class AppLauncher(private val context: Context, private val onLaunched: (String) -> Unit = {}) {
    fun open(entry: AppEntry): Boolean {
        val intent = when (entry.kind) {
            Kind.APP -> launchIntent(entry.id)
            Kind.LIVE_TV -> launchIntent(AppArranger.LIVE_TV_PACKAGE)
            Kind.INPUT -> Intent(Intent.ACTION_VIEW, TvContract.buildChannelUriForPassthroughInput(entry.inputId!!))
            Kind.SETTINGS -> Intent(Settings.ACTION_SETTINGS)
        } ?: return false
        return try {
            context.startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
            entry.packageName?.let(onLaunched)
            true
        } catch (e: ActivityNotFoundException) {
            Log.w(TAG, "Could not open ${entry.id}", e)
            false
        } catch (e: SecurityException) {
            Log.w(TAG, "Not allowed to open ${entry.id}", e)
            false
        }
    }

    private fun launchIntent(packageName: String): Intent? =
        context.packageManager.getLeanbackLaunchIntentForPackage(packageName)
            ?: context.packageManager.getLaunchIntentForPackage(packageName)

    private companion object {
        const val TAG = "AppLauncher"
    }
}
