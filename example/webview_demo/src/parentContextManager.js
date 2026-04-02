import { ROOT_CONTEXT, TraceFlags, trace } from '@opentelemetry/api'

/**
 * A ContextManager that uses a parsed traceparent as the default active
 * context instead of ROOT_CONTEXT. This makes all auto-instrumented spans
 * (fetch, XHR) children of the provided parent trace, without requiring
 * manual `context.with()` wrapping in application code.
 *
 * When no traceparent is provided it behaves identically to OTel's
 * built-in StackContextManager.
 *
 * This is the **web-side glue** for cross-boundary tracing between a
 * native Flutter app and a Faro-instrumented web app loaded in a WebView.
 * On the Flutter side the counterpart is `FaroWebViewBridge` (from
 * `package:faro`) which creates the parent span and appends `traceparent`,
 * `session.parent_id`, and `session.parent_app` to the URL.
 *
 * **Note:** This class currently lives in the example app while the
 * approach is being evaluated. It may be promoted into the Faro Web SDK
 * (`@grafana/faro-web-tracing`) in the future. In the meantime, feel free
 * to copy it into your own project and adapt as needed.
 *
 * Usage with Faro Web SDK:
 *
 *   import { InitialParentContextManager } from './parentContextManager'
 *
 *   const traceparent = new URLSearchParams(location.search).get('traceparent')
 *
 *   initializeFaro({
 *     instrumentations: [
 *       new TracingInstrumentation({
 *         contextManager: new InitialParentContextManager(traceparent),
 *       }),
 *     ],
 *     // ...
 *   })
 */
export class InitialParentContextManager {
  _enabled = false
  _currentContext = ROOT_CONTEXT

  constructor(traceparent) {
    this._rootContext = traceparent
      ? parseTraceparentToContext(traceparent)
      : ROOT_CONTEXT
  }

  active() {
    return this._currentContext
  }

  with(context, fn, thisArg, ...args) {
    const previous = this._currentContext
    this._currentContext = context || this._rootContext
    try {
      return fn.call(thisArg, ...args)
    } finally {
      this._currentContext = previous
    }
  }

  bind(context, target) {
    if (context === undefined) {
      context = this.active()
    }
    if (typeof target === 'function') {
      return this._bindFunction(context, target)
    }
    return target
  }

  enable() {
    if (this._enabled) return this
    this._enabled = true
    this._currentContext = this._rootContext
    return this
  }

  disable() {
    this._currentContext = ROOT_CONTEXT
    this._enabled = false
    return this
  }

  _bindFunction(context, target) {
    const manager = this
    const contextWrapper = function (...args) {
      return manager.with(context, () => target.apply(this, args))
    }
    Object.defineProperty(contextWrapper, 'length', {
      enumerable: false,
      configurable: true,
      writable: false,
      value: target.length,
    })
    return contextWrapper
  }
}

function parseTraceparentToContext(traceparent) {
  const parts = traceparent.split('-')
  if (parts.length < 4) return ROOT_CONTEXT

  return trace.setSpanContext(ROOT_CONTEXT, {
    traceId: parts[1],
    spanId: parts[2],
    traceFlags: (() => {
      const parsed = parseInt(parts[3], 16)
      return Number.isNaN(parsed) ? TraceFlags.SAMPLED : parsed
    })(),
    isRemote: true,
  })
}
