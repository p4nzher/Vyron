import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

// Faz 7.5 — Vyron Yönetim Paneli. `VITE_API_BASE_URL` build-time'da
// enjekte edilir (bkz. `.env.example` ve `Dockerfile`).
export default defineConfig({
  plugins: [react()],
  server: {
    port: 5173,
  },
  build: {
    outDir: 'dist',
    sourcemap: true,
  },
});
