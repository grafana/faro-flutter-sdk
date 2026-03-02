# Remote Device Testing

Run the Faro example app on real Android devices without a local emulator, Android Studio, or Xcode — using [BrowserStack App Automate](https://www.browserstack.com/app-automate) and the Appium REST API.

This works from anywhere: a CI runner (GitHub Actions), a cloud-based AI agent (Cursor, Codex, Claude Code), or a developer's laptop.

## Prerequisites

Two environment variables are required:

- `BROWSERSTACK_USERNAME` — BrowserStack username (or service account)
- `BROWSERSTACK_ACCESS_KEY` — BrowserStack access key

Get these from [BrowserStack Account Settings](https://www.browserstack.com/accounts/settings).

## Workflow

### 1. Build the APK

```bash
# Create the config file (placeholder URL is fine for local testing)
FARO_COLLECTOR_URL="https://example.com/collect" bash tool/create-api-config-file.sh

# Build debug APK
cd example && flutter build apk --debug --dart-define-from-file api-config.json
```

### 2. Upload to BrowserStack

```bash
curl -s -u "${BROWSERSTACK_USERNAME}:${BROWSERSTACK_ACCESS_KEY}" \
  -X POST "https://api-cloud.browserstack.com/app-automate/upload" \
  -F "file=@build/app/outputs/flutter-apk/app-debug.apk" \
  -F "custom_id=faro-example-app"
```

Returns `app_url` (e.g. `bs://abc123...`). The `custom_id` lets you re-upload without changing session config — subsequent uploads overwrite the previous version.

### 3. Start an Appium session

```bash
curl -s -X POST \
  "https://${BROWSERSTACK_USERNAME}:${BROWSERSTACK_ACCESS_KEY}@hub-cloud.browserstack.com/wd/hub/session" \
  -H "Content-Type: application/json" \
  -d '{
    "desiredCapabilities": {
      "platformName": "android",
      "deviceName": "Google Pixel 8",
      "os_version": "14.0",
      "app": "faro-example-app",
      "project": "Faro Flutter SDK",
      "build": "Dev Test",
      "name": "Session Name",
      "autoGrantPermissions": true
    }
  }'
```

The response contains a `sessionId`. Set it for subsequent commands:

```bash
export BS_HUB="https://${BROWSERSTACK_USERNAME}:${BROWSERSTACK_ACCESS_KEY}@hub-cloud.browserstack.com/wd/hub"
export BS_SESSION_ID="<sessionId from response>"
```

### 4. Interact with the device

All commands use the Appium REST API via `curl`.

**Take a screenshot** (returns base64 PNG):

```bash
curl -s "${BS_HUB}/session/${BS_SESSION_ID}/screenshot" \
  | python3 -c "import sys,json,base64; data=json.load(sys.stdin); \
    open('screenshot.png','wb').write(base64.b64decode(data['value']))"
```

**Get UI element tree** (XML hierarchy with element bounds, text, and accessibility labels):

```bash
curl -s "${BS_HUB}/session/${BS_SESSION_ID}/source" \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['value'])"
```

**Find an element** by accessibility label:

```bash
curl -s -X POST "${BS_HUB}/session/${BS_SESSION_ID}/element" \
  -H "Content-Type: application/json" \
  -d '{"using": "accessibility id", "value": "Button Text"}'
```

Returns an element ID in the response.

**Click an element**:

```bash
curl -s -X POST "${BS_HUB}/session/${BS_SESSION_ID}/element/${ELEMENT_ID}/click" \
  -H "Content-Type: application/json" -d '{}'
```

**Scroll**:

```bash
curl -s -X POST "${BS_HUB}/session/${BS_SESSION_ID}/touch/scroll" \
  -H "Content-Type: application/json" \
  -d '{"x": 540, "y": 1200, "xoffset": 0, "yoffset": -400}'
```

### 5. End the session

```bash
curl -s -X DELETE "${BS_HUB}/session/${BS_SESSION_ID}"
```

## Tips

- **Custom ID reuse**: Using the same `custom_id` when uploading means session configs don't need to change between builds.
- **Device selection**: Change `deviceName` and `os_version` to test on different devices. List available devices at [BrowserStack device list](https://www.browserstack.com/list-of-browsers-and-platforms/app_automate).
- **Debug vs release**: Use `--debug` for development testing (faster builds, includes debug banner). Use `--release` for production-like testing.
- **Collector URL**: A placeholder URL is fine for visual testing. The app runs normally — telemetry just won't reach a real backend.
- **Session timeout**: BrowserStack sessions have idle timeouts. End sessions explicitly when done to free device capacity.

## Use in GitHub Actions

The same workflow works in CI. Set `BROWSERSTACK_USERNAME` and `BROWSERSTACK_ACCESS_KEY` as repository secrets, then call the same `curl` commands from a workflow step after building the APK.
