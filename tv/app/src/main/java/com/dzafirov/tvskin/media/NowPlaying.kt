package com.dzafirov.tvskin.media

import android.content.ComponentName
import android.content.Context
import android.graphics.Bitmap
import android.media.MediaMetadata
import android.media.session.MediaController
import android.media.session.MediaSessionManager
import android.media.session.PlaybackState
import android.service.notification.NotificationListenerService
import com.dzafirov.tvskin.home.NowPlaying

/**
 * Exists so the launcher may read media sessions (title, artist, cover) of whatever plays. Granted once over adb:
 * `cmd notification allow_listener com.dzafirov.tvskin/com.dzafirov.tvskin.media.MediaListener`. It reads no notifications.
 */
class MediaListener : NotificationListenerService()

data class SessionInfo(val packageName: String, val title: String?, val artist: String?, val playing: Boolean, val art: Bitmap? = null)

/** What the top bar's pill shows: a playing session first, else a paused one; never one without a title. */
fun pickNowPlaying(sessions: List<SessionInfo>): NowPlaying? {
    val withTitle = sessions.filter { !it.title.isNullOrBlank() }
    val pick = withTitle.firstOrNull { it.playing } ?: withTitle.firstOrNull() ?: return null
    return NowPlaying(pick.title!!.trim(), pick.artist?.trim().orEmpty(), pick.packageName, pick.playing, pick.art)
}

/** Watches the TV's media sessions and reports what is playing; does nothing without listener access. */
class NowPlayingWatcher(private val context: Context, private val onChange: (NowPlaying?) -> Unit) {
    private val manager = context.getSystemService(MediaSessionManager::class.java)
    private val listener = ComponentName(context, MediaListener::class.java)
    private var controllers: List<MediaController> = emptyList()
    private val callback = object : MediaController.Callback() {
        override fun onMetadataChanged(metadata: MediaMetadata?) = publish()
        override fun onPlaybackStateChanged(state: PlaybackState?) = publish()
        override fun onSessionDestroyed() = refresh()
    }
    private val sessionsChanged = MediaSessionManager.OnActiveSessionsChangedListener { refresh() }

    fun start() {
        runCatching { manager?.addOnActiveSessionsChangedListener(sessionsChanged, listener) }.onFailure { onChange(null); return }
        refresh()
    }

    fun stop() {
        runCatching { manager?.removeOnActiveSessionsChangedListener(sessionsChanged) }
        controllers.forEach { it.unregisterCallback(callback) }
        controllers = emptyList()
    }

    private fun refresh() {
        controllers.forEach { it.unregisterCallback(callback) }
        controllers = runCatching { manager?.getActiveSessions(listener).orEmpty() }.getOrDefault(emptyList())
        controllers.forEach { it.registerCallback(callback) }
        publish()
    }

    private fun publish() {
        onChange(pickNowPlaying(controllers.map { c ->
            val m = c.metadata
            SessionInfo(
                packageName = c.packageName,
                title = m?.getString(MediaMetadata.METADATA_KEY_TITLE) ?: m?.getString(MediaMetadata.METADATA_KEY_DISPLAY_TITLE),
                artist = m?.getString(MediaMetadata.METADATA_KEY_ARTIST) ?: m?.getString(MediaMetadata.METADATA_KEY_DISPLAY_SUBTITLE),
                playing = c.playbackState?.state == PlaybackState.STATE_PLAYING,
                art = m?.getBitmap(MediaMetadata.METADATA_KEY_ART) ?: m?.getBitmap(MediaMetadata.METADATA_KEY_ALBUM_ART)
                    ?: m?.getBitmap(MediaMetadata.METADATA_KEY_DISPLAY_ICON),
            )
        }))
    }
}
