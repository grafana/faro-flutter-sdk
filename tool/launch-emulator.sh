#!/usr/bin/env bash
# Boot an Android/iOS emulator by id and wait for it to register with Flutter.
#
# Usage:
#   ./tool/launch-emulator.sh <emulator-id>
#
# Run ./tool/list-devices.sh to see available emulator ids.

set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <emulator-id>" >&2
  echo "Run ./tool/list-devices.sh to see available emulator ids." >&2
  exit 2
fi

EMULATOR_ID="$1"

if ! flutter emulators 2>/dev/null | awk '{print $1}' | grep -Fxq "$EMULATOR_ID"; then
  echo "Error: emulator id '$EMULATOR_ID' not found." >&2
  echo "Available emulators:" >&2
  flutter emulators >&2
  exit 1
fi

echo "Launching emulator: $EMULATOR_ID"
flutter emulators --launch "$EMULATOR_ID"

echo "Waiting for emulator to register with Flutter..."
TIMEOUT_SECONDS=120
INTERVAL_SECONDS=3
ELAPSED=0
PREV_DEVICES=$(flutter devices --machine 2>/dev/null || echo "[]")

while [ "$ELAPSED" -lt "$TIMEOUT_SECONDS" ]; do
  CURRENT_DEVICES=$(flutter devices --machine 2>/dev/null || echo "[]")
  # New device appeared if the device list changed and now contains an emulator entry.
  if [ "$CURRENT_DEVICES" != "$PREV_DEVICES" ] && echo "$CURRENT_DEVICES" | grep -q '"emulator": *true'; then
    echo
    echo "Emulator is ready. Connected devices:"
    flutter devices
    exit 0
  fi
  sleep "$INTERVAL_SECONDS"
  ELAPSED=$((ELAPSED + INTERVAL_SECONDS))
  printf '.'
done

echo
echo "Error: emulator did not register within ${TIMEOUT_SECONDS}s." >&2
echo "Check 'flutter devices' manually." >&2
exit 1
