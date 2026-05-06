#!/usr/bin/env bash
# List connected Flutter devices and available Android/iOS emulators,
# with hints for launching one and running the example app.

set -euo pipefail

bold() { printf '\033[1m%s\033[0m\n' "$1"; }
dim()  { printf '\033[2m%s\033[0m\n' "$1"; }

bold "Connected devices"
flutter devices
echo

bold "Available emulators"
flutter emulators
echo

bold "Next steps"
dim "  Boot an emulator:        ./tool/launch-emulator.sh <emulator-id>"
dim "  Run example on device:   ./tool/run-example.sh -d <device-id>"
dim "  Run example (auto pick): ./tool/run-example.sh"
