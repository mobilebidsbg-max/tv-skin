# TV home screen ("TV skin"): design

Date: 2026-11-01. Status: approved by Dimitar 2026-11-01 ("build it"; answers to the builder-check questions the same day).
Part of the "TV skin" project. The iPhone remote is already built and installed (`2026-10-29-iphone-remote-design.md`).
Visual source of truth: `~/Developer/playground/tv-skin/mockup-v4.html` (copy it to `docs/design/` when building).

## Why

Dimitar wants his TCL Google TV to feel like his own product: a calm, Apple-like home screen with no ads or clutter, which does a few useful things. He uses the TV with the iPhone remote we built. The things he cares about most are a clean look and **two apps on screen at once** (YouTube, TikTok and similar).

## Decided by Dimitar

1. **v4 is the final design.** He wants it "cleaner, more modern and lighter" than v4, with the "clean Apple aesthetic".
2. **The wallpaper stays still.** Focusing an app never changes the wallpaper or the top area (decided 2026-10-30 for v4). The wallpaper is his Dune aerial shot with the logo removed: `assets/wall-dune.jpg`, 1920×1080. Blur and a little darkening go only where text sits.
3. **Netflix and HBO Max "ads" at the bottom of the home screen,** done "in a beautiful way". Read this as a promo strip of their titles, not banner ads.
4. **Two windows is very important.** The apps he means are YouTube, TikTok and the like (TikTok is not installed yet; he plans to install it).
5. **Screensaver:** the desert wallpaper with a big glass digital clock, Apple style.
6. **Features:** he left them to me and accepted this list. **No football:** he is not a football fan, so drop every football element from v4.
   - Two windows ("Side by side")
   - Netflix / HBO Max strip
   - Screensaver
   - Send to TV (from the iPhone)
   - Sleep timer
   - Only your apps
   - Back to… (last app)
7. **"Lighter" means less on screen,** not lighter colours. The dark glass stays (his answer, 2026-11-01).
8. **Ask (Claude) waits until later** (his answer, 2026-11-01).
9. **Do not touch the TV while he is watching.** The build happens on the Mac. Installing, restarts and tests on the TV happen only after he says the TV is free.

## Goals

1. A home screen app ("launcher") on the TV that replaces the Google TV home and opens when he presses Home.
2. The v4 look, made lighter (see "Lighter" below).
3. Side by side: two apps on screen together, set up in two presses.
4. A screensaver: the Dune shot plus a big frosted-glass clock.
5. The small useful features from the list above.

## Non-goals (this version)

- Football, sports scores, a TV guide.
- Watch history inside other apps. The launcher cannot see which episode you are on; "Back to…" names only the app.
- Accounts or profiles, kids mode.
- Play Store release. Side-loaded over adb only.
- A mouse pointer driven by the iPhone touchpad. It comes later.
- **Ask (Claude).** Dimitar moved it to later. Notes on how it would work are kept under "Calls settled after the builder check".

## Anti-goals (it fails even if it works)

- **Looks like Google TV:** busy rows, promo clutter, banner ads. The Netflix/HBO strip must look like part of the design.
- **Laggy.** The TV has 2.4 GB RAM with about 600 MB free. Focus moves must feel instant, and Home must come up in about a second.
- **Anything irreversible.** No root. Every change to the TV is an adb setting or app install that one command undoes, or that a factory reset clears. Each undo command gets written down.
- **Taking over the TV unannounced.**

## Facts and constraints (checked 2026-10-29 to 11-01)

- **TV:** TCL "Smart TV Pro" (G08), Google TV, Android 14 (SDK 34), MediaTek MT9689, 4K panel with a 1920×1080 UI. IP `192.168.1.16`, adb over the network on port 5555; the Mac is authorized.
- **Stock home screen:** `com.google.android.apps.tv.launcherx/.home.HomeActivity`. Live TV is `com.tcl.tv`.
- **Installed apps** include:
  - YouTube `com.google.android.youtube.tv`
  - YouTube Music `com.google.android.youtube.tvmusic`
  - Netflix `com.netflix.ninja`
  - Prime Video `com.amazon.amazonvideo.livingroom`
  - Apple TV `com.apple.atve.androidtv.appletv`
  - Disney+ `com.disney.disneyplus`
  - HBO Max `com.wbd.stream`
  - TV browser `com.internet.tvbrowser`
  - iQIYI, TCL Channel, `xploretv.android.tv`
- **Freeform windows** are not declared by the system, and `enable_freeform_support` and `force_resizable_activities` are unset. Whether they work after switching them on is **untested** (see Spike A).
- Other apps' data (Netflix/HBO titles, watch progress) is generally not visible to a third-party launcher (see Spike B).
- **Mac toolchain:** no JDK, no Android SDK, no Gradle yet. About 90 GB of disk is free.
- **SF Pro cannot ship** on Android (Apple license).
- **Typing from the iPhone remote** reaches only real Android text fields. YouTube's own search keyboard does not count. Our launcher's text fields are real ones, so typing into them works.
- **The TV keeps one remote pairing per certificate name** (found 2026-11-01, fixed in the remote).

## The home screen

The layout is v4 with football removed, made lighter.

**Top to bottom:**
1. **Empty top half:** the Dune wallpaper, sharp.
2. **Hero, bottom left of the top half:**
   - the greeting ("Good evening");
   - one line: weather for Sofia and the time;
   - a row of three smart buttons:
     - **Back to <last app>**, with the app's banner;
     - **Side by side**;
     - **Sleep**, which shows the remaining time when a timer is running.
   - A soft frost (blurred, slightly darkened wallpaper) sits only behind this text.
3. **Your apps:** one row of his apps in his order. The end of the row holds the TV items: Live TV, HDMI inputs and Settings. Hidden apps never appear.
4. **Netflix / HBO Max strip** at the bottom: wide artwork cards on the darker blurred band. One press opens the title, or the app if a title can't be opened.

**"Lighter" (Dimitar: less on screen; the details below are my calls):**
- fewer elements: one app row instead of several;
- no wallpaper switcher on the home screen (it moves to Settings);
- shorter text;
- thinner, more transparent glass;
- more empty wallpaper;
- a dark theme kept, with nothing turned white.

**Hold OK on an app** (as in v3) opens:
- Open
- Side by side
- Move
- Hide

**Focus:**
- Apple TV style: the focused card lifts and scales slightly with a soft shadow.
- Nothing else on screen changes on focus.

**Font:** Inter (open licence) as the closest free match to SF. *My call.*

## Side by side (two windows)

**Target behaviour:**
1. Choose Side by side, either from a smart button or by holding OK on an app.
2. Pick the second app.
3. The two apps appear left and right: 50/50, or 70/30 with one press.
4. A key or the iPhone moves control from one side to the other; the active side gets a thin light outline.
5. One press swaps the sides. Home or Back closes the split.

**How:** Spike A finds out what the TV can do. Expected routes, best first:
1. **Android freeform windows**, switched on over adb. The launcher starts each app with launch bounds through `ActivityOptions`. Moving control between sides and swapping likely needs our own accessibility service, switched on over adb, to catch a key and bring the other task to the front (`REORDER_TASKS`).
2. **Picture-in-picture** for apps that support it, as a 70/30 fallback.
3. **Inside our launcher**, if Android windows fail: two web views showing the YouTube and TikTok web players. This is weaker, as it means no app logins and possible ads, so tell Dimitar before choosing it.

**Sound (Dimitar's choice: "playing silently, not pausing"; it does not need the Mac):** the side not in use keeps playing silently, and the sound follows the active side. A normal app cannot mute another app, so the launcher gets shell rights on the TV itself (see "Shell rights" below). It mutes the inactive app's audio with app-ops (`appops set <pkg> PLAY_AUDIO ignore`; the builder verifies this mutes a playing app on this TV) and restores it on switch or close. If muting doesn't work, tell Dimitar before falling back to anything else; pausing is not what he wants.

**Known risks:**
- DRM apps (Netflix, HBO Max, Prime, Disney+) may show black or refuse in a window.
- Low RAM may kill the second app.
- Write down which apps work.

## Screensaver

- An Android screensaver (`DreamService`) that shows the Dune wallpaper, still.
- On top, a big digital clock (hours:minutes) in frosted glass: blurred wallpaper inside the digits or a glass slab behind them, a thin light edge, and a soft shadow.
- Below it, the date and the weather in small type.
- To avoid burn-in, the clock drifts a few pixels each minute.
- Google TV hides third-party screensavers in its settings, so it is set over adb (`settings put secure screensaver_components …`). The undo command gets written down.

## The other features

| Feature | Behaviour | Notes |
|---|---|---|
| **Back to…** | Smart button with the last app used; one press reopens it | Tracks apps opened from the launcher. Usage-stats access granted over adb catches apps opened elsewhere. |
| **Sleep timer** | 30 / 60 / 90 min, or off; at the end the TV goes to standby, exactly like the power button | Uses the shell rights below (`input keyevent KEYCODE_SLEEP`, or POWER), so the result matches the real power button. |
| **Only your apps** | Hold-menu Hide, and Settings lists hidden apps to bring back | Hiding is only in our launcher. Disabling bloat packages over adb is a separate step that needs Dimitar's OK per package. |
| **Send to TV** (iPhone) | In iOS share sheet → TV Remote, the link opens on the TV | A share extension in the existing iPhone app, using the existing pairing (shared keychain). YouTube links open the YouTube app. TikTok links are untested until TikTok is installed. Others open in the TV browser. |
| **Weather** | Sofia, current temperature and condition | Open-Meteo, no key. |
| **Settings** (small) | Wallpaper choice (Dune default), hidden apps, sleep timer default, about | Reached from the end of the apps row. |

## Netflix / HBO Max strip

Spike B decides the data source:
1. **Best:** the titles these apps publish to Android TV's home screen (preview channels in the TV provider), with their own artwork and deep links. Check on the TV, read-only, whether Netflix and HBO Max publish them and whether a non-system app can read them. They are normally restricted to the system launcher.
2. **Fallback:** "Popular on Netflix / HBO Max in Bulgaria" from TMDB (free key, attribution required). It provides backdrop art and titles. A press opens the app, or its search for that title if a search link works.
3. **Minimum:** if neither works, the strip shows the two apps' own TV banners as large cards.

## How it gets made (my calls)

- **Language and UI:** Kotlin with Jetpack Compose for TV (`androidx.tv`).
- **SDK levels:** minSdk 31, targetSdk 34.
- **Build:** Gradle wrapper.
- **Tools:** JDK 17 and the Android command-line tools from Homebrew; SDK platform 34 plus build-tools. Expect several GB of downloads.
- **Package:** `com.dzafirov.tvskin`. Debug-signed, installed with `adb install` over the network.
- **Repo:** `~/Developer/projects/tv-skin`, new folder `tv/`, new branch `feat/tv-launcher` from `feat/iphone-remote`. The iPhone share extension goes in `ios/` on the same branch.
- **Glass without live blur:** the wallpaper never moves, so the blurred and darkened areas use a pre-blurred copy of the wallpaper cropped to each glass shape. This is cheap on a 2.4 GB TV.
- **Shell rights on the TV, with no Mac needed (my call):** the launcher connects to the TV's own developer connection (adb on `localhost:5555`, which is already switched on for the Mac) with its own key. Dimitar accepts it once on the TV ("Always allow"). It uses this to mute or unmute a side, to resize and move the two windows, to send the TV to standby for the sleep timer, and to grant itself the permissions above (usage stats, notification listener, accessibility). The Mac does not have to be on. The builder must check that the developer connection comes back after a TV restart (power off at the wall). If it doesn't, the features that need it fall back gracefully (both sides play sound; the sleep timer tries `lockNow()`), and Dimitar is told that one command from the Mac re-enables it after a restart.
- **Making it the Home button's target,** with Dimitar's OK at that moment, in this order:
  1. Give our app the HOME role over adb (`cmd role add-role-holder android.app.role.HOME com.dzafirov.tvskin`).
  2. If that doesn't take, disable the stock launcher for the user (`pm disable-user --user 0 com.google.android.apps.tv.launcherx`).
  3. Last resort: our accessibility service sends Home to us.
  Each undo command is written down.
- **What is lost without the stock home screen:** Google's "Continue watching" rows, the profile switcher, and Google's own ads. The remote's Assistant button, the settings and Live TV keep working through their own system apps. The builder confirms this on the TV.

## Order of work

1. Mac toolchain, plus the launcher showing the home screen on the Mac emulator or in Compose previews. **No TV needed.**
2. *(TV free)* Install on the TV as a normal app, open it from the app list, and check the look, speed and memory.
3. *(TV free)* **Spike A: two windows.** One TV restart. Record what works, then build Side by side on that route.
4. *(TV free, with OK)* Make it the Home button's target.
5. Screensaver, then set it over adb *(TV free)*.
6. Back to…, Sleep timer, Only your apps, Settings, Weather.
7. **Spike B: the data source**, then the Netflix/HBO strip.
8. iPhone share extension (Send to TV), installed with `ios/scripts/install.sh`.

## Calls settled after the builder check (mine)

- **Language:** English, as in the mockups. All text goes in resource files.
- **Ask, when it comes back:** the key lives in the Mac's `.env` (never in git or the APK) and is pushed into the app's private storage over adb. The model and tools are chosen then.
- **A v5 HTML preview comes first:** before the Compose screens are built, update the mockup to v5 (less on screen, no football, no Ask, the Netflix/HBO strip, the screensaver). Show it to Dimitar in the browser; building continues unless he objects.
- **iPhone scope:** only the share extension. If a free Apple ID can't sign an extension with a shared keychain, fall back to a "Send link" field inside the app.

## Left to the builder

- Package structure, state handling, and how the hero and rows are composed.
- Exact sizes, timings and animation curves, matched to v4.
- The key used to move control between the two sides, once it is known what keys reach an accessibility service.
- Tests: unit tests for logic (app order, hidden apps, sleep timer, last app) and screenshots from the TV over adb for the look.
- A short `docs/TV-INSTALL.md` listing every adb change made to the TV, with its undo command.

## v5 (approved by Dimitar 2026-11-01): what changed on top of the text above

The visual reference is now `docs/design/mockup-v5.html` with screenshots in `docs/design/shots/`. Where this section and the text above disagree, this section wins.

1. **Top bar from v4, which Dimitar asked to bring back:**
   - **Left:** a now-playing pill (cover art, title, artist, moving bars), shown only while something plays.
   - **Centre:** glass tabs ✦ · Home · Apps · Music · Photos · ⚙.
   - **Right:** weather icon and temperature, short date, time, and the avatar "D".
   - The ✦ (Ask) does nothing until Ask is built; it shows "Ask comes later".
2. **Hero:**
   - "Good evening" plus the three smart buttons (Back to… · Side by side · Sleep).
   - No weather/time line under the greeting; the top bar has it.
3. **Rows, top to bottom:**
   - **Apps:** his apps, then Live TV / HDMI / Settings.
   - **"Today" widgets from v4**, which Dimitar asked to bring back:
     - Weather (now + next 4 hours);
     - Up next (calendar);
     - a Memories photo card;
     - Quick controls (Sleep timer, Input, Picture mode, Sound output).
   - **The Netflix / HBO Max strip, last.** Moving focus down to the widgets or the strip scrolls the rows up and hides the hero.
4. **Original logos (Dimitar, 2026-11-01):** app tiles show each app's own TV banner from the app itself (`loadBanner`). Without a banner, the app's icon sits centred on a dark glass tile. There are no hand-drawn logos.
5. **Screensaver (Dimitar, 2026-11-01):**
   - No glass clock.
   - A small solid-white clock with the date in the bottom-left corner, and the weather (icon, temperature, "Clear · Sofia") in the bottom-right corner.
   - The Dune wallpaper, sharp, with a soft dark gradient at the bottom.
   - My call: both corners drift a few px each minute against burn-in. Dimitar may still move the clock to the top.
6. **Pieces whose data source is still unknown.** Each is checked before it is built, and its widget part stays hidden until it works:
   - **Calendar:** probably Google Calendar's private iCal link.
   - **Memories and the Photos tab:** depends on where his photos live.
   - **Picture mode and Sound output:** whether TCL lets another app change them.
   - **Music tab and now-playing pill:** media sessions need notification-listener access, granted over the shell rights in plan 2.
   - **Photos tab contents:** I propose them before building.
