#!/usr/bin/env bash
# Keeps TV Remote installed on every iPhone at home. A free Apple ID signs the app for 7 days.
#
# usage: ios/scripts/renew.sh [--force] [--dry-run]
#
# Run every evening by launchd (~/Library/LaunchAgents/com.dzafirov.tvskin.renew-remote.plist).
# It does nothing until a phone's last renewal is RENEW_AFTER_DAYS old (or a phone was never renewed),
# then runs install.sh, which installs over Wi-Fi on every iPhone that is home. A phone that was missed (away,
# locked, asleep) keeps its old stamp, so the next evening tries again.
# A phone still not renewed after WARN_AFTER_DAYS gets a notification on the Mac.
# --force renews now; --dry-run is passed to install.sh (prints the commands only).
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STAMP_DIR="${TVSKIN_STAMP_DIR:-$HOME/.tvskin/remote-renewed}"
RENEW_AFTER_DAYS=5
WARN_AFTER_DAYS=6

# Days since the stamp file was last touched (whole days, rounded down).
age_days() {
    local now modified
    now="$(date +%s)"
    modified="$(stat -f %m "$1")"
    echo $(((now - modified) / 86400))
}

# True when no phone was ever renewed, or any phone's last renewal is RENEW_AFTER_DAYS or older.
needs_renewal() {
    local stamp found=0
    for stamp in "$STAMP_DIR"/*; do
        [[ -f "$stamp" ]] || continue
        found=1
        [[ "$(age_days "$stamp")" -ge "$RENEW_AFTER_DAYS" ]] && return 0
    done
    [[ "$found" -eq 0 ]]
}

# Phones not renewed for WARN_AFTER_DAYS or more, one per line.
overdue_phones() {
    local stamp
    for stamp in "$STAMP_DIR"/*; do
        [[ -f "$stamp" ]] || continue
        [[ "$(age_days "$stamp")" -ge "$WARN_AFTER_DAYS" ]] && basename "$stamp"
    done
}

# The phone names in install.sh output ("App installed on <name>"), one per line.
installed_names() {
    sed -n 's/^App installed on //p' <<< "$1"
}

# A phone name as a file name: slashes and colons become underscores.
stamp_name() {
    printf '%s' "$1" | tr '/:' '__'
}

notify() {
    /usr/bin/osascript -e "display notification \"$1\" with title \"TV Remote\"" >/dev/null 2>&1 || true
}

main() {
    local force=0 pass=() arg output status name names
    for arg in "$@"; do
        case "$arg" in
            --force) force=1 ;;
            --dry-run) pass+=(--dry-run) ;;
            *) echo "renew.sh: unknown argument '$arg'" >&2; exit 2 ;;
        esac
    done
    mkdir -p "$STAMP_DIR"
    echo "$(date '+%Y-%m-%d %H:%M') renew.sh"
    if [[ "$force" -eq 0 ]] && ! needs_renewal; then
        echo "  nothing due"
        exit 0
    fi

    output="$("$SCRIPT_DIR/install.sh" ${pass[@]+"${pass[@]}"} 2>&1)"
    status=$?
    echo "$output" | grep -E 'App installed on|install.sh:|No iPhone|error:' | sed 's/^/  /'
    names="$(installed_names "$output")"
    if [[ ${#pass[@]} -eq 0 && -n "$names" ]]; then
        while IFS= read -r name; do
            touch "$STAMP_DIR/$(stamp_name "$name")"
        done <<< "$names"
        notify "Renewed for 7 days on $(paste -sd, - <<< "$names" | sed 's/,/, /g')"
    fi

    local overdue
    overdue="$(overdue_phones)"
    if [[ -n "$overdue" ]]; then
        notify "Not renewed yet on $(paste -sd, - <<< "$overdue" | sed 's/,/, /g'). Keep it unlocked on home Wi-Fi this evening."
    fi
    exit "$status"
}

# Run only when executed, so the functions above can be sourced by renew_test.sh.
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi
