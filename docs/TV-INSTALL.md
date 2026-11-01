# TV Skin on the TV: what was changed, and how to undo it

TV: TCL Smart TV Pro, Google TV / Android 14, `192.168.8.16`.
Connect first: `adb connect 192.168.8.16:5555`. Every command below is run from the Mac and starts with `adb -s 192.168.8.16:5555`.

## Changes (2026-11-01)

| # | Change | Command used | Undo |
|---|---|---|---|
| 1 | Installed the launcher app `com.dzafirov.tvskin` (debug build) | `install -r tv/app/build/outputs/apk/debug/app-debug.apk` | Undo 3 first, then `uninstall com.dzafirov.tvskin` |
| 2 | Usage access, so "Back to…" also sees apps opened with the phone or the TV remote | `shell appops set com.dzafirov.tvskin GET_USAGE_STATS allow` | `shell appops set com.dzafirov.tvskin GET_USAGE_STATS default` |
| 3 | Device admin (only the "lock screen" policy), so the sleep timer can put the TV in standby | `shell dpm set-active-admin --user 0 com.dzafirov.tvskin/.sleep.AdminReceiver` | `shell am start -n com.dzafirov.tvskin/.MainActivity --ez remove_admin true`. Android refuses `dpm remove-active-admin` for this app, so the app switches its own admin off. Verified on the TV: logcat "Device admin … removed from user 0". |
| 5 | Media-session access (only for the "now playing" pill; reads no notifications) | `shell cmd notification allow_listener com.dzafirov.tvskin/com.dzafirov.tvskin.media.MediaListener` | `shell cmd notification disallow_listener com.dzafirov.tvskin/com.dzafirov.tvskin.media.MediaListener` |
| 4 | Screensaver: the TV Skin clock (corner clock + weather on the Dune wallpaper) | `shell settings put secure screensaver_components com.dzafirov.tvskin/.dream.ClockDream` (it was `null` before, meaning Google's default) | `shell settings delete secure screensaver_components` |

| 6 | TV Skin is the home screen (Dimitar's OK, 2026-11-01) | `shell cmd role add-role-holder android.app.role.HOME com.dzafirov.tvskin 0` (before: `com.google.android.apps.tv.launcherx`) | `shell cmd role add-role-holder android.app.role.HOME com.google.android.apps.tv.launcherx 0` |
| 7 | Google's home screen switched off for user 0 (Home ignored the role while it was on) | `shell pm disable-user --user 0 com.google.android.apps.tv.launcherx` | `shell pm enable com.google.android.apps.tv.launcherx` |
| 8 | Google's setup app switched off for user 0. Its "RecoveryActivity" catches Home when the launcher is off, and Android doesn't let adb switch off a single screen of another app. | `shell pm disable-user --user 0 com.google.android.tungsten.setupwraith` | `shell pm enable com.google.android.tungsten.setupwraith` |

| 9 | Free-form windows switched on (side by side), then a reboot | `shell settings put global enable_freeform_support 1` and `shell settings put global force_resizable_activities 1` (both were `null`) | `shell settings delete global enable_freeform_support`, `shell settings delete global force_resizable_activities`, reboot |
| 10 | Key service "TV Skin side by side" (accessibility, key filtering only; it acts only while side by side is on) | `shell settings put secure enabled_accessibility_services com.dzafirov.tvskin/com.dzafirov.tvskin.split.SplitKeys` and `shell settings put secure accessibility_enabled 1` (before: empty and `0`) | `shell settings delete secure enabled_accessibility_services` and `shell settings put secure accessibility_enabled 0` |
| 11 | TV Skin's own adb key, approved on the TV with "Always allow", so the launcher can open windows, resize and mute them without the Mac | First side by side from the TV shows "Allow USB debugging? TV Skin@tv" | TV Settings → Developer options → Revoke USB debugging authorizations (this also revokes the Mac's) |

**Full undo of the home-screen switch:** run the undo of 8, 7 and 6, then press Home. A factory reset also restores everything.

**What happened while switching (2026-11-01 23:58):**
- Right after change 8 the TV went into standby (it did not reboot; uptime stayed 21 days).
- On waking it didn't rejoin Wi-Fi by itself until Dimitar connected it.
- After a full restart (`adb reboot`) it starts straight into TV Skin, rejoins Wi-Fi `A1_FB646F` by itself, and Home opens TV Skin.

- `screensaver_enabled` was already `1`; it was left as it was.

**Updating the app (release build, used since 2026-11-01):**
1. `cd tv && ./gradlew :app:assembleRelease`
2. `install -r tv/app/build/outputs/apk/release/app-release.apk`
3. `shell cmd package compile -m speed-profile -f com.dzafirov.tvskin` (applies the startup profile now instead of later)

This works over Wi-Fi, needs no cable, and keeps all settings.

**Netflix/HBO titles:** put `TMDB_API_KEY=…` in the repo's `.env`, then update the app. Without a key the strip shows the two apps' banners.

**Starting the screensaver now (for testing):** `shell am start -a com.google.android.pano.action.SLEEP`

## Measured on the TV (round 2, release build with the 4K wallpaper surface)

| | Before (debug, 2026-11-01 22:40) | Now |
|---|---|---|
| Typical frame while scrolling the apps row | 53 ms, 52% late frames | 17 ms, 4% late frames |
| GPU per frame | 18–20 ms | 8 ms |
| Start from scratch | 4.9–5.2 s | 0.8–2.0 s |
| Memory (TOTAL PSS) | 122–132 MB | 88–102 MB (includes the cached 4K wallpaper, 33 MB) |

- Google's own home screen on this TV, for reference: 22 ms typical frame, 2.6% late.
- **Wallpaper:** a 3840×2160 SurfaceView, composed by the TV's hardware (SurfaceFlinger: buffer 3840×2160, DEVICE); the UI stays 1920×1080. The screensaver uses the same 4K path.

## Measured on the TV (round 1)

| | Result | Limit |
|---|---|---|
| Warm start (`am start -W`) | 302 ms | ≤ 1000 ms |
| Cold start (after force-stop) | 4.9–5.2 s | not set; a debug build. A release build with R8 and a baseline profile comes next. |
| Memory, home screen (`dumpsys meminfo`, TOTAL PSS) | 121–132 MB | ≤ 150 MB |
| Crashes (`logcat` FATAL) | none | |

## Checked on the TV

- **Home screen:** shows every app's own logo and live Sofia weather. "Back to Netflix" / "Back to YouTube" appear after using those apps.
- **Hold OK on a tile** (also as the phone remote sends it, `tvremote key OK --long`):
  - the menu opens and stays open;
  - Back closes it;
  - a short OK opens the app.
- **Tiles:**
  - Live TV opens `com.tcl.tv`;
  - the "A1 Smart…" HDMI input switches to it through `com.tcl.tv`;
  - the Netflix card in the strip opens Netflix.
- **TV items at the end of the row:** Live TV, A1 Smart…, HDMI 1, HDMI 2, HDMI 3, HDMI 4, Settings.
- **Screensaver:** starts and shows the time, the date and the weather.

## Feedback

(Dimitar, after trying it with the iPhone remote.)
