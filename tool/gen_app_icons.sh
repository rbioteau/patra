#!/usr/bin/env bash
# Regenerate every app-icon bitmap from the two masters in assets/icon/.
#
# The design handoff draws the palm frond in two variants and the choice
# between them is a size rule, not a taste: below 72px the five blades and
# their gaps fall under two pixels each and the fan closes into a blob, so
# every icon at or under 72px is rendered from the three-blade *compact*
# master instead. That rule is why `flutter_launcher_icons` no longer runs
# here — it rasterises one master to every size and would quietly close the
# fan on the settings and notification icons.
#
# The Android *adaptive* icon is not produced here at all: its foreground is
# the vector res/drawable/patra_mark.xml (see CLAUDE.md).
#
#   ./tool/gen_app_icons.sh
#
# Requires ImageMagick (`convert`).
set -euo pipefail

cd "$(dirname "$0")/.."

FULL=assets/icon/patra-1024.png            # five blades
COMPACT=assets/icon/patra-compact-1024.png # three blades, for <= 72px
IOS=ios/Runner/Assets.xcassets/AppIcon.appiconset
ANDROID=android/app/src/main/res

# Below this the fan has to be the compact one.
COMPACT_MAX=72

command -v convert >/dev/null || { echo "ImageMagick (convert) is required" >&2; exit 1; }

master_for() { [ "$1" -le "$COMPACT_MAX" ] && echo "$COMPACT" || echo "$FULL"; }

# iOS icons are square and opaque: the OS applies its own mask, and App Store
# Connect rejects an icon carrying an alpha channel.
ios_icon() { # <px> <path>
  convert "$(master_for "$1")" -resize "${1}x${1}" -alpha remove -alpha off \
    -strip PNG24:"$2"
}

# Legacy Android launcher icons are drawn as-is by pre-API-26 launchers, so
# they carry the platform's own 22.7% corner themselves.
android_icon() { # <px> <path>
  local px=$1 out=$2 r=$(( ($1 * 227 + 500) / 1000 ))
  convert "$(master_for "$px")" -resize "${px}x${px}" \
    \( -size "${px}x${px}" xc:black -fill white \
       -draw "roundrectangle 0,0,$((px-1)),$((px-1)),$r,$r" -alpha off \) \
    -compose CopyOpacity -composite -strip "$out"
}

# Every size Contents.json names, @1x/@2x/@3x flattened to pixels.
while read -r px name; do
  ios_icon "$px" "$IOS/$name"
done <<'SIZES'
40    Icon-App-20x20@2x.png
60    Icon-App-20x20@3x.png
20    Icon-App-20x20@1x.png
29    Icon-App-29x29@1x.png
58    Icon-App-29x29@2x.png
87    Icon-App-29x29@3x.png
40    Icon-App-40x40@1x.png
80    Icon-App-40x40@2x.png
120   Icon-App-40x40@3x.png
50    Icon-App-50x50@1x.png
100   Icon-App-50x50@2x.png
57    Icon-App-57x57@1x.png
114   Icon-App-57x57@2x.png
120   Icon-App-60x60@2x.png
180   Icon-App-60x60@3x.png
72    Icon-App-72x72@1x.png
144   Icon-App-72x72@2x.png
76    Icon-App-76x76@1x.png
152   Icon-App-76x76@2x.png
167   Icon-App-83.5x83.5@2x.png
1024  Icon-App-1024x1024@1x.png
SIZES

while read -r px bucket; do
  android_icon "$px" "$ANDROID/mipmap-$bucket/ic_launcher.png"
done <<'SIZES'
48   mdpi
72   hdpi
96   xhdpi
144  xxhdpi
192  xxxhdpi
SIZES

echo "Icons regenerated from $FULL and $COMPACT."
