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

const traceparent = new URLSearchParams(window.location.search).get(
  "traceparent",
);
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
};

if (collectorUrl) {
  initConfig.url = collectorUrl;
} else {
  initConfig.transports = [new ConsoleTransport({ level: LogLevel.INFO })];
}

initializeFaro(initConfig);

console.log(
  "[WebView Demo] traceparent from Flutter:",
  traceparent ?? "not provided",
);
console.log(
  "[WebView Demo] collector URL:",
  collectorUrl || "(none — using ConsoleTransport)",
);

createRoot(document.getElementById("root")).render(<App />);
