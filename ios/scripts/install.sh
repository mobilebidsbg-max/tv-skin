#!/usr/bin/env bash
# Build the TV Remote app for every connected iPhone and install it there.
#
# usage: ios/scripts/install.sh [--dry-run]
#
# TV_TEAM_ID is the Apple signing team. It is read from the environment, then from .env at the repo root,
# then from Xcode's signed-in accounts, then from a local "Apple Development" certificate.
# Each phone gets its own build, which registers the phone with the team (a free team has no other way).
# With a free Apple ID the app expires after 7 days: plug in the iPhone and run this script again.
# --dry-run prints the commands (with placeholders for the phone) instead of running them.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
APP_PATH="ios/App/build/Build/Products/Debug-iphoneos/TVRemote.app"
DRY_RUN=0
DEVICES_JSON=""

die() {
    echo "install.sh: $*" >&2
    exit 1
}

# Runs a command, or only prints it with --dry-run.
run() {
    printf '+'
    printf ' %q' "$@"
    printf '\n'
    if [[ "$DRY_RUN" -eq 0 ]]; then
        "$@"
    fi
}

# 10 upper-case letters/digits, e.g. ABCDE12345.
valid_team_id() {
    [[ "$1" =~ ^[A-Z0-9]{10}$ ]]
}

# Prints TV_TEAM_ID from .env at the repo root, if it is set there.
team_id_from_env_file() {
    local file="$REPO_ROOT/.env" value
    [[ -f "$file" ]] || return 0
    value="$(sed -n 's/^[[:space:]]*\(export[[:space:]]\{1,\}\)\{0,1\}TV_TEAM_ID[[:space:]]*=[[:space:]]*//p' "$file" | tail -n 1)"
    value="${value%%#*}"
    value="$(printf '%s' "$value" | tr -d "\"'[:space:]")"
    printf '%s' "$value"
}

# Prints the team IDs of the accounts signed in to Xcode (one per line, no duplicates).
# Xcode stores them in its preferences under IDEProvisioningTeams / IDEProvisioningTeamByIdentifier.
team_ids_from_xcode() {
    defaults export com.apple.dt.Xcode - 2>/dev/null | /usr/bin/python3 -I -c '
import plistlib, sys
try:
    prefs = plistlib.loads(sys.stdin.buffer.read())
except Exception:
    sys.exit(0)

found = []
def walk(node):
    if isinstance(node, dict):
        team = node.get("teamID")
        if isinstance(team, str) and team not in found:
            found.append(team)
        for value in node.values():
            walk(value)
    elif isinstance(node, list):
        for value in node:
            walk(value)

for key in ("IDEProvisioningTeams", "IDEProvisioningTeamByIdentifier"):
    walk(prefs.get(key))
print("\n".join(found))
' || true
}

# Prints the team IDs (OU field) of the "Apple Development" certificates in the keychain.
# The number in brackets in the certificate name is NOT always the team ID, so read the certificate itself.
team_ids_from_certificates() {
    local name subject
    while IFS= read -r name; do
        subject="$(security find-certificate -c "$name" -p 2>/dev/null | openssl x509 -noout -subject 2>/dev/null || true)"
        printf '%s\n' "$subject" | grep -oE 'OU ?= ?[A-Z0-9]{10}' | grep -oE '[A-Z0-9]{10}$' || true
    done < <(security find-identity -v -p codesigning 2>/dev/null | sed -n 's/^[[:space:]]*[0-9]*) [0-9A-F]* "\(Apple Development:[^"]*\)".*/\1/p') | sort -u
}

# Sets TV_TEAM_ID or exits with a message.
resolve_team_id() {
    TV_TEAM_ID="${TV_TEAM_ID:-}"
    if [[ -z "$TV_TEAM_ID" ]]; then
        TV_TEAM_ID="$(team_id_from_env_file)"
    fi
    if [[ -z "$TV_TEAM_ID" ]]; then
        local found count
        found="$(team_ids_from_xcode || true)"
        if [[ -z "$found" ]]; then
            found="$(team_ids_from_certificates || true)"
        fi
        count="$(printf '%s' "$found" | grep -c . || true)"
        if [[ "$count" -eq 1 ]]; then
            TV_TEAM_ID="$found"
            echo "Using signing team $TV_TEAM_ID (found on this Mac)."
        elif [[ "$count" -gt 1 ]]; then
            {
                echo "install.sh: more than one signing team found on this Mac:"
                sed 's/^/  /' <<< "$found"
                echo "Pick one: export TV_TEAM_ID=<team id>   (or put TV_TEAM_ID=<team id> in .env)"
            } >&2
            exit 1
        fi
    fi
    if [[ -z "$TV_TEAM_ID" ]]; then
        {
            echo "install.sh: TV_TEAM_ID is not set and no signing team was found."
            echo "1. Xcode > Settings > Accounts > add your Apple ID (this creates a Personal Team)."
            echo "2. Run: export TV_TEAM_ID=<10-character team id>   (or put TV_TEAM_ID=... in .env)"
            echo "   The team id is the Organizational Unit of your 'Apple Development' certificate"
            echo "   (Keychain Access > My Certificates > double-click it), or Team ID under Membership details at developer.apple.com/account."
            echo "   The certificate exists once Xcode has signed a build with your Apple ID."
        } >&2
        exit 1
    fi
    valid_team_id "$TV_TEAM_ID" || die "TV_TEAM_ID '$TV_TEAM_ID' should be 10 upper-case letters or digits (like ABCDE12345)."
    export TV_TEAM_ID
}

# Prints "<UDID><TAB><name>" for every paired, reachable iPhone in a `devicectl list devices` JSON file.
# Exits with 2 and a message on stderr when the file is not a device list (empty, cut short, another format).
list_iphones() {
    /usr/bin/python3 -I -c '
import json, sys
try:
    with open(sys.argv[1]) as handle:
        devices = json.load(handle)["result"]["devices"]
    if not isinstance(devices, list):
        raise TypeError("devices is not a list")
except (OSError, ValueError, KeyError, TypeError) as error:
    print("devicectl did not write a device list (%s: %s)" % (type(error).__name__, error), file=sys.stderr)
    sys.exit(2)
for device in devices:
    if not isinstance(device, dict):
        continue
    hardware = device.get("hardwareProperties") or {}
    connection = device.get("connectionProperties") or {}
    name = str((device.get("deviceProperties") or {}).get("name") or "iPhone").replace("\t", " ")
    if hardware.get("deviceType") != "iPhone":
        continue
    if connection.get("pairingState", "paired") != "paired":
        continue
    if connection.get("tunnelState") == "unavailable":
        continue
    udid = hardware.get("udid")
    if not udid:
        print("Skipping %s: devicectl did not report its UDID." % name, file=sys.stderr)
        continue
    print(udid + "\t" + name)
' "$1"
}

no_iphone_hint() {
    {
        echo "No iPhone is connected."
        echo "Plug it in with a cable, unlock it, tap Trust, and turn on Settings > Privacy & Security > Developer Mode (it restarts the phone)."
        echo "Then run this script again."
    } >&2
}

main() {
    local arg
    for arg in "$@"; do
        case "$arg" in
            --dry-run) DRY_RUN=1 ;;
            -h|--help)
                sed -n '2,10p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
                exit 0
                ;;
            *) die "unknown argument '$arg' (usage: install.sh [--dry-run])" ;;
        esac
    done

    cd "$REPO_ROOT"
    resolve_team_id
    if [[ "$DRY_RUN" -eq 1 ]]; then
        echo "Dry run: printing the commands instead of running them. Team: $TV_TEAM_ID"
        echo "+ cd $REPO_ROOT"
    else
        command -v xcodegen >/dev/null || die "XcodeGen is missing. Install it with: brew install xcodegen"
        xcodebuild -version >/dev/null 2>&1 || die "Xcode is not set up. Install Xcode, open it once, then run: sudo xcode-select -s /Applications/Xcode.app"
    fi

    # The phones come first: a free team can only make a provisioning profile for a device it has registered,
    # and each build below registers its phone.
    echo "1/3 Looking for connected iPhones"
    local devices
    if [[ "$DRY_RUN" -eq 1 ]]; then
        run xcrun devicectl list devices --quiet --json-output DEVICES_JSON
        devices=$'IPHONE_UDID\tyour iPhone'
    else
        DEVICES_JSON="$(mktemp -t tvremote-devices)"
        trap 'rm -f "$DEVICES_JSON"' EXIT
        if ! xcrun devicectl list devices --quiet --json-output "$DEVICES_JSON" </dev/null >/dev/null; then
            die "devicectl could not list devices. Is Xcode installed and opened once? Try: xcrun devicectl list devices"
        fi
        devices="$(list_iphones "$DEVICES_JSON")" || die "could not read the list of connected devices. Try: xcrun devicectl list devices"
        if [[ -z "$devices" ]]; then
            no_iphone_hint
            exit 1
        fi
        cut -f2 <<< "$devices" | sed 's/^/  /'
    fi

    echo "2/3 Generating the Xcode project"
    run xcodegen generate --spec ios/App/project.yml

    echo "3/3 Building and installing, one iPhone at a time"
    local udid name failed=0 installed=0
    # The list is read on fd 3, so xcodebuild and devicectl cannot swallow it from stdin.
    while IFS=$'\t' read -r udid name <&3; do
        echo "Building for $name"
        if ! run xcodebuild -project ios/App/TVRemote.xcodeproj -scheme TVRemote -configuration Debug \
            -destination "id=$udid" -allowProvisioningUpdates -allowProvisioningDeviceRegistration \
            "DEVELOPMENT_TEAM=$TV_TEAM_ID" -derivedDataPath ios/App/build build </dev/null; then
            echo "install.sh: the build for $name failed (see above)." >&2
            failed=$((failed + 1))
            continue
        fi
        if [[ "$DRY_RUN" -eq 0 && ! -d "$APP_PATH" ]]; then
            echo "install.sh: the build did not produce $APP_PATH" >&2
            failed=$((failed + 1))
            continue
        fi
        if run xcrun devicectl device install app --device "$udid" "$APP_PATH" </dev/null; then
            [[ "$DRY_RUN" -eq 1 ]] || echo "App installed on $name"
            installed=$((installed + 1))
        else
            echo "install.sh: could not install on $name (is it unlocked, trusted and in Developer Mode?)" >&2
            failed=$((failed + 1))
        fi
    done 3<<< "$devices"

    if [[ "$DRY_RUN" -eq 0 && "$installed" -gt 0 ]]; then
        echo "First time on a phone: Settings > General > VPN & Device Management > trust the developer app, then open TV Remote."
    fi
    [[ "$failed" -eq 0 ]] || exit 1
}

# Run only when executed, so the functions above can be sourced for testing.
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi
