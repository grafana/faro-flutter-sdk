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
   `?traceparent=00-<traceId>-<spanId>-01&correlation.from.session_id=<id>&correlation.from.app_name=<name>`
2. `main.jsx` reads the `traceparent` from the URL and passes it to a
   custom `InitialParentContextManager` (see `parentContextManager.js`).
   This sets the Flutter span as the root context for **all**
   auto-instrumented spans (fetch, XHR) — no manual `context.with()`
   needed in application code.
3. `main.jsx` also reads the `correlation.from.*` query parameters and
   stores them as Faro session attributes, linking this web session back
   to the originating Flutter session.
4. After Faro initialises, the web app sends its own Faro session ID
   back to Flutter via the `HandoffBridge` JS channel (`faro_session`
   message). Flutter pushes a `correlation.linked` event with
   `correlation.to.*` attributes, completing the bidirectional link.
5. The user taps "Log in" (optionally toggling "Simulate failure").
   The auto-instrumented `POST /api/login` fetch carries the trace
   context, appearing as a child span under the Flutter `WebView` span
   in Grafana Tempo.
6. The React app sends the login result back to Flutter via the
   `HandoffBridge` (`login_result` message). Flutter pops the WebView
   and shows the result as a SnackBar.

## Key files

| File | Purpose |
|------|---------|
| `src/main.jsx` | Faro SDK init, traceparent + correlation setup |
| `src/App.jsx` | Demo login UI, Flutter communication |
| `src/parentContextManager.js` | Custom OTel ContextManager for automatic parent propagation |
| `vite.config.js` | Mock `/api/login` endpoint |
| `.env.example` | Environment variable template |
