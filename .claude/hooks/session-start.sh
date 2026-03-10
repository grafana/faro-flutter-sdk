#!/bin/bash
set -euo pipefail

# Only run in remote Claude Code web environments
if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

FLUTTER_DIR="/opt/flutter"

# Install Flutter if not already installed
if [ ! -f "$FLUTTER_DIR/bin/flutter" ]; then
  echo "Installing Flutter (stable)..."

  # Fetch the latest stable release archive URL using python3
  FLUTTER_URL=$(python3 -c "
import urllib.request, json
url = 'https://storage.googleapis.com/flutter_infra_release/releases/releases_linux.json'
with urllib.request.urlopen(url) as r:
    data = json.load(r)
    archive = next(
        rel['archive']
        for rel in data['releases']
        if rel['channel'] == 'stable'
    )
    print('https://storage.googleapis.com/flutter_infra_release/releases/' + archive)
")

  echo "Downloading Flutter from: $FLUTTER_URL"
  curl -sS "$FLUTTER_URL" | tar -xJ -C /opt

  # Fix git safe.directory for the Flutter SDK (installed as different user)
  git config --global --add safe.directory "$FLUTTER_DIR"

  # Disable analytics to avoid prompts
  "$FLUTTER_DIR/bin/flutter" config --no-analytics
  echo "Flutter installed successfully."
else
  echo "Flutter already installed at $FLUTTER_DIR"
  git config --global --add safe.directory "$FLUTTER_DIR"
fi

# Add Flutter to PATH for this session and future sessions
export PATH="$FLUTTER_DIR/bin:$PATH"
echo "export PATH=\"$FLUTTER_DIR/bin:\$PATH\"" >> "$CLAUDE_ENV_FILE"

# Disable analytics (idempotent — safe to run each session)
flutter config --no-analytics 2>/dev/null || true

# Install Dart/Flutter package dependencies
echo "Running flutter pub get..."
cd "${CLAUDE_PROJECT_DIR}"
flutter pub get

echo "Session setup complete."
