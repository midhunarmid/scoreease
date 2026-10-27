#!/usr/bin/env bash
# Regenerates every ScoreEase icon (Android, web, Play listing) from the SVG sources here.
# Needs ImageMagick 7 (`magick`). Run from anywhere: bash tools/icon/build.sh
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/../.." && pwd)"
cd "$here"

mark() { # the scoreboard mark, drawn for a 1024 canvas; $1 = scale around the centre
  cat <<SVG
  <g transform="translate(512 512) scale($1) translate(-512 -520)">
    <rect x="252" y="386" width="230" height="300" rx="44" fill="#064E3B" opacity="0.28"/>
    <rect x="542" y="386" width="230" height="300" rx="44" fill="#064E3B" opacity="0.28"/>
    <rect x="252" y="370" width="230" height="300" rx="44" fill="#FFFFFF"/>
    <rect x="542" y="370" width="230" height="300" rx="44" fill="#FFFFFF"/>
    <path d="M252 520 H482 V626 A44 44 0 0 1 438 670 H296 A44 44 0 0 1 252 626 Z" fill="#E3F7EE"/>
    <path d="M542 520 H772 V626 A44 44 0 0 1 728 670 H586 A44 44 0 0 1 542 626 Z" fill="#E3F7EE"/>
    <path d="M386 440 V600 M386 440 L340 474" stroke="#064E3B" stroke-width="44" stroke-linecap="round" stroke-linejoin="round" fill="none"/>
    <rect x="607" y="440" width="100" height="160" rx="50" stroke="#064E3B" stroke-width="44" fill="none"/>
    <rect x="252" y="515" width="230" height="10" fill="#0E9F6E"/>
    <rect x="542" y="515" width="230" height="10" fill="#0E9F6E"/>
    <circle cx="512" cy="484" r="14" fill="#FFFFFF"/>
    <circle cx="512" cy="556" r="14" fill="#FFFFFF"/>
  </g>
SVG
}
grad='<defs><linearGradient id="g" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#34D399"/><stop offset="1" stop-color="#059669"/></linearGradient></defs>'
svg() { echo '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024">'; echo "$grad"; cat; echo '</svg>'; }

# Full-bleed square (Play listing, maskable web icons, apple-touch): mark large.
{ echo '<rect width="1024" height="1024" fill="url(#g)"/>'; mark 1.3; } | svg > icon-full.svg
# Rounded square (favicon, legacy Android launcher).
{ echo '<rect width="1024" height="1024" rx="224" fill="url(#g)"/>'; mark 1.3; } | svg > icon-rounded.svg
# Adaptive-icon foreground: canvas = 108dp, mark kept inside the 66dp safe zone.
mark 1.0 | svg > icon-foreground.svg

render() { magick -background none -density 384 "$1" -resize "$2x$2" "$3"; }

res="$root/android/app/src/main/res"
for d in mdpi:48 hdpi:72 xhdpi:96 xxhdpi:144 xxxhdpi:192; do
  render icon-rounded.svg "${d#*:}" "$res/mipmap-${d%%:*}/ic_launcher.png"
done
for d in mdpi:108 hdpi:162 xhdpi:216 xxhdpi:324 xxxhdpi:432; do
  render icon-foreground.svg "${d#*:}" "$res/mipmap-${d%%:*}/ic_launcher_foreground.png"
done

fav="$root/web/favicon"
cp icon-rounded.svg "$fav/favicon.svg"
render icon-rounded.svg 96 "$fav/favicon-96x96.png"
render icon-full.svg 180 "$fav/apple-touch-icon.png"
render icon-full.svg 192 "$fav/web-app-manifest-192x192.png"
render icon-full.svg 512 "$fav/web-app-manifest-512x512.png"
render icon-rounded.svg 256 ico.png && magick ico.png -define icon:auto-resize=48,32,16 "$fav/favicon.ico" && rm ico.png

mkdir -p "$root/store"
render icon-full.svg 512 "$root/store/play-icon-512.png"
echo "icons written"
