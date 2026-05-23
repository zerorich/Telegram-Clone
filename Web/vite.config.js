import { defineConfig, loadEnv } from 'vite'
import react from '@vitejs/plugin-react'

// Configure dev proxies so the client can call /api, /uploads and /ws against a
// running Go backend without CORS hassles. In production, the env vars are used
// directly (see src/lib/env.js).
export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, process.cwd(), '')
  const target = env.VITE_DEV_PROXY_TARGET || 'http://localhost:8080'
  const wsTarget = target.replace(/^http/, 'ws')

  return {
    plugins: [react()],
    server: {
      port: 5173,
      host: true,
      proxy: {
        '/api': { target, changeOrigin: true },
        '/uploads': { target, changeOrigin: true },
        '/ws': { target: wsTarget, ws: true, changeOrigin: true },
      },
    },
    build: {
      target: 'es2020',
      sourcemap: false,
    },
  }
})
