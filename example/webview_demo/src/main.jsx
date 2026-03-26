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
const correlationFromSessionId = params.get("correlation.from.session_id");
const correlationFromAppName = params.get("correlation.from.app_name");
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
        ...(correlationFromSessionId && {
          "correlation.from.session_id": correlationFromSessionId,
        }),
        ...(correlationFromAppName && {
          "correlation.from.app_name": correlationFromAppName,
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
  "[WebView Demo] correlation from: session_id=%s, app_name=%s",
  correlationFromSessionId ?? "not provided",
  correlationFromAppName ?? "not provided",
);
console.log(
  "[WebView Demo] collector URL:",
  collectorUrl || "(none — using ConsoleTransport)",
);

createRoot(document.getElementById("root")).render(<App />);
