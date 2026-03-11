# WebView Tracing Demo (React)

A small React app instrumented with
[Faro Web SDK](https://www.npmjs.com/package/@grafana/faro-web-sdk) and
[Faro Web Tracing](https://www.npmjs.com/package/@grafana/faro-web-tracing).
It runs inside the Flutter example app's WebView to demonstrate
cross-boundary distributed tracing.

## Quick start

```bash
npm install
cp .env.example .env    # edit with your Faro Web collector URL
npm run dev
```

The dev server starts on `http://localhost:5173` (all interfaces).

Then add the URL to your `example/api-config.json`:

```json
{
  "FARO_COLLECTOR_URL": "https://your-collector-url",
  "FARO_WEBVIEW_DEMO_URL": "http://10.0.2.2:5173"
}
```

Use `http://10.0.2.2:5173` for the Android emulator or
`http://localhost:5173` for the iOS simulator.

## How it works

1. The Flutter app opens this page in a WebView with
   `?traceparent=00-<traceId>-<spanId>-01`
2. `main.jsx` reads the `traceparent` from the URL and passes it to a
   custom `InitialParentContextManager` (see `parentContextManager.js`).
   This sets the Flutter span as the root context for **all**
   auto-instrumented spans (fetch, XHR) — no manual `context.with()`
   needed in application code.
3. The user taps "Log in" (optionally toggling "Simulate failure").
   The auto-instrumented `POST /api/login` fetch carries the trace
   context, appearing as a child span under the Flutter `WebView` span
   in Grafana Tempo.
4. The React app sends the login result back to Flutter via the
   `HandoffBridge` JavaScript channel
   (`window.HandoffBridge.postMessage(json)`). Flutter pops the WebView
   and shows the result as a SnackBar.

## Key files

| File | Purpose |
|------|---------|
| `src/main.jsx` | Faro SDK init, traceparent setup |
| `src/App.jsx` | Demo login UI, Flutter communication |
| `src/parentContextManager.js` | Custom OTel ContextManager for automatic parent propagation |
| `vite.config.js` | Mock `/api/login` endpoint |
| `.env.example` | Environment variable template |
