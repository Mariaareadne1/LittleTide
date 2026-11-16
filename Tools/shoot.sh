#!/bin/zsh
# Launch Little Tide in a demo scenario and capture a screenshot.
#   Tools/shoot.sh <sim-udid> <scenario> <out.png> [extra launch args...]
set -e
SIM=$1; SCENARIO=$2; OUT=$3; shift 3
APP=build/DD/Build/Products/Debug-iphonesimulator/LittleTide.app
xcrun simctl install "$SIM" "$APP"
xcrun simctl terminate "$SIM" app.littletide.LittleTide >/dev/null 2>&1 || true
xcrun simctl launch "$SIM" app.littletide.LittleTide -LTDemo "$SCENARIO" "$@" >/dev/null
sleep ${LT_WAIT:-3}
mkdir -p "$(dirname "$OUT")"
xcrun simctl io "$SIM" screenshot "$OUT" >/dev/null 2>&1
echo "$OUT"
