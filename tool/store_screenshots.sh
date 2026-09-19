#!/usr/bin/env bash
# Photograph the store listings' screenshots, on a device, in the sizes the
# stores take.
#
#   ./tool/store_screenshots.sh --locale fr
#
# The recipe is `integration_test/store_screenshots_test.dart` and the half
# that writes files is `test_driver/store_screenshots.dart`; this is the part
# that cannot be Dart — clearing the app's data, sizing the screen, and
# flattening what comes out.
#
# Why each step is here:
#
#   * `pm clear` — the run has to start from the sign-in form. Without it the
#     recipe photographs whatever profile, progress and downloads the device
#     was left holding, and "Continue — Ch. 12" is a different chapter every
#     time.
#   * The ratio check — Play wants 9:16 (1080x1920 is the size it names) to be
#     eligible for the formats that show screenshots large, and a modern
#     phone's own screen is taller than that. The script refuses rather than
#     cropping: a crop cuts the app's own chrome off, which is the thing a
#     store screenshot is for.
#   * `-alpha remove` — both stores refuse an alpha channel, and a screenshot
#     of a phone has one.
#
# Credentials come from the environment, never from a file and never committed:
# KAVITA_URL, KAVITA_USER, KAVITA_PASSWORD. They are handed to the device as
# `--dart-define`, which means they are visible in `ps` for the length of the
# run — the same trade `tool/measure_page_shapes.dart` makes with its API key,
# and the reason the password is read from the environment rather than typed on
# the command line, where it would also land in the shell's history.
set -euo pipefail

cd "$(dirname "$0")/.."

LOCALE=en
DEVICE=""
PACKAGE=io.github.rbioteau.patra
CLEAR=1
URL="${KAVITA_URL:-}"
USER_NAME="${KAVITA_USER:-}"
PASSWORD="${KAVITA_PASSWORD:-}"

usage() {
  sed -n '2,32p' "$0" | sed 's/^# \{0,1\}//'
  cat <<'EOF'

Options:
  --locale <en|fr>    which listing this run is for (default: en)
  --device <id>       the device to run on (default: the only one attached)
  --url <url>         the Kavita server   (default: $KAVITA_URL)
  --user <name>       the account         (default: $KAVITA_USER)
  --password <pass>   its password        (default: $KAVITA_PASSWORD)
  --package <id>      cleared before the run (default: the app's own id)
  --keep              do not clear the app's data
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --locale) LOCALE="$2"; shift 2 ;;
    --device) DEVICE="$2"; shift 2 ;;
    --url) URL="$2"; shift 2 ;;
    --user) USER_NAME="$2"; shift 2 ;;
    --password) PASSWORD="$2"; shift 2 ;;
    --package) PACKAGE="$2"; shift 2 ;;
    --keep) CLEAR=0; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

for tool in convert flutter; do
  command -v "$tool" >/dev/null || { echo "$tool is required" >&2; exit 1; }
done

# `adb` is rarely on PATH — the Android SDK keeps it in its own directory, and
# this machine's is at ~/Android/Sdk (see the root CLAUDE.md). PATH first, then
# the two places the SDK says where it is, then the one it is on here.
ADB="$(command -v adb || true)"
for candidate in "${ANDROID_HOME:-}/platform-tools/adb" \
                 "${ANDROID_SDK_ROOT:-}/platform-tools/adb" \
                 "$HOME/Android/Sdk/platform-tools/adb"; do
  if [ -z "$ADB" ] && [ -x "$candidate" ]; then ADB="$candidate"; fi
done
[ -n "$ADB" ] || {
  echo "adb is required — it is in the Android SDK's platform-tools." >&2
  exit 1
}

[ -n "$URL" ] && [ -n "$USER_NAME" ] && [ -n "$PASSWORD" ] || {
  echo "KAVITA_URL, KAVITA_USER and KAVITA_PASSWORD must be set (or passed)." >&2
  exit 1
}

case "$LOCALE" in
  en|fr) ;;
  *) echo "--locale takes en or fr, not '$LOCALE'." >&2; exit 2 ;;
esac

if [ -z "$DEVICE" ]; then
  DEVICE="$("$ADB" devices | awk '$2 == "device" { print $1 }')"
  case "$(printf '%s\n' "$DEVICE" | grep -c .)" in
    1) ;;
    0) echo "No device attached. Boot one first, then run this again." >&2; exit 1 ;;
    *) echo "More than one device attached — pass --device." >&2; exit 1 ;;
  esac
fi

# The screen has to be the ratio the stores ask for, and it has to be that
# before the app is launched: a screenshot is the whole screen.
#
# `wm size` prints the physical size and, once one has been set, an override
# line under it — the override is the one in force, so it is the last line that
# is read.
SIZE="$("$ADB" -s "$DEVICE" shell wm size | tr -d '\r' | awk 'END { print $NF }')"
case "$SIZE" in
  [0-9]*x[0-9]*) ;;
  *) echo "$DEVICE did not report a screen size (got '$SIZE')." >&2; exit 1 ;;
esac
WIDTH="${SIZE%x*}"
HEIGHT="${SIZE#*x}"
if [ "$WIDTH" -ge "$HEIGHT" ] || [ $((WIDTH * 16)) -ne $((HEIGHT * 9)) ]; then
  cat >&2 <<EOF
$DEVICE reports $SIZE, which is not 9:16.

Play's recommended sizes are 1080x1920 (portrait, 9:16) and Apple wants
1320x2868 for a 6.9" iPhone — neither is a screen a phone ships with. On an
emulator, set it:

  adb -s $DEVICE shell wm size 1080x1920
  adb -s $DEVICE shell wm density 420

and undo it afterwards with \`wm size reset\`.
EOF
  exit 1
fi

if [ "$CLEAR" = 1 ]; then
  # Uninstalled, not `pm clear`ed. `pm clear` needs
  # android.permission.CLEAR_APP_USER_DATA, which `adb shell` does not have on
  # a device that is not rooted and whose app is not debuggable — it fails
  # with a SecurityException, and a step that quietly does nothing is how the
  # recipe ends up photographing the profiles somebody left behind. An
  # uninstall needs no permission and leaves no doubt; the drive that follows
  # installs the build again, so it costs a few seconds.
  #
  # The cost, said out loud: a store-installed Patra on this device is gone
  # and comes back as a debug build.
  "$ADB" -s "$DEVICE" uninstall "$PACKAGE" >/dev/null 2>&1 || true
fi

SHOT_DIR="store/screenshots/$LOCALE"
rm -rf "$SHOT_DIR"

echo "Photographing $LOCALE on $DEVICE ($SIZE) into $SHOT_DIR"

# The drive runs the recipe on the device and the driver here; PATRA_SHOT_DIR
# is how the driver learns where to write, `--dart-define` is how the recipe
# learns everything else.
PATRA_SHOT_DIR="$SHOT_DIR" flutter drive \
  --driver=test_driver/store_screenshots.dart \
  --target=integration_test/store_screenshots_test.dart \
  --device-id "$DEVICE" \
  --dart-define=KAVITA_URL="$URL" \
  --dart-define=KAVITA_USER="$USER_NAME" \
  --dart-define=KAVITA_PASSWORD="$PASSWORD" \
  --dart-define=PATRA_LOCALE="$LOCALE"

# Flattened in place, and only after the run succeeded: a half-processed
# directory is worse than none, because it looks like an answer.
shopt -s nullglob
shots=("$SHOT_DIR"/*.png)
if [ ${#shots[@]} -eq 0 ]; then
  echo "The run finished but wrote no screenshots — nothing to flatten." >&2
  exit 1
fi
for file in "${shots[@]}"; do
  convert "$file" -alpha remove -alpha off -strip PNG24:"$file.flattened"
  mv "$file.flattened" "$file"
done

echo
echo "Done. Upload these in order:"
identify -format '  %f  %wx%h  %b\n' "$SHOT_DIR"/*.png