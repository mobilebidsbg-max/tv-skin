# TV Skin on the TV: what was changed, and how to undo it

TV: TCL Smart TV Pro, Google TV / Android 14, `192.168.8.16`.
Connect first: `adb connect 192.168.8.16:5555`. Every command below is run from the Mac and starts with `adb -s 192.168.8.16:5555`.

## Changes (2026-11-01)

| # | Change | Command used | Undo |
|---|---|---|---|
| 1 | Installed the launcher app `com.dzafirov.tvskin` (debug build) | `install -r tv/app/build/outputs/apk/debug/app-debug.apk` | Undo 3 first, then `uninstall com.dzafirov.tvskin` |
| 2 | Usage access, so "Back to…" also sees apps opened with the phone or the TV remote | `shell appops set com.dzafirov.tvskin GET_USAGE_STATS allow` | `shell appops set com.dzafirov.tvskin GET_USAGE_STATS default` |
| 3 | Device admin (only the "lock screen" policy), so the sleep timer can put the TV in standby | `shell dpm set-active-admin --user 0 com.dzafirov.tvskin/.sleep.AdminReceiver` | `shell am start -n com.dzafirov.tvskin/.MainActivity --ez remove_admin true`. Android refuses `dpm remove-active-admin` for this app, so the app switches its own admin off. Verified on the TV: logcat "Device admin … removed from user 0". |
| 4 | Screensaver: the TV Skin clock (corner clock + weather on the Dune wallpaper) | `shell settings put secure screensaver_components com.dzafirov.tvskin/.dream.ClockDream` (it was `null` before, meaning Google's default) | `shell settings delete secure screensaver_components` |

**Not changed yet:**
- The Home button still opens Google's home screen. Making TV Skin the home screen is a separate step that waits for Dimitar's OK.
- `screensaver_enabled` was already `1`; it was left as it was.

**Updating the app:** `cd tv && ./gradlew :app:assembleDebug` and then command 1 again. This works over Wi-Fi, needs no cable, and keeps all settings.

**Starting the screensaver now (for testing):** `shell am start -a com.google.android.pano.action.SLEEP`

## Measured on the TV

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
