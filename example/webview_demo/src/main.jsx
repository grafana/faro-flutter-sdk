import { createRoot } from "react-dom/client";
import {
  ConsoleTransport,
  LogLevel,
  getWebInstrumentations,
  initializeFaro,
} from "@grafana/faro-web-sdk";
import { TracingInstrumentation } from "@grafana/faro-web-tracing";
import { InitialParentContextManager } from "./parentContextManager.js";
import App from "./App.jsx";
import "./index.css";

const params = new URLSearchParams(window.location.search);
const traceparent = params.get("traceparent");
const parentSessionId = params.get("session.parent_id");
const parentApp = params.get("session.parent_app");
const collectorUrl = import.meta.env.VITE_FARO_COLLECTOR_URL ?? "";
const serviceName =
  import.meta.env.VITE_FARO_SERVICE_NAME ?? "example_webview_react";

const initConfig = {
  app: {
    name: serviceName,
    version: "1.0.0",
    environment: "example",
  },
  instrumentations: [
    ...getWebInstrumentations({ captureConsole: false }),
    new TracingInstrumentation({
      contextManager: new InitialParentContextManager(traceparent),
      instrumentationOptions: {
        propagateTraceHeaderCorsUrls: [/.*/],
      },
    }),
  ],
  sessionTracking: {
    session: {
      attributes: {
        ...(parentSessionId && {
          "session.parent_id": parentSessionId,
        }),
        ...(parentApp && {
          "session.parent_app": parentApp,
        }),
      },
    },
  },
};

if (collectorUrl) {
  initConfig.url = collectorUrl;
} else {
  initConfig.transports = [new ConsoleTransport({ level: LogLevel.INFO })];
}

const faro = initializeFaro(initConfig);

if (window.HandoffBridge) {
  const webSessionId = faro.api.getSession()?.id;
  if (webSessionId) {
    window.HandoffBridge.postMessage(
      JSON.stringify({
        type: "faro_session",
        session_id: webSessionId,
        app_name: serviceName,
      }),
    );
  }
}

console.log(
  "[WebView Demo] traceparent from Flutter:",
  traceparent ?? "not provided",
);
console.log(
  "[WebView Demo] parent session: id=%s, app=%s",
  parentSessionId ?? "not provided",
  parentApp ?? "not provided",
);
console.log(
  "[WebView Demo] collector URL:",
  collectorUrl || "(none — using ConsoleTransport)",
);

createRoot(document.getElementById("root")).render(<App />);
