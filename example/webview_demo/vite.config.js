import { Buffer } from 'node:buffer'
import { URL } from 'node:url'
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// Serves the mock /api/login endpoint used by the React demo.
function webviewDemoApiPlugin() {
  return {
    name: 'webview-demo-api',
    configureServer(server) {
      server.middlewares.use('/api/login', async (req, res, next) => {
        if (!req.url) {
          next()
          return
        }

        const requestUrl = new URL(req.url, 'http://127.0.0.1')
        const delayMs = Number(requestUrl.searchParams.get('delayMs') ?? '650')
        const chunks = []

        for await (const chunk of req) {
          chunks.push(Buffer.from(chunk))
        }

        const rawBody = Buffer.concat(chunks).toString('utf-8')
        let parsedBody = null
        if (rawBody) {
          try {
            parsedBody = JSON.parse(rawBody)
          } catch {
            parsedBody = { rawBody }
          }
        }

        await new Promise((resolve) => {
          setTimeout(resolve, delayMs)
        })

        const simulateFail =
          requestUrl.searchParams.get('simulateFail') === 'true'

        const statusCode = simulateFail ? 401 : 200
        const responseBody = JSON.stringify({
          ok: !simulateFail,
          delayMs,
          method: req.method ?? 'GET',
          traceparent: req.headers.traceparent ?? null,
          message: simulateFail
            ? 'Invalid credentials'
            : 'Login successful',
          requestBody: parsedBody,
        })

        res.statusCode = statusCode
        res.setHeader('Content-Type', 'application/json')
        res.setHeader('Cache-Control', 'no-store')
        res.end(responseBody)
      })
    },
  }
}

export default defineConfig({
  plugins: [react(), webviewDemoApiPlugin()],
  server: {
    host: '0.0.0.0',
  },
})
