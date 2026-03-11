import { useState } from 'react'
import { faro } from '@grafana/faro-web-sdk'
import './App.css'

// Posts a JSON message to the Flutter WebView via the HandoffBridge
// JavaScript channel. When running outside a WebView (e.g. in a
// browser for development) the channel won't exist and this is a no-op.
function notifyFlutter(payload) {
  if (
    window.HandoffBridge &&
    typeof window.HandoffBridge.postMessage === 'function'
  ) {
    window.HandoffBridge.postMessage(JSON.stringify(payload))
  }
}

function App() {
  const [simulateFail, setSimulateFail] = useState(false)
  const [isLoading, setIsLoading] = useState(false)
  const [result, setResult] = useState(null)

  async function handleLogin() {
    if (isLoading) return
    setIsLoading(true)
    setResult(null)

    try {
      const loginUrl = new URL('/api/login', window.location.origin)
      loginUrl.searchParams.set('delayMs', '650')
      if (simulateFail) {
        loginUrl.searchParams.set('simulateFail', 'true')
      }

      const response = await fetch(loginUrl.toString(), {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({
          username: 'demo-user@example.com',
          otp: '123456',
        }),
      })
      const body = await response.json()
      const ok = body.ok === true

      faro.api.pushEvent('webview_login_complete', {
        ok: String(ok),
      })

      const loginResult = {
        type: 'login_result',
        ok,
        message: body.message ?? (ok ? 'Login successful' : 'Login failed'),
      }

      setResult(loginResult)
      // Brief delay so the user sees the result before the WebView closes.
      setTimeout(() => notifyFlutter(loginResult), 800)
    } catch (error) {
      const errorResult = {
        type: 'login_result',
        ok: false,
        message: `Network error: ${error}`,
      }
      setResult(errorResult)
      setTimeout(() => notifyFlutter(errorResult), 800)
    } finally {
      setIsLoading(false)
    }
  }

  return (
    <main className="login-shell">
      <div className="login-card">
        <h1 className="login-title">Demo Login</h1>
        <p className="login-subtitle">WebView tracing test page</p>

        {result ? (
          <div className={`result-banner ${result.ok ? 'success' : 'error'}`}>
            {result.ok ? 'Login successful' : 'Login failed'}
          </div>
        ) : (
          <>
            <label className="toggle-row">
              <input
                type="checkbox"
                checked={simulateFail}
                onChange={(e) => setSimulateFail(e.target.checked)}
                disabled={isLoading}
              />
              <span>Simulate failure</span>
            </label>

            <button
              className="login-button"
              type="button"
              onClick={handleLogin}
              disabled={isLoading}
            >
              {isLoading ? 'Signing in\u2026' : 'Log in'}
            </button>
          </>
        )}
      </div>
    </main>
  )
}

export default App
