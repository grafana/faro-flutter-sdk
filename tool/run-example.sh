#!/usr/bin/env bash
# Run the example app with the same configuration as .vscode/launch.json.
#
# Any extra arguments are passed through to `flutter run`.
#
# Usage:
#   ./tool/run-example.sh                       # let flutter pick a device
#   ./tool/run-example.sh -d <device-id>        # specific device
#   ./tool/run-example.sh -d android --release  # Android release build
#
# Run ./tool/list-devices.sh to see device ids.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXAMPLE_DIR="$SCRIPT_DIR/../example"
CONFIG_FILE="$EXAMPLE_DIR/api-config.json"

if [ ! -f "$CONFIG_FILE" ]; then
  echo "Error: $CONFIG_FILE not found." >&2
  echo "Create it from the template:" >&2
  echo "  cp example/api-config.example.json example/api-config.json" >&2
  echo "Then edit it with your FARO_COLLECTOR_URL." >&2
  exit 1
fi

cd "$EXAMPLE_DIR"
exec flutter run \
  -t lib/main.dart \
  --dart-define-from-file=api-config.json \
  "$@"
