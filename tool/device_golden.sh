#!/usr/bin/env bash
# Open one known book on a phone, photograph its page, and put the picture
# beside the reference for a person to compare by eye.
#
#   ./tool/device_golden.sh
#
# Run before cutting a release tag (see .github/CLAUDE.md). CI does not run
# it and cannot: it has no phone, and a golden with no device would only ever
# go green. What it is, and why the web engine needs it, is in
# integration_test/golden/README.md.
#
# What it does:
#
#   * uninstalls the app, so the run starts from the sign-in form — the same
#     step, and the same cost, as tool/store_screenshots.sh: a Patra on that
#     phone is gone, profiles and saved chapters with it, and what comes back
#     is a debug build;
#   * starts tool/golden_server.dart, which replays what a real Kavita made
#     of integration_test/golden/golden-book.epub, and reaches the phone to it
#     with `adb reverse`;
#   * puts the status bar in demo mode where the phone honours it, so its
#     clock is not a difference between two runs;
#   * runs integration_test/book_golden_test.dart, which photographs the page
#     read from the server and the same page read from a saved copy offline;
#   * writes, for each, <name>-compare.png into build/golden/: the reference,
#     this run and their difference side by side, with the count of pixels
#     that differ.
#
# It fails when the run fails. It does not fail on a difference: a reference
# is one phone's pixels, and whether a difference is a regression is the
# judgement this exists to hand a person.
set -euo pipefail

cd "$(dirname "$0")/.."

DEVICE=""
PACKAGE=io.github.rbioteau.patra
CLEAR=1
ACCEPT=0
RECORD=""
PORT=5000
GOLDEN=integration_test/golden
REFERENCE="$GOLDEN/reference"
SHOTS=build/golden
NAMES=(book-streamed book-offline)

usage() {
  sed -n '2,31p' "$0" | sed 's/^# \{0,1\}//'
  cat <<'EOF'

Options:
  --device <id>        the phone to run on (default: the only one attached)
  --keep               do not uninstall the app first (it must then be
                       signed out, with no profile remembered)
  --accept             make this run's pictures the reference
  --record <url>       record a real Kavita instead of replaying one; its
                       account is golden, its password $GOLDEN_PASSWORD
                       (see integration_test/golden/README.md)
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --device) DEVICE="${2:?--device takes an id}"; shift 2 ;;
    --keep) CLEAR=0; shift ;;
    --accept) ACCEPT=1; shift ;;
    --record) RECORD="${2:?--record takes the Kavita to record}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

for tool in convert compare identify flutter dart curl; do
  command -v "$tool" >/dev/null || { echo "$tool is required" >&2; exit 1; }
done

# adb is rarely on PATH; the same search as tool/store_screenshots.sh.
ADB="$(command -v adb || true)"
for candidate in "${ANDROID_HOME:-}/platform-tools/adb" \
                 "${ANDROID_SDK_ROOT:-}/platform-tools/adb" \
                 "$HOME/Android/Sdk/platform-tools/adb"; do
  if [ -z "$ADB" ] && [ -x "$candidate" ]; then ADB="$candidate"; fi
done
[ -n "$ADB" ] || { echo "adb is required — it is in the Android SDK's platform-tools." >&2; exit 1; }

if [ -z "$DEVICE" ]; then
  DEVICE="$("$ADB" devices | awk '$2 == "device" { print $1 }')"
  case "$(printf '%s\n' "$DEVICE" | grep -c .)" in
    1) ;;
    0) echo "No device attached. Plug one in, then run this again." >&2; exit 1 ;;
    *) echo "More than one device attached — pass --device." >&2; exit 1 ;;
  esac
fi

if [ -n "$RECORD" ] && [ -z "${GOLDEN_PASSWORD:-}" ]; then
  echo "--record signs in to a real Kavita: set GOLDEN_PASSWORD." >&2
  exit 1
fi

SERVER_PID=""
cleanup() {
  [ -n "$SERVER_PID" ] && kill "$SERVER_PID" 2>/dev/null || true
  "$ADB" -s "$DEVICE" reverse --remove "tcp:$PORT" >/dev/null 2>&1 || true
  "$ADB" -s "$DEVICE" reverse --remove "tcp:$((PORT + 1))" >/dev/null 2>&1 || true
  "$ADB" -s "$DEVICE" shell am broadcast -a com.android.systemui.demo -e command exit >/dev/null 2>&1 || true
}
trap cleanup EXIT

if [ "$CLEAR" = 1 ]; then
  "$ADB" -s "$DEVICE" uninstall "$PACKAGE" >/dev/null 2>&1 || true
fi

# A fixed clock, a full battery and no notifications, where the phone honours
# SystemUI's demo mode — some vendors' builds do not, and then the status bar
# is simply one more thing that differs between two runs.
"$ADB" -s "$DEVICE" shell settings put global sysui_demo_allowed 1 >/dev/null 2>&1 || true
for command in "enter" "clock -e hhmm 1200" "battery -e level 100 -e plugged false" \
               "notifications -e visible false" "network -e wifi show -e level 4"; do
  # shellcheck disable=SC2086
  "$ADB" -s "$DEVICE" shell am broadcast -a com.android.systemui.demo -e command $command >/dev/null 2>&1 || true
done

rm -rf "$SHOTS"
mkdir -p "$SHOTS"
SERVER_ARGS=(--device "$DEVICE" --adb "$ADB" --port "$PORT" --shots "$SHOTS")
[ -n "$RECORD" ] && SERVER_ARGS+=(--record "$RECORD")
dart run tool/golden_server.dart "${SERVER_ARGS[@]}" > "$SHOTS/server.log" 2>&1 &
SERVER_PID=$!

READY=0
for _ in $(seq 1 150); do
  if curl -s -o /dev/null "http://127.0.0.1:$((PORT + 1))/"; then READY=1; break; fi
  kill -0 "$SERVER_PID" 2>/dev/null || { cat "$SHOTS/server.log" >&2; exit 1; }
  sleep 0.2
done
[ "$READY" = 1 ] || {
  echo "The golden server did not answer within 30s:" >&2
  cat "$SHOTS/server.log" >&2
  exit 1
}
"$ADB" -s "$DEVICE" reverse "tcp:$PORT" "tcp:$PORT" >/dev/null
"$ADB" -s "$DEVICE" reverse "tcp:$((PORT + 1))" "tcp:$((PORT + 1))" >/dev/null

# The password reaches the phone as a `--dart-define`, visible in `ps` for
# the length of the run — the trade tool/store_screenshots.sh makes, and only
# ever the password of a throwaway Kavita recorded from.
DEFINES=()
[ -n "$RECORD" ] && DEFINES+=(--dart-define=GOLDEN_PASSWORD="$GOLDEN_PASSWORD")

echo "Opening the golden book on $DEVICE ($("$ADB" -s "$DEVICE" shell getprop ro.product.model | tr -d '\r'))"
if ! flutter test integration_test/book_golden_test.dart -d "$DEVICE" ${DEFINES[@]+"${DEFINES[@]}"}; then
  echo >&2
  echo "The run failed. What the server was asked is in $SHOTS/server.log." >&2
  grep 'NOT RECORDED' "$SHOTS/server.log" >&2 || true
  exit 1
fi

for name in "${NAMES[@]}"; do
  [ -f "$SHOTS/$name.png" ] || { echo "The run took no $name.png." >&2; exit 1; }
done

# What the phone was, written beside a reference so the next person knows
# whether their phone can be compared with it at all: a reference is one
# screen's pixels.
describe_device() {
  printf 'model: %s\n' "$("$ADB" -s "$DEVICE" shell getprop ro.product.model | tr -d '\r')"
  printf 'android: %s (API %s)\n' \
    "$("$ADB" -s "$DEVICE" shell getprop ro.build.version.release | tr -d '\r')" \
    "$("$ADB" -s "$DEVICE" shell getprop ro.build.version.sdk | tr -d '\r')"
  printf 'screen: %s\n' "$("$ADB" -s "$DEVICE" shell wm size | tr -d '\r' | awk 'END { print $NF }')"
  printf 'density: %s\n' "$("$ADB" -s "$DEVICE" shell wm density | tr -d '\r' | awk 'END { print $NF }')"
  printf 'webview: %s\n' "$("$ADB" -s "$DEVICE" shell dumpsys webviewupdate | tr -d '\r' | sed -n 's/.*Current WebView package (name, version): (\(.*\))/\1/p')"
}

if [ "$ACCEPT" = 1 ]; then
  mkdir -p "$REFERENCE"
  for name in "${NAMES[@]}"; do
    convert "$SHOTS/$name.png" -strip PNG24:"$REFERENCE/$name.png"
  done
  describe_device > "$REFERENCE/device.txt"
  echo "Accepted as the reference, in $REFERENCE:"
  cat "$REFERENCE/device.txt" | sed 's/^/  /'
  exit 0
fi

# ---- side by side ----------------------------------------------------------
#
# A count of differing pixels is printed, and it is advice, not a verdict:
# a font hinted a pixel differently by a WebView update is a difference and
# not a regression. `-fuzz` forgives the anti-aliasing that moves between two
# runs of the same engine.
echo
describe_device > "$SHOTS/device.txt"
if [ -f "$REFERENCE/device.txt" ] && ! diff -q "$REFERENCE/device.txt" "$SHOTS/device.txt" >/dev/null; then
  echo "This phone is not the one the reference was made on:"
  diff "$REFERENCE/device.txt" "$SHOTS/device.txt" | sed 's/^/  /' || true
  echo
fi

compare_pair() { # <left> <right> <out> — prints the differing pixel count
  local left="$1" right="$2" out="$3"
  if [ "$(identify -format '%wx%h' "$left")" != "$(identify -format '%wx%h' "$right")" ]; then
    convert "$left" "$right" +append "$out"
    echo "different sizes"
    return
  fi
  local diff="$out.diff.png" count
  count="$(compare -fuzz 2% -metric AE "$left" "$right" "$diff" 2>&1 >/dev/null || true)"
  convert "$left" "$right" "$diff" +append "$out"
  rm -f "$diff"
  echo "$count pixels differ"
}

for name in "${NAMES[@]}"; do
  if [ ! -f "$REFERENCE/$name.png" ]; then
    echo "  $name: no reference yet — look at $SHOTS/$name.png, then run with --accept"
    continue
  fi
  said="$(compare_pair "$REFERENCE/$name.png" "$SHOTS/$name.png" "$SHOTS/$name-compare.png")"
  echo "  $name: $said — reference | this run | difference in $SHOTS/$name-compare.png"
done

# The saved copy is handed the very document the streamed page is, so the
# two pictures of one run should be one picture.
said="$(compare_pair "$SHOTS/book-streamed.png" "$SHOTS/book-offline.png" "$SHOTS/streamed-vs-offline.png")"
echo "  streamed against offline: $said — $SHOTS/streamed-vs-offline.png"
echo
echo "Look at them. A difference you meant is accepted with --accept."
