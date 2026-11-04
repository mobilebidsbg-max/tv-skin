# TV skin

Dimitar's own Google TV experience: an iPhone remote now, a custom home screen (launcher) and AI later.

- `ios/` — iPhone remote (SwiftUI) and `TVRemoteKit` (Android TV Remote v2 protocol + `tvremote` Mac CLI).
- `docs/superpowers/specs/` — designs. `docs/superpowers/plans/` — implementation plans.
- `docs/design/` — HTML mockups (home screen v3, remote).
- `docs/ACCEPTANCE.md` — live acceptance checklist for the iPhone app.

TV: TCL "Smart TV Pro", Google TV / Android 14, `192.168.1.16` on the home Wi-Fi.

## iPhone app — install

One-time setup (free Apple ID, no paid developer account needed):

1. Xcode → Settings → Accounts → add your Apple ID.
2. Plug the iPhone into the Mac and tap **Trust** on the phone.
3. On the iPhone: Settings → Privacy & Security → Developer Mode → On (the phone restarts).
4. On the Mac, from anywhere: `ios/scripts/install.sh`. It finds your signing team by itself; if it cannot, set `TV_TEAM_ID` in the environment or in `.env` (see `.env.example`). `--dry-run` only prints the commands.
5. On the iPhone: Settings → General → VPN & Device Management → trust the developer app. Then open **TV Remote**, allow Local Network, pick the TV and type the code shown on it.

Every connected iPhone gets the app in one run. Each phone pairs with the TV on its own, so two phones can be used at the same time.

## Renewal every 7 days (automatic, over Wi-Fi)

A free Apple ID signs the app for 7 days. The Mac renews it by itself:

- Every evening at 20:30 launchd runs `ios/scripts/renew.sh` (job `com.dzafirov.tvskin.renew-remote`, a copy of it is in `ios/scripts/`).
- It does nothing until a phone's last renewal is 5 days old. Then it runs `install.sh`, which installs over Wi-Fi on every iPhone at home. No cable is needed after the first install.
- Renewals are recorded in `~/.tvskin/remote-renewed/<phone name>`; the log is `~/Library/Logs/tvskin-renew-remote.log`.
- A phone that is still not renewed after 6 days gets a Mac notification. Keep it on the home Wi-Fi that evening, or run `ios/scripts/renew.sh --force`.
- The Mac has to be on (asleep is fine; the check runs when it wakes). The pairing with the TV is kept.

**A new iPhone:** do steps 2, 3 and 5 of the install above once with a cable, but run `ios/scripts/renew.sh --force` instead of `install.sh` so the phone is recorded. From then on it renews with the others.

**Set the job up again** (e.g. on a new Mac): `cp ios/scripts/com.dzafirov.tvskin.renew-remote.plist ~/Library/LaunchAgents/ && launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.dzafirov.tvskin.renew-remote.plist`. **Remove it:** `launchctl bootout gui/$(id -u)/com.dzafirov.tvskin.renew-remote`, then delete the file. Tests: `ios/scripts/renew_test.sh`.

## Mac CLI

`tvremote` is built from `ios/TVRemoteKit`. Run it from there with `swift run tvremote <command>`; the Mac keeps its own pairing in `ios/TVRemoteKit/.tvremote/`.

```sh
cd ios/TVRemoteKit
swift run tvremote discover                                  # list TVs on the network
swift run tvremote pair --host 192.168.1.16                  # code appears on the TV, type it here
swift run tvremote key --host 192.168.1.16 HOME              # press a key (add --long to hold it)
swift run tvremote app --host 192.168.1.16 https://www.youtube.com
swift run tvremote text --host 192.168.1.16 "hello"          # type into the focused field on the TV
swift run tvremote watch --host 192.168.1.16 --seconds 30    # print what the TV reports
swift run tvremote wake --mac 00:11:22:33:44:55              # Wake-on-LAN
```

`swift run tvremote help` lists every command and key name.
