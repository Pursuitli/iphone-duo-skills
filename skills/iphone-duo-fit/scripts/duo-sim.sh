#!/usr/bin/env bash
# Create and boot your OWN iPhone Duo simulator, install a build, launch it.
#
#   scripts/duo-sim.sh create [name]                 -> prints the new device's UDID
#   scripts/duo-sim.sh launch <udid> <App.app> <bundle-id> [ENV=1 ...]
#   scripts/duo-sim.sh shot <udid> <out.png>
#
# Needs Xcode 27.1 beta or later (the Duo simulator first shipped there):
#   export DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer
#
# Why your own device: a shared machine usually has a simulator open in
# Xcode, and installing/launching on it takes over the screen someone is
# working on. Poses (Closed / Book / Open / Rotate) are set only in the
# Simulator app's Device Hub; simctl has none, and a fresh device boots
# closed (screenshots come out 1398 x 2034).
set -euo pipefail

TYPE="com.apple.CoreSimulator.SimDeviceType.iPhone-Duo"

runtime() {
  xcrun simctl list runtimes | grep -o 'com.apple.CoreSimulator.SimRuntime.iOS-27-[0-9]*' | sort -V | tail -1
}

case "${1:-}" in
  create)
    NAME="${2:-iPhone Duo (mine)}"
    RT="$(runtime)"
    [ -n "$RT" ] || { echo "no iOS 27.x runtime; run: xcodebuild -downloadPlatform iOS" >&2; exit 1; }
    xcrun simctl list devicetypes | grep -q "$TYPE" || { echo "no iPhone Duo device type; set DEVELOPER_DIR to Xcode 27.1+" >&2; exit 1; }
    UDID="$(xcrun simctl create "$NAME" "$TYPE" "$RT")"
    xcrun simctl boot "$UDID"
    xcrun simctl bootstatus "$UDID" -b >/dev/null 2>&1 || true   # "Data Migration Failed" here is harmless
    echo "$UDID"
    ;;
  launch)
    UDID="$2"; APP="$3"; BUNDLE="$4"; shift 4
    xcrun simctl install "$UDID" "$APP"
    # Debug switches go as SIMCTL_CHILD_<NAME> in the ENVIRONMENT of launch;
    # anything after the bundle id is an app argument and is silently ignored.
    ENVS=()
    for kv in "$@"; do ENVS+=("SIMCTL_CHILD_$kv"); done
    env "${ENVS[@]}" xcrun simctl launch "$UDID" "$BUNDLE"
    ;;
  shot)
    xcrun simctl io "$2" screenshot "$3"
    python3 - "$3" <<'PY' 2>/dev/null || true
import sys
from PIL import Image
w, h = Image.open(sys.argv[1]).size
pose = "closed (outer display)" if (w, h) == (1398, 2034) else "open upright" if (w, h) == (1878, 2670) else "open on its side" if (w, h) == (2670, 1878) else "not a Duo pose"
print(f"{w} x {h}: {pose}")
PY
    ;;
  *)
    sed -n '2,12p' "$0"; exit 1 ;;
esac
