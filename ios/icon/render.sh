#!/bin/bash
# Renders icon.html into the three app icon PNGs (needs Google Chrome).
# The light icon must have no alpha channel, which the App Store requires, so it is flattened afterwards.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
out="$here/../App/TVRemote/Assets.xcassets/AppIcon.appiconset"
chrome="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
mkdir -p "$out"

shoot() { # <url> <png> <background colour>
  "$chrome" --headless=new --hide-scrollbars --force-device-scale-factor=1 --window-size=1024,1024 \
    --default-background-color="$3" --screenshot="$2" "$1" >/dev/null 2>&1
}

shoot "file://$here/icon.html" "$out/icon-1024.png" FF000000
# Chrome writes RGBA even for an opaque page; a JPEG round trip drops the alpha channel.
sips -s format jpeg -s formatOptions 100 "$out/icon-1024.png" --out "$out/icon-1024.jpg" >/dev/null
sips -s format png "$out/icon-1024.jpg" --out "$out/icon-1024.png" >/dev/null
rm "$out/icon-1024.jpg"

# The dark icon is the same picture.
cp "$out/icon-1024.png" "$out/icon-1024-dark.png"

shoot "file://$here/icon.html?tinted" "$out/icon-1024-tinted.png" 00000000

for f in icon-1024 icon-1024-dark icon-1024-tinted; do
  echo "$f: $(sips -g pixelWidth -g pixelHeight -g hasAlpha "$out/$f.png" | tail -3 | tr -s ' \n' ' ')"
done
