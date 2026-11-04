# TV home screen, plan 1: the launcher on the TV

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A launcher app for Dimitar's TCL Google TV with the v5 home screen, Back to…, the sleep timer, Settings and the glass-clock screensaver. It ends installed on the TV and set as Home.

**Architecture:** A single-module Android app in `tv/`. Pure logic (app order, greeting, weather parsing, last app, timer, clock drift) lives in plain Kotlin classes with JVM unit tests. The UI is Jetpack Compose for TV, checked with Paparazzi snapshots. The glass is a pre-blurred copy of the still wallpaper, cropped and feathered; there is no live blur.

**Tech Stack:**
- Kotlin 2.x; Android Gradle Plugin, latest stable; Gradle wrapper; JDK 17 (21 if the chosen AGP needs it)
- Jetpack Compose (BOM) + `androidx.tv:tv-material`
- JUnit 4, Paparazzi (Roborazzi if Paparazzi doesn't support the chosen AGP), `org.json` for JVM tests
- Android command-line tools from Homebrew; an Android TV emulator for the smoke test

**Spec:** `docs/superpowers/specs/2026-11-01-tv-home-screen-design.md`

**Not in this plan (later plans, written after their spikes):**
- **Plan 2:** Spike A (two windows), plus the launcher's shell rights over adb on `localhost:5555`, Side by side with the silent inactive side, and the sleep timer through the shell.
- **Plan 3:** Spike B (data source), then the Netflix/HBO strip with real titles.
- **Plan 4:** the iPhone "Send to TV" share extension.

## Changes after v5 (2026-11-01, Dimitar approved v5; this section wins over the tasks below)

- **Task 1 is done:** `docs/design/mockup-v5.html` and `docs/design/shots/v5-{home,widgets,saver}.png`, commits f459947 to 0fdf88c.
- **Task 4 (home screen) builds the v5 layout:**
  - **Top bar:**
    - the now-playing pill composable, hidden while there is no data (data comes in plan 2);
    - tabs ✦ · Home · Apps · Music · Photos · ⚙;
    - status: weather, short date, time, avatar.
  - **Hero:** greeting + 3 smart buttons (no info line).
  - **Apps row:** tiles use `PackageManager.getApplicationBanner`/`loadBanner`; fallback: the icon centred on a dark glass tile.
  - **"Today" widgets:** Weather card (now + 4 hours) and Quick controls (Sleep timer, Input; the Picture and Sound tiles are hidden until checked).
  - **Netflix/HBO strip last.**
  - Focus on widgets or strip scrolls the rows up 170 dp and hides the hero.
  - Replace `infoLine` with `statusLine(weather: WeatherNow?, date: String, time: String)`.
- **Task 5b (new, after Task 5): Tabs.**
  - **Home**, plus an **Apps** page: a grid of all visible apps, 6 per row, same tiles, hold-OK menu works.
  - **⚙** opens Settings (Task 9).
  - **✦, Music and Photos** show a small toast ("Ask comes later" / "Music comes next" / "Photos come next").
  - Snapshot test: `apps page grid`.
- **Task 7 (weather):** also parse `hourly.temperature_2m`, `hourly.weather_code` and `hourly.time` (`&hourly=temperature_2m,weather_code&forecast_hours=5`) into `List<HourWeather(hour: Int, tempC: Int, code: Int)>`.
  - Test `parse next hours`: 5 entries, hours ascending.
- **Task 10 (screensaver) builds the corner layout instead of the glass clock:**
  - `ClockFace` becomes `SaverFace(time, dateLine, weather, offset)`.
  - Bottom-left: time at 56sp SemiBold plus the date at 14sp.
  - Bottom-right: weather icon, temperature at 56sp, and "Clear · Sofia" at 14sp.
  - Solid white, with a dark gradient over the bottom 34%.
  - `driftOffset` stays.
  - Snapshot: `saver 21_40 on dune`.
- **Not in plan 1, added to the later list:**
  - calendar (Up next);
  - Memories and the Photos tab;
  - the Music tab and now-playing data;
  - Picture mode and Sound output controls.

## Global Constraints

- **Package and versions:**
  - Package `com.dzafirov.tvskin`; minSdk 31, targetSdk 34; debug-signed; installed with `adb install`.
  - TV: Android 14, UI 1920×1080 px at density 320. **Mockup px ÷ 2 = dp**, so the screen is 960×540 dp.
- **The look:**
  - The wallpaper never changes when focus moves. Default wallpaper: Dune (`wall-dune.jpg`, 1920×1080).
  - Blur and slight darkening only behind text: the hero frost, and the darker blurred band behind the rows. Use the pre-blurred wallpaper, never `Modifier.blur` on live content.
  - Dark theme, glass stays dark. "Lighter" means less on screen.
  - Font: Inter (OFL), bundled in `res/font`.
  - Copy in English, in `res/values/strings.xml`.
- **Removed:** no football anywhere, and no Ask (Dimitar moved it to later).
- **Smart buttons, in this order:** Back to <last app> · Side by side · Sleep. Side by side is a placeholder until plan 2 (it shows the "Two windows come next" message).
- **TV safety:**
  - No adb command touches the TV except in tasks marked **(TV free)**. Those tasks start by asking Dimitar whether the TV is free.
  - Every change made to the TV goes into `docs/TV-INSTALL.md` together with its undo command.
- **Performance on the TV:**
  - `am start -W` TotalTime ≤ 1000 ms for a warm start of the launcher.
  - `dumpsys meminfo com.dzafirov.tvskin` TOTAL PSS ≤ 150 MB on the home screen.
- **Commits:**
  - Small and frequent, on branch `feat/tv-launcher`.
  - Messages end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
  - Never push.

## Review Focus

1. **An app is installed or removed while the launcher runs:**
   - Stale packages in the saved order are dropped and new apps are added at the end.
   - Test `arrange drops missing and appends new apps` (Task 3).
2. **No network, or Open-Meteo down or returning garbage:**
   - The info line shows only the time; no crash, no endless spinner.
   - Tests `parse returns null on bad json` and `infoLine without weather` (Task 7).
3. **A sleep timer that outlives its moment** (the TV was off, the launcher was killed, or a reboot happened):
   - An `endsAt` in the past is not running; it never fires late.
   - Test `timer in the past is not running` (Task 8); `BootReceiver` clears the timer (Task 8).
4. **The "last app" would be the launcher itself, Settings or a system UI package:**
   - The button never says "Back to TV Skin" or "Back to Settings".
   - Test `lastApp skips own and ignored packages` (Task 6).
5. **Long app names** (YouTube Music, a long TikTok TV label):
   - Labels truncate with an ellipsis; tiles keep their size.
   - Snapshot `home with long labels` (Task 4).

---

## File structure (`tv/`)

```
tv/
  settings.gradle.kts, build.gradle.kts, gradle/libs.versions.toml, gradlew…
  tools/make_blur.py                      # wallpaper → blurred, darkened copy
  app/build.gradle.kts
  app/src/main/AndroidManifest.xml
  app/src/main/res/{drawable-nodpi,font,values,xml}/
  app/src/main/java/com/dzafirov/tvskin/
    MainActivity.kt                       # hosts Home / Settings, handles Home re-entry
    ui/Theme.kt                           # colours, Inter, type scale, dp sizes
    ui/Frost.kt                           # glass: blurred wallpaper crop with feathered mask
    ui/Wallpapers.kt                      # Wallpaper enum (sharp + blurred drawable ids)
    apps/AppEntry.kt                      # data
    apps/AppArranger.kt                   # pure: order, hide, move
    apps/AppPrefs.kt                      # order, hidden set, wallpaper, sleep default (SharedPreferences)
    apps/AppRepository.kt                 # PackageManager + TvInputManager → entries
    apps/AppLauncher.kt                   # start an entry, record last app
    home/Greeting.kt                      # pure greeting + info line
    home/HomeScreen.kt, home/Hero.kt, home/AppRow.kt, home/PromoStrip.kt, home/AppMenu.kt
    lastapp/LastApp.kt                    # pure pick
    lastapp/LastAppStore.kt               # saved last package
    weather/Weather.kt                    # pure parse + describe
    weather/WeatherRepository.kt          # fetch, 30-min cache
    sleep/SleepTimer.kt                   # pure state
    sleep/SleepScheduler.kt, sleep/SleepReceiver.kt, sleep/BootReceiver.kt
    sleep/Standby.kt                      # interface + DeviceAdminStandby, AdminReceiver
    settings/SettingsScreen.kt
    dream/Drift.kt                        # pure
    dream/ClockFace.kt, dream/ClockDream.kt
  app/src/test/java/com/dzafirov/tvskin/  # unit + snapshot tests (names per task)
```

---

### Task 1: v5 preview in HTML

**Files:**
- Create: `docs/design/mockup-v5.html` (start from `~/Developer/playground/tv-skin/mockup-v4.html`)
- Create: `docs/design/assets/` (copy `wall-dune.jpg` and the other images the page uses)

**Interfaces:** Produces the visual reference for Tasks 4, 9 and 10. Its numbers, in px, are halved to dp in Compose.

- [ ] **Step 1: Make the v5 home screen**
  - Remove everything about football (hero line, card, `kick*` code) and Ask (card, sheet, spark).
  - Smart buttons: Back to YouTube (YouTube banner and name) · Side by side · Sleep.
  - The info line becomes "9° and clear in Sofia · 21:40".
  - One apps row: YouTube, Netflix, HBO Max, Prime Video, Disney+, Apple TV, YouTube Music, then the TV items (Live TV, HDMI 1, Settings).
  - At the bottom, a **Netflix / HBO Max strip** of 4 wide artwork cards (2 per service; use the existing `assets/v3-*.jpg` stills as stand-ins, each with the service's wordmark in small type).
  - Remove the wallpaper switcher.
  - Glass: keep the v4 frost behind the hero, a little thinner (`brightness(.85)`, blur 26px). The band behind the rows starts 40px lower.
- [ ] **Step 2: Add a screensaver view** (key `S` toggles it)
  - The Dune wallpaper, sharp.
  - A clock "21:40" centred, about 300px tall, in a frosted-glass slab: the blurred wallpaper inside, a 1px rgba(255,255,255,.35) edge, radius 48px, and a soft shadow.
  - Below it, "Sunday, 1 November · 9° clear" at 28px.
- [ ] **Step 3: Check it in the browser panel**
  - Serve `docs/design` on 127.0.0.1 (any free port).
  - Open the page, press arrows, `S` and `Esc`, and take a screenshot of each view.
  - Expected: no console errors; no football or Ask text anywhere (`grep -ci 'football\|ask' docs/design/mockup-v5.html` shows only CSS/JS identifiers that are unused, ideally 0).
- [ ] **Step 4: Show Dimitar both screenshots.** Continue with Task 2 unless he objects.
- [ ] **Step 5: Commit** `docs/design/mockup-v5.html docs/design/assets` with the message "v5 home screen and screensaver preview".

### Task 2: Toolchain and an empty launcher that builds

**Files:**
- Create: `tv/settings.gradle.kts`, `tv/build.gradle.kts`, `tv/gradle/libs.versions.toml`, the Gradle wrapper, `tv/app/build.gradle.kts`
- Create: `tv/app/src/main/AndroidManifest.xml`, `MainActivity.kt`, `ui/Theme.kt`, `ui/Wallpapers.kt`, `ui/Frost.kt`
- Create: `tv/tools/make_blur.py`, `res/drawable-nodpi/wall_*.jpg`, `res/font/inter_*.ttf`
- Create: `tv/.gitignore` (`build/`, `.gradle/`, `local.properties`)
- Test: `tv/app/src/test/java/com/dzafirov/tvskin/ui/FrostSnapshotTest.kt`

**Interfaces:**
- Produces:
  - `enum class Wallpaper(val sharp: Int, val blurred: Int) { DUNE, DUNES, RIDGES, GOLDEN }`. DUNE is the default.
  - `@Composable fun TvSkinTheme(content: @Composable () -> Unit)`.
  - `@Composable fun Frost(wallpaper: Wallpaper, modifier: Modifier, feather: Dp = 48.dp, darken: Float = 0.15f)`. It draws the blurred wallpaper aligned to the full screen, clipped to the modifier's bounds, with a radial alpha mask fading to 0 at the edges (`graphicsLayer(compositingStrategy = Offscreen)` + `drawWithContent` + `BlendMode.DstIn`).
  - `object Sizes`: the dp values used by Tasks 4, 9 and 10.

- [ ] **Step 1: Install the tools on the Mac**
  - Run `brew install openjdk@17 gradle` and `brew install --cask android-commandlinetools`.
  - Then `sdkmanager "platforms;android-35" "build-tools;35.0.0"`.
  - Set `JAVA_HOME` and `ANDROID_HOME` for the session.
  - Expected: `java -version` shows 17; `sdkmanager --list_installed` lists both packages.
- [ ] **Step 2: Create the project**
  - Manifest: `MainActivity` exported, with `singleTask` launch mode. Intent filters: MAIN + LAUNCHER + LEANBACK_LAUNCHER, and MAIN + HOME + DEFAULT.
  - Declare `android.software.leanback` and touchscreen both as `required="false"`.
  - Permissions: `QUERY_ALL_PACKAGES`, `INTERNET`, `RECEIVE_BOOT_COMPLETED`, `USE_EXACT_ALARM`.
  - Banner `@drawable/banner` (320×180 dp: Dune crop + "TV Skin" in Inter).
- [ ] **Step 3: Make the blurred wallpapers**
  - Run `tools/make_blur.py <in.jpg> <out.jpg>` (Pillow) with GaussianBlur radius 30 at 1920×1080, brightness ×0.8, JPEG quality 85.
  - Run it for dune, dunes, ridges and golden from `~/Developer/playground/tv-skin/assets/`. Copy the sharp and blurred files into `res/drawable-nodpi` as `wall_<name>.jpg` and `wall_<name>_blur.jpg`.
  - Download Inter (Regular, Medium, SemiBold, Light) from the rsms/inter release into `res/font`.
- [ ] **Step 4: Write the failing snapshot test**
  - `FrostSnapshotTest.frostOnDune`: a 960×540 dp screen with the Dune wallpaper, plus a `Frost` box at x 60, y 300, 520×180 dp holding white text "Good evening".
  - Run `./gradlew :app:recordPaparazziDebug` once, look at the PNG, then `./gradlew :app:verifyPaparazziDebug`.
  - Expected PNG: sharp dunes, and a soft blurred patch with no hard edges behind the text.
- [ ] **Step 5: Implement `Theme.kt`, `Wallpapers.kt` and `Frost.kt` until the snapshot looks right.** Commit the reference PNG.
- [ ] **Step 6: Build**
  - Run `./gradlew :app:assembleDebug test`.
  - Expected: BUILD SUCCESSFUL; `app/build/outputs/apk/debug/app-debug.apk` exists.
- [ ] **Step 7: Commit** `tv/` with the message "TV launcher skeleton: theme, wallpapers, frost".

### Task 3: Which apps show, in what order

**Files:**
- Create: `apps/AppEntry.kt`, `apps/AppArranger.kt`, `apps/AppPrefs.kt`, `apps/AppRepository.kt`, `apps/AppLauncher.kt`
- Test: `tv/app/src/test/java/com/dzafirov/tvskin/apps/AppArrangerTest.kt`

**Interfaces:**
- `data class AppEntry(val id: String, val label: String, val kind: Kind)`
  - `enum Kind { APP, LIVE_TV, INPUT, SETTINGS }`
  - `id` is the package for APP, `tv-input:<inputId>` for INPUT, and `settings` / `live-tv` for the others.
- `object AppArranger`:
  - `fun arrange(installed: List<AppEntry>, order: List<String>, hidden: Set<String>): List<AppEntry>`
  - `fun move(order: List<String>, id: String, delta: Int): List<String>`
  - `val DEFAULT_ORDER: List<String>`
  - `val DEFAULT_HIDDEN: Set<String>`
- `class AppPrefs(context)`:
  - `order: List<String>`
  - `hidden: Set<String>`
  - `wallpaper: Wallpaper`
  - `sleepDefaultMinutes: Int`
- `class AppRepository(context)`:
  - `fun apps(): List<AppEntry>`: LEANBACK_LAUNCHER activities, minus our own package and minus `com.tcl.tv` (Live TV is a TV item).
  - `fun tvItems(): List<AppEntry>`: Live TV; every passthrough input from `TvInputManager` whose type is HDMI, labelled with `loadLabel`; Settings.
- `class AppLauncher(context, lastAppStore)`: `fun open(entry: AppEntry)`.
  - APP: `getLeanbackLaunchIntentForPackage`, falling back to `getLaunchIntentForPackage`.
  - LIVE_TV: launch `com.tcl.tv`.
  - INPUT: `ACTION_VIEW` on `TvContract.buildChannelUriForPassthroughInput(inputId)`.
  - SETTINGS: `Settings.ACTION_SETTINGS`.
  - Records the package for APP.

**Default values** (from the TV, 2026-11-01):
- `DEFAULT_ORDER` = `com.google.android.youtube.tv`, `com.netflix.ninja`, `com.wbd.stream`, `com.amazon.amazonvideo.livingroom`, `com.disney.disneyplus`, `com.apple.atve.androidtv.appletv`, `com.google.android.youtube.tvmusic`, `com.internet.tvbrowser`, `com.android.vending`.
- `DEFAULT_HIDDEN` = every `com.tcl.*` package except `com.tcl.tv`, plus `com.iqiyi.i18n.tv`, `xploretv.android.tv`, `com.google.android.play.games` and `com.android.tv.settings` (Settings is a TV item).
- Apps not in the order come after the ordered ones, alphabetically by label.

- [ ] **Step 1: Write the failing tests**

```kotlin
@Test fun `arrange follows order then label`()        // order [b,a], installed a,b,c(label "C") → [b,a,c]
@Test fun `arrange drops missing and appends new apps`() // order [x,a] (x not installed), installed a,z → [a,z]
@Test fun `arrange removes hidden`()                     // hidden {a} → a absent
@Test fun `default hidden covers tcl bloat but not live tv`() // "com.tcl.dashboard" hidden, "com.tcl.tv" not
@Test fun `move clamps at the ends`()                    // move([a,b,c],"a",-1) == [a,b,c]; move(…,"a",+1) == [b,a,c]
```

Treat `DEFAULT_HIDDEN` as a rule (prefix `com.tcl.` minus `com.tcl.tv`), not a fixed list: expose `fun isHiddenByDefault(id: String): Boolean`.

- [ ] **Step 2: Run** `./gradlew :app:testDebugUnitTest --tests '*AppArrangerTest*'`. Expected: FAIL (unresolved references).
- [ ] **Step 3: Implement** `AppEntry`, `AppArranger`, `AppPrefs`, `AppRepository` and `AppLauncher` as specified above.
- [ ] **Step 4: Run the tests.** Expected: PASS.
- [ ] **Step 5: Commit** with the message "Launcher: app list, order, hidden apps, TV items".

### Task 4: The home screen

**Files:**
- Create: `home/Greeting.kt`, `home/HomeScreen.kt`, `home/Hero.kt`, `home/AppRow.kt`, `home/PromoStrip.kt`
- Modify: `MainActivity.kt` (show `HomeScreen`)
- Test: `home/GreetingTest.kt`, `home/HomeSnapshotTest.kt`

**Interfaces:**
- Consumes: `Frost`, `Wallpaper`, `Sizes` (Task 2); `AppEntry`, `AppRepository`, `AppLauncher` (Task 3).
- Produces:
  - `fun greetingFor(hour: Int): Int`: a string resource. 5–11 → "Good morning", 12–17 → "Good afternoon", 18–4 → "Good evening".
  - `fun infoLine(weather: WeatherNow?, time: String): String`.
  - `data class HomeState(val wallpaper: Wallpaper, val greeting: String, val info: String, val lastApp: AppEntry?, val sleepLeftMinutes: Int?, val apps: List<AppEntry>, val tvItems: List<AppEntry>, val promos: List<AppEntry>)`.
  - `@Composable fun HomeScreen(state: HomeState, actions: HomeActions)`.
  - `interface HomeActions { fun open(e: AppEntry); fun sideBySide(); fun sleep(); fun hold(e: AppEntry); fun settings() }`.
  - `data class WeatherNow(val tempC: Int, val text: String)` in `weather/Weather.kt` (this task creates the file with only this class; Task 7 adds the parser).

**Layout** (dp, from v5 ÷ 2):
- Hero at x 60, y 150. Greeting 32sp SemiBold; info line 14sp at 70% white; smart buttons 50dp tall with radius 15.
- Apps row: tiles 120×68 with labels below at 12sp, one line with ellipsis.
- TV items at the end of the row, after a 16dp gap.
- Promo strip pinned 24dp above the bottom: cards 200×90.
- Frost behind the hero. A blurred band (wallpaper blur, alpha gradient from .0 to .5 starting 30dp above the apps row) behind the rows.
- Focus: scale 1.06 and a soft shadow on the focused item only. Nothing else changes.
- The promo strip shows the Netflix and HBO Max banners (`loadBanner`, falling back to the icon) as large cards and opens the app. Plan 3 replaces its contents.

- [ ] **Step 1: Write the failing tests**

```kotlin
@Test fun `greeting by hour`()   // 7→morning, 13→afternoon, 21→evening, 2→evening
@Test fun `infoLine without weather`() // infoLine(null,"21:40") == "21:40"
@Test fun `infoLine with weather`()    // infoLine(WeatherNow(9,"clear"),"21:40") == "9° and clear in Sofia · 21:40"
// HomeSnapshotTest
@Test fun home()                  // 7 apps, 3 TV items, lastApp YouTube, no timer
@Test fun `home with long labels`() // one label "YouTube Music for TV with a very long name"
@Test fun `home with sleep running`() // sleepLeftMinutes = 42 → Sleep button reads "42 min"
```

- [ ] **Step 2: Run them.** Expected: FAIL.
- [ ] **Step 3: Implement** `Greeting.kt`, then the composables, until the snapshots match v5's look.
  - Use `androidx.tv.material3` `Surface`/`Card` for focusable items.
  - D-pad UP from the apps row goes to the smart buttons; DOWN goes to the promo strip.
- [ ] **Step 4: Run the tests and record the snapshots.** Look at the PNGs: the top half is empty wallpaper; there's no football or Ask.
- [ ] **Step 5: Commit** with the message "Home screen: hero, apps row, TV items, promo strip".

### Task 5: Hold OK: Open, Side by side, Move, Hide

**Files:**
- Create: `home/AppMenu.kt`
- Modify: `HomeScreen.kt`, `AppRow.kt`
- Test: `home/AppMenuSnapshotTest.kt` (move logic is already tested in Task 3)

**Interfaces:**
- Consumes: `AppArranger.move`, `AppPrefs`, `HomeActions.hold` (Tasks 3 and 4).
- Holding OK is a `KEYCODE_DPAD_CENTER` key-down with `repeatCount > 0`, or `isLongPress`.
- The iPhone remote's Hold sends exactly this.

**Behaviour:**
- **Menu:** Open / Side by side / Move / Hide, on a frosted sheet at the right, matching v3.
- **Side by side:** shows a toast "Two windows come next". Plan 2 replaces it.
- **Move:** the tile gets an outline. LEFT/RIGHT calls `move` and saves; OK or BACK ends.
- **Hide:** adds the app to `hidden`, and focus goes to the neighbouring tile.
- TV items show only Open.

- [ ] **Step 1: Write the failing snapshot** `app menu open on YouTube`.
- [ ] **Step 2: Run it.** Expected: FAIL.
- [ ] **Step 3: Implement** the menu and move mode.
- [ ] **Step 4: Run the tests.** Expected: PASS.
- [ ] **Step 5: Commit** with the message "Hold OK menu: open, move, hide".

### Task 6: Back to…

**Files:**
- Create: `lastapp/LastApp.kt`, `lastapp/LastAppStore.kt`
- Modify: `AppLauncher.kt` (record), `MainActivity.kt` (refresh on resume)
- Test: `lastapp/LastAppTest.kt`

**Interfaces:**
- `fun pickLastApp(recent: List<String>, own: String, ignored: Set<String>, launchable: Set<String>): String?`
  - `recent` is newest first.
  - It returns the first entry that is launchable, not own and not ignored.
- `ignored` = `com.android.tv.settings`, `com.google.android.apps.tv.launcherx`, `com.android.systemui`, `com.google.android.tv.remote.service`, `com.tcl.tv`.
- `class LastAppStore(context)`:
  - `fun record(pkg: String)` keeps the newest 10.
  - `fun recent(): List<String>` merges this list with `UsageStatsManager.queryEvents` ACTIVITY_RESUMED for the last 24 h, when usage access is granted. Without access, the merge quietly does nothing.

- [ ] **Step 1: Write the failing tests**

```kotlin
@Test fun `lastApp skips own and ignored packages`() // recent [own, settings, youtube] → youtube
@Test fun `lastApp skips uninstalled`()               // recent [gone, netflix], launchable {netflix} → netflix
@Test fun `lastApp none`()                            // recent [own] → null (button hidden)
```

- [ ] **Step 2: Run them.** Expected: FAIL.
- [ ] **Step 3: Implement** both classes.
  - The hero's first button shows "Back to <label>" with the app banner, and is absent when null.
- [ ] **Step 4: Run them.** Expected: PASS.
- [ ] **Step 5: Commit** with the message "Back to the last app".

### Task 7: Weather for Sofia

**Files:**
- Create: `weather/Weather.kt`, `weather/WeatherRepository.kt`
- Create: `app/src/test/resources/open-meteo-sofia.json`
- Test: `weather/WeatherTest.kt`

**Interfaces:**
- `fun parseOpenMeteo(json: String): WeatherNow?` reads `current.temperature_2m` (rounded) and `current.weather_code`. It returns null on any parse problem.
- `fun describe(code: Int): String`:
  - 0 → "clear"
  - 1–3 → "partly cloudy"
  - 45/48 → "fog"
  - 51–67 → "rain"
  - 71–77 → "snow"
  - 80–82 → "showers"
  - 95–99 → "storms"
  - anything else → "cloudy"
- `class WeatherRepository(context)`: `suspend fun now(): WeatherNow?`.
  - URL: `https://api.open-meteo.com/v1/forecast?latitude=42.6977&longitude=23.3219&current=temperature_2m,weather_code`.
  - Cache 30 min in memory; 5 s timeout; null on any failure.

- [ ] **Step 1: Write the failing tests**

```kotlin
@Test fun `parse current weather`()      // fixture → WeatherNow(9, "clear")
@Test fun `parse returns null on bad json`() // "{" and "{}" → null
@Test fun `describe codes`()             // 0 clear, 2 partly cloudy, 63 rain, 95 storms, 4 cloudy
```

- [ ] **Step 2: Run them.** Expected: FAIL.
- [ ] **Step 3: Implement** the parser and repository. Wire the repository into `HomeState.info`, refreshing on resume.
- [ ] **Step 4: Run them.** Expected: PASS.
- [ ] **Step 5: Commit** with the message "Weather line for Sofia (Open-Meteo)".

### Task 8: Sleep timer

**Files:**
- Create: `sleep/SleepTimer.kt`, `sleep/SleepScheduler.kt`, `sleep/SleepReceiver.kt`, `sleep/BootReceiver.kt`, `sleep/Standby.kt`
- Create: `res/xml/device_admin.xml`
- Modify: the manifest (receivers, admin), `Hero.kt` (Sleep button and picker)
- Test: `sleep/SleepTimerTest.kt`

**Interfaces:**
- `data class SleepTimer(val endsAtMillis: Long?)`
  - `fun minutesLeft(nowMillis: Long): Int?`: rounded up; null when not set or already past.
  - `fun start(nowMillis: Long, minutes: Int): SleepTimer`
  - `fun cancel(): SleepTimer`
- `class SleepScheduler(context)`: `fun set(timer: SleepTimer)`.
  - Saves `endsAt` in prefs.
  - Schedules `AlarmManager.setExactAndAllowWhileIdle(RTC_WAKEUP)` to `SleepReceiver`, or cancels it.
- `interface Standby { fun now() }`
  - `class DeviceAdminStandby(context) : Standby` calls `DevicePolicyManager.lockNow()` when our admin is active.
  - Plan 2 adds a shell-based Standby and picks whichever works.
- `SleepReceiver` calls `Standby.now()` and clears the timer.
- `BootReceiver` clears the timer.
- **Picker:** the Sleep button opens choices 30 / 60 / 90 min / Off. While running, the button reads "N min".

- [ ] **Step 1: Write the failing tests**

```kotlin
@Test fun `minutes left rounds up`()     // ends in 41m10s → 42
@Test fun `timer in the past is not running`() // endsAt < now → null
@Test fun `cancel clears`()              // start(…,30).cancel().minutesLeft(now) == null
```

- [ ] **Step 2: Run them.** Expected: FAIL.
- [ ] **Step 3: Implement** the timer, scheduler, receivers and admin, plus the picker UI.
- [ ] **Step 4: Run them.** Expected: PASS.
- [ ] **Step 5: Commit** with the message "Sleep timer".

### Task 9: Settings

**Files:**
- Create: `settings/SettingsScreen.kt`
- Modify: `MainActivity.kt` (navigate), `HomeActions.settings`
- Test: `settings/SettingsSnapshotTest.kt`

**Behaviour:**
- **Reached by:** a small gear tile at the very end of the apps row, after the TV items. (The TV's own Settings stays a TV item.)
- **Sections:**
  - **Wallpaper:** 4 thumbnails, Dune selected.
  - **Hidden apps:** a list; OK unhides one.
  - **Sleep default:** 30 / 60 / 90.
  - **About:** version, and the line "Changes to the TV: see docs/TV-INSTALL.md on the Mac".
- Frosted panel on the right half; the wallpaper stays.

- [ ] **Step 1: Write the failing snapshot** `settings with two hidden apps`.
- [ ] **Step 2: Run it.** Expected: FAIL.
- [ ] **Step 3: Implement** the screen and persist the choices through `AppPrefs`.
- [ ] **Step 4: Run it.** Expected: PASS.
- [ ] **Step 5: Commit** with the message "Settings: wallpaper, hidden apps, sleep default".

### Task 10: Glass-clock screensaver

**Files:**
- Create: `dream/Drift.kt`, `dream/ClockFace.kt`, `dream/ClockDream.kt`
- Modify: the manifest (the `DreamService` with `BIND_DREAM_SERVICE` and the `android.service.dreams.DreamService` intent filter)
- Test: `dream/DriftTest.kt`, `dream/ClockFaceSnapshotTest.kt`

**Interfaces:**
- `fun driftOffset(minuteOfDay: Int): Pair<Int, Int>`: a dp offset, cycling through 8 positions within ±12 dp so the clock never sits still for long.
- `@Composable fun ClockFace(wallpaper: Wallpaper, time: String, dateLine: String, offset: Pair<Int, Int>)`
  - Clock: 150sp Inter Light (300px in v5) inside a glass slab drawn with `Frost` and `darken = 0.1f`.
  - Slab: 1dp edge at white .35, radius 24dp, soft shadow.
  - Date line: 14sp.
- **`ClockDream`:**
  - Not interactive; fullscreen; screen bright.
  - Hosts a `ComposeView`. Set the lifecycle, view-model-store and saved-state owners on the window's decor view: Compose crashes in a `DreamService` without them.
  - Updates every minute, and reads the weather from `WeatherRepository` (cached).

- [ ] **Step 1: Write the failing tests**

```kotlin
@Test fun `drift stays within 12dp`()      // all minutes 0..1439 → |x|,|y| ≤ 12
@Test fun `drift changes every minute`()  // driftOffset(m) != driftOffset(m+1)
// ClockFaceSnapshotTest: `clock 21_40 on dune`
```

- [ ] **Step 2: Run them.** Expected: FAIL.
- [ ] **Step 3: Implement** `Drift`, `ClockFace` and `ClockDream`.
- [ ] **Step 4: Run them.** Expected: PASS. Look at the PNG next to the v5 screensaver screenshot.
- [ ] **Step 5: Commit** with the message "Glass clock screensaver".

### Task 11: Smoke test in the Android TV emulator (Mac only)

**Files:** none (verification only). Fix any crash in the task that owns the code.

- [ ] **Step 1: Install and start an emulator**
  - `sdkmanager "system-images;android-34;android-tv;arm64-v8a" "emulator"`
  - `avdmanager create avd -n tvskin -k "system-images;android-34;android-tv;arm64-v8a" -d tv_1080p`
  - Start it headless with `-no-window`.
- [ ] **Step 2: Install and open the app**
  - `adb -s emulator-5554 install -r app/build/outputs/apk/debug/app-debug.apk`
  - `adb -s emulator-5554 shell am start -W -n com.dzafirov.tvskin/.MainActivity`
  - Expected: `Status: ok` and no `FATAL` in `adb logcat -d`.
- [ ] **Step 3: Exercise it**
  - Press DPAD keys and a long DPAD_CENTER with `adb shell input keyevent [--longpress]`.
  - Screenshot with `adb exec-out screencap -p`.
  - Expected: home renders as in the snapshots, the menu opens, no crash.
- [ ] **Step 4: Start the screensaver**
  - `adb shell settings put secure screensaver_components com.dzafirov.tvskin/.dream.ClockDream`
  - Then `adb shell cmd dreams start-dreaming` (on API 34; otherwise `am start -n com.android.systemui/.Somnambulator`).
  - Screenshot. Expected: the glass clock, no crash.
- [ ] **Step 5: Stop the emulator.** Commit only if fixes were needed (in their owning task's files).

### Task 12 (TV free): Install on the TV as a normal app

**Files:**
- Create: `docs/TV-INSTALL.md`

- [ ] **Step 1: Ask Dimitar whether the TV is free.** Stop here until he says yes.
- [ ] **Step 2: Install and open**
  - `adb -s 192.168.1.16:5555 install -r tv/app/build/outputs/apk/debug/app-debug.apk`
  - Open "TV Skin" from the Google TV app list (or `am start -W -n com.dzafirov.tvskin/.MainActivity`).
  - Expected: Status ok; TotalTime ≤ 1000 ms on the second (warm) start.
- [ ] **Step 3: Measure**
  - `dumpsys meminfo com.dzafirov.tvskin`: TOTAL PSS ≤ 150 MB.
  - Take screenshots of home, the menu, Settings and the sleep picker.
  - Check that the TV items open Live TV, HDMI and Settings, and that the promo cards open Netflix and HBO Max.
- [ ] **Step 4: Grant and set**, recording each command and its undo in `docs/TV-INSTALL.md`:
  - **Usage access:** `appops set com.dzafirov.tvskin GET_USAGE_STATS allow`. Undo: `… default`.
  - **Device admin:** `dpm set-active-admin com.dzafirov.tvskin/.sleep.AdminReceiver`. Undo: `dpm remove-active-admin …`.
  - **Screensaver:** `settings put secure screensaver_components com.dzafirov.tvskin/.dream.ClockDream`. Undo: put back the value read beforehand with `settings get secure screensaver_components`.
- [ ] **Step 5: Show Dimitar the screenshots** and ask him to try it with the iPhone remote. Note what he says in `docs/TV-INSTALL.md` under "Feedback".
- [ ] **Step 6: Commit** `docs/TV-INSTALL.md` with the message "TV install notes".

### Task 13 (TV free, with Dimitar's OK): Make it the Home button's target

**Files:**
- Modify: `docs/TV-INSTALL.md`

- [ ] **Step 1: Ask Dimitar for his OK.** Explain that Google's home screen is replaced, that one command undoes it, and that Google's "Continue watching" rows go away.
- [ ] **Step 2: Try the HOME role**
  - Run `adb shell cmd role get-role-holders android.app.role.HOME` and record the result.
  - Then `adb shell cmd role add-role-holder android.app.role.HOME com.dzafirov.tvskin 0`.
  - Press Home with `tvremote key HOME`. Expected: our home screen.
- [ ] **Step 3: If Home still opens Google's screen**
  - `adb shell pm disable-user --user 0 com.google.android.apps.tv.launcherx`
  - Press Home. Expected: ours.
  - Undo: `pm enable com.google.android.apps.tv.launcherx`.
- [ ] **Step 4: Check that the rest still works**
  - The remote's Assistant button, Live TV, Settings and inputs.
  - A full restart: `adb reboot`, wait, then press Home.
  - Record everything, including undo commands, in `docs/TV-INSTALL.md`.
- [ ] **Step 5: Commit** with the message "Launcher set as Home on the TV".
