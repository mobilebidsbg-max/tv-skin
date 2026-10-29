# iPhone remote: live acceptance

Fill this in with Dimitar present. Write `Pass` or `Fail` in the Result column and anything odd in Notes (what happened, how long, which app was open). Take the TV over only after asking Dimitar.

| | |
|---|---|
| Date | |
| App commit (`git rev-parse --short HEAD`) | |
| TV | TCL Smart TV Pro, `192.168.8.16`, MAC `44:0f:b4:88:a4:9b` |
| iPhone 1 (model, iOS) | |
| iPhone 2 (model, iOS) | |

## 1. Install and first run (iPhone 1)

| # | Check | Expected | Result | Notes |
|---|---|---|---|---|
| 1.1 | `ios/scripts/install.sh` with the iPhone plugged in | Prints "App installed on <name>" | | |
| 1.2 | Settings → General → VPN & Device Management → trust the developer app | TV Remote opens | | |
| 1.3 | First launch: Local Network prompt | Allow, the TV appears in the list | | |
| 1.4 | Pick the TV, type the code shown on it | Pairing succeeds | | |
| 1.5 | Header after pairing | Shows "Connected" with an orange dot | | |

## 2. Touchpad gestures

| # | Check | Expected | Result | Notes |
|---|---|---|---|---|
| 2.1 | Swipe up | Highlight moves up on the TV | | |
| 2.2 | Swipe down | Highlight moves down | | |
| 2.3 | Swipe left | Highlight moves left | | |
| 2.4 | Swipe right | Highlight moves right | | |
| 2.5 | Fast flick | Repeats the arrow key | | |
| 2.6 | Tap | OK (selects the highlighted item) | | |
| 2.7 | Hold | Long-press menu on the TV (hold OK) | | |
| 2.8 | Two-finger tap, video playing in YouTube | Play / pause | | |
| 2.9 | Two-finger swipe right | Forward 10 s | | |
| 2.10 | Two-finger swipe left | Back 10 s | | |
| 2.11 | Slide up along the right edge | Volume up | | |
| 2.12 | Slide down along the right edge | Volume down | | |
| 2.13 | Every touch gives instant haptic and a dot glow | No lag you can notice | | |

## 3. Main buttons

| # | Check | Expected | Result | Notes |
|---|---|---|---|---|
| 3.1 | Back | Goes back on the TV | | |
| 3.2 | Home | Opens the Google TV home screen | | |
| 3.3 | Play/Pause | Toggles playback | | |
| 3.4 | Keyboard | iPhone keyboard opens | | |
| 3.5 | Handle under the buttons, swipe up | Controls sheet opens with Playback, Volume, Apps, TV | | |

## 4. Controls sheet

### Playback

| # | Check | Expected | Result | Notes |
|---|---|---|---|---|
| 4.1 | Previous | Previous track / item | | |
| 4.2 | Back 10 s | Jumps back about 10 s | | |
| 4.3 | Play/Pause (orange) | Toggles playback | | |
| 4.4 | Forward 10 s | Jumps forward about 10 s | | |
| 4.5 | Next | Next track / item | | |
| 4.6 | Subtitles | Toggles captions | | |
| 4.7 | Stop | Stops playback | | |
| 4.8 | Gestures card | Lists the four touchpad gestures | | |

### Volume

| # | Check | Expected | Result | Notes |
|---|---|---|---|---|
| 4.9 | Volume up (tap) | One step up | | |
| 4.10 | Volume down (tap) | One step down | | |
| 4.11 | Hold volume up / down | Repeats while held | | |
| 4.12 | Mute | Mutes, press again unmutes | | |
| 4.13 | Level readout | Follows the TV's volume live | | |

### Apps

| # | Check | Expected | Result | Notes |
|---|---|---|---|---|
| 4.14 | YouTube | Opens YouTube | | |
| 4.15 | Netflix | Opens Netflix | | |
| 4.16 | Prime Video | Opens Prime Video | | |
| 4.17 | Apple TV | Opens Apple TV | | |
| 4.18 | Disney+ | Opens Disney+ | | |
| 4.19 | YouTube Music | Opens YouTube Music | | |
| 4.20 | Home | Google TV home screen | | |
| 4.21 | All apps | The TV's app list | | |

### TV

| # | Check | Expected | Result | Notes |
|---|---|---|---|---|
| 4.22 | Input | Input picker opens | | |
| 4.23 | HDMI 1 | Switches to HDMI 1 | | |
| 4.24 | HDMI 2 | Switches to HDMI 2 | | |
| 4.25 | HDMI 3 | Switches to HDMI 3 | | |
| 4.26 | Settings | TV settings open | | |
| 4.27 | Search | Google TV search opens | | |
| 4.28 | Power | Puts the TV in standby (see 6.3 for waking it) | | |

## 5. Typing

| # | Check | Expected | Result | Notes |
|---|---|---|---|---|
| 5.1 | Open YouTube search on the TV, tap Keyboard, type a word | The text appears in the TV's search field | | |
| 5.2 | Delete a character, then type a space | Both reach the TV | | |

## 6. Connection and power

| # | Check | Expected | Result | Notes |
|---|---|---|---|---|
| 6.1 | Lock the phone for 1 min, then unlock | Reconnects by itself within 2 s, header shows "Connected" | | |
| 6.2 | Airplane mode on, then off | "Can't reach the TV", then "Connected" | | |
| 6.3 | Power puts the TV in standby, then Power again | The TV wakes. Note which way: protocol POWER key or Wake-on-LAN | | |
| 6.4 | Header while the TV is in standby | "TV is off", not an error | | |

## 7. Second iPhone

| # | Check | Expected | Result | Notes |
|---|---|---|---|---|
| 7.1 | Plug in iPhone 2, Trust, Developer Mode on, run `ios/scripts/install.sh` | Prints "App installed on <name>" | | |
| 7.2 | Pair iPhone 2 (its own code) | Header shows "Connected" | | |
| 7.3 | iPhone 2: swipe, tap, Play/Pause | All three work | | |
| 7.4 | Both phones connected, press keys on each in turn | Both work, neither kicks the other off | | |
| 7.5 | Leave both connected for a minute, then use each | Both still "Connected" | | |

## Deferred live TV checks

These need the real TV and Dimitar in the room. They do not depend on the iPhone being installed, except where noted.

| # | Check | Expected | Result | Notes |
|---|---|---|---|---|
| D.1 | Pair from the Mac CLI with a real code: `tvremote pair --host 192.168.8.16` | Prints `CODE_ON_TV`, then `PAIRED` after the code from the TV | | |
| D.2 | Pair from the Mac CLI with a wrong code | Prints an error name and exits with status 1, the TV is not paired | | |
| D.3 | `tvremote watch --host 192.168.8.16 --seconds 60` | Stays open across at least 3 pings, no `closed(...)` line | | |
| D.4 | `tvremote key` HOME, DOWN, RIGHT, OK | Each does the expected thing on the TV | | |
| D.5 | `tvremote key --host 192.168.8.16 OK --long` | Long-press OK menu appears | | |
| D.6 | Choose `Seek.forward` / `Seek.backward` by testing `fastForward` vs `skipForward` vs `dpadRight` in a YouTube video (`tvremote key --host 192.168.8.16 FAST_FORWARD`, then `SKIP_FORWARD`, then `DPAD_RIGHT`; same for the backward keys) | Pick the key that jumps about 10 s and write it down | | |
| D.7 | Verify each AppShortcut link opens the right package (YouTube, Netflix, Prime Video, Apple TV, Disney+, YouTube Music) | Each opens its own app; fix the link if not | | |
| D.8 | Typing via SEARCH + text: `tvremote key --host 192.168.8.16 SEARCH`, then `tvremote text --host 192.168.8.16 "hello"` | The word appears in the search field | | |
| D.9 | Does POWER over the protocol, or Wake-on-LAN (`tvremote wake --mac 44:0f:b4:88:a4:9b`), wake the TV from standby? | Note which of the two works (or both, or neither) | | |

## Result

| | |
|---|---|
| Passed | |
| Failed | |
| Open issues to fix | |
