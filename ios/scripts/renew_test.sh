#!/usr/bin/env bash
# Tests for renew.sh's decisions (no phones, no Xcode needed). Run: ios/scripts/renew_test.sh
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export TVSKIN_STAMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TVSKIN_STAMP_DIR"' EXIT
# shellcheck source=renew.sh
source "$HERE/renew.sh"
fails=0
check() { if [[ "$2" == "$3" ]]; then echo "ok   - $1"; else echo "FAIL - $1 (expected '$3', got '$2')"; fails=$((fails + 1)); fi; }
old() { touch -t "$(date -v-"$2"d +%Y%m%d%H%M)" "$TVSKIN_STAMP_DIR/$1"; }

needs_renewal && r=yes || r=no;              check "no phone renewed yet: renew" "$r" yes
old "Dimitar's iPhone" 1
needs_renewal && r=yes || r=no;              check "renewed yesterday: wait" "$r" no
old "Dimitar's iPhone" 5
needs_renewal && r=yes || r=no;              check "renewed 5 days ago: renew" "$r" yes
old "Dimitar's iPhone" 2; old "Her iPhone" 6
needs_renewal && r=yes || r=no;              check "one phone due: renew" "$r" yes
check "phones close to expiry" "$(overdue_phones)" "Her iPhone"
check "names from install.sh output" "$(installed_names $'App installed on Dimitar’s iPhone\nnoise\nApp installed on Her iPhone')" $'Dimitar’s iPhone\nHer iPhone'
check "a name is a safe file name" "$(stamp_name 'Her/iPhone: 2')" "Her_iPhone_ 2"
[[ $fails -eq 0 ]] && echo "all passed" || { echo "$fails failed"; exit 1; }
