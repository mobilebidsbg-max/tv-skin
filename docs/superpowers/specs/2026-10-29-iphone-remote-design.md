# TV Remote for iPhone: design

Date: 2026-10-29. Status: approved by Dimitar 2026-10-29 ("Go").
Part of the "TV skin" project (own Google TV home screen + iPhone remote + AI). Mockups: `../mockup-v3.html`.

## Why

Dimitar wants to drive his TV from the couch with his iPhone instead of the TCL remote: a remote that feels like Apple's, looks like his own product (black, a little Claude Code orange), and puts every control one gesture away without cluttering the screen. It must also run on a second iOS device in the house.

## Goals

1. An iPhone app that controls the TCL Google TV today, before our own home screen exists.
2. A dotted touchpad: swipe moves the highlight, tap = OK (Apple TV remote style).
3. Rich controls that stay hidden until wanted: playback, volume, apps, TV (input, settings, power), keyboard.
4. A custom app icon: black with a touch of Claude Code orange.
5. Installed on Dimitar's iPhone and on one more iOS device.

## Non-goals (for this version)

- Mouse-pointer mode. It needs our TV app (AccessibilityService) installed on the TV. It comes later as a second touchpad mode.
- Voice and AI ("Ask"). Planned with the TV app.
- Control Center button, lock screen or widgets. Possible later with App Intents. *(My call.)*
- A sleep timer. The protocol can't set one, so it would need our TV app. *(My call: "Sleep" was swapped for "Search" on the TV page.)*
- App Store release.

## Anti-goals (it fails even if it works)

- Laggy or uncertain: every touch must give instant haptic + visual feedback, and the connection state must always be visible.
- Busy: the first screen shows the touchpad and four buttons, nothing more.
- Re-pairing every time: pair once, then it just connects.

## Constraints and facts (checked 2026-10-29)

- TV: TCL "Smart TV Pro", Google TV on Android 14, at 192.168.8.16. Google's remote service (`com.google.android.tv.remote.service`) is installed. Ports 6467 (pairing) and 6466 (remote) are open.
- Protocol: Android TV Remote v2, the one Google's own remote app uses. TLS with a client certificate, varint-length-prefixed protobuf messages. Pairing shows a 6-character code on the TV, and the client proves it with SHA-256 over both certificates' RSA modulus/exponent plus the code. Reference implementation: `tronikos/androidtvremote2` (Python), `.proto` files `polo.proto` and `remotemessage.proto`.
- What the protocol can do: key presses (short, long-press start/end), app launch by link, volume state, power state, text into a focused text field (IME batch edit). It cannot move a mouse pointer.
- Mac: Xcode 26.6 installed. No signing identity yet.
- Signing: free Apple ID (Dimitar's choice). Each device is plugged into this Mac once and needs Developer Mode on. The app has to be re-installed from the Mac every 7 days.

## Decided by Dimitar

- Swipe touchpad now, pointer mode later.
- Free Apple ID.
- iPhone only, no iPad layout. The second device is an iPhone too. *(My call: deployment target iOS 17, so an older second iPhone still works.)*
- Black with a little Claude Code orange (#D97757). Dotted touchpad. Rich controls in hidden menus (play/pause, forward and more).
- Icon: option C, "Ripple" (a 9×9 dot grid glowing orange from the centre, on black). Source: `../mockup-remote.html`.

## The app

**Main screen (black):**
- Top: TV name with a connection dot, and a power button.
- The touchpad fills most of the screen: a grid of small dim dots. Under the finger the dots light up orange and fade as it moves, so you see your touch. Swipe = arrow keys (fast flicks repeat), tap = OK, long press = hold OK. Light haptic tick per move.
- Below the touchpad: Back, Home, Play/Pause, Keyboard.
- A small handle under the buttons pulls up the hidden controls.

**Hidden controls (a sheet you swipe up), four pages:**
1. Playback: previous, back 10 s, play/pause (big, orange), forward 10 s, next; subtitles; stop.
2. Volume: up, down, mute, with the TV's current level shown live.
3. Apps: one-tap launch for YouTube, Netflix, Spotify, Apple TV, Prime Video, HBO Max, Twitch, Google TV home.
4. TV: Input (HDMI 1–3), Settings, Search, Power.

**Hidden gestures on the touchpad:** two-finger tap = play/pause; two-finger swipe left/right = back/forward 10 s; slide up/down along the right edge = volume. A "Gestures" card in the sheet lists them.

**Keyboard:** opens the iPhone keyboard and types into the text field focused on the TV (search boxes).

**First run:** finds the TV on Wi-Fi automatically (Bonjour `_androidtvremote2._tcp`), with manual IP entry as a fallback. Tap it, type the code shown on the TV, done. The pairing is remembered.

## How it gets built (my calls, open to change)

- Repo: `~/Developer/projects/tv-skin` (one repo for the whole product: `ios/` now, `android/` launcher later). Private GitHub repo under mobilebidsbg-max if wanted.
- `TVRemoteKit`: a Swift package with the protocol (minimal hand-written protobuf, pairing, session, discovery). It also builds a small Mac command-line tool, so the protocol is tested against the real TV before any iPhone is involved. Pairing codes in that test are read from a TV screenshot over adb, so no one has to read them out.
- iOS app: SwiftUI, iOS 17+, iPhone only, project generated with XcodeGen.
- Client certificate: each device makes its own RSA certificate on first launch and keeps it in the Keychain, so each device pairs once. *(My call, after the builder check: one shared certificate risks two devices kicking each other off when both are used at the same time.)*
- iPhone volume buttons controlling TV volume: nice to have, added only if it works reliably.
- Icon: drawn as SVG, exported to a 1024 px PNG, with a dark variant.

## Power

The power button sends the TV's power key. If the TV is in deep standby and the remote ports are closed, the app falls back to Wake-on-LAN using the TV's MAC address (read once over adb), and the header shows "TV is off" instead of an error. *(My call. To verify: does this TCL wake from standby over Wi-Fi?)*

## Left to the builder

Exact dot spacing and glow radius, animation timing, swipe thresholds and repeat rate (tune on the device), the order of app shortcuts, and app link URLs per app (verify each on the TV).

## Risks

- Seek ±10 s behaves differently per app (some use media keys, some use left/right). Verify in YouTube and Netflix and pick per app if needed.
- Text input depends on the TV reporting a focused field. Fall back to "type, then press search".
- Free signing: 7-day expiry is a chore. Moving to a paid account later only changes signing.
