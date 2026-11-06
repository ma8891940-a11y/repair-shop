import { defineConfig } from 'vitest/config';
import react from '@vitejs/plugin-react';
import tailwindcss from '@tailwindcss/vite';
import { VitePWA } from 'vite-plugin-pwa';

export default defineConfig({
  // مسارات نسبية عشان التطبيق يشتغل جوه Electron/Tauri/Capacitor كمان
  base: './',
  plugins: [
    react(),
    tailwindcss(),
    VitePWA({
      registerType: 'autoUpdate',
      includeAssets: ['favicon-16.png', 'favicon-32.png', 'apple-touch-icon.png'],
      manifest: {
        name: 'جوالك | Gawalak',
        short_name: 'جوالك',
        description: 'جوالك: برنامج إدارة محل صيانة الموبايل',
        lang: 'ar',
        dir: 'rtl',
        display: 'standalone',
        start_url: './',
        scope: './',
        background_color: '#0b0f12',
        theme_color: '#0b0f12',
        icons: [
          { src: 'icon-192.png', sizes: '192x192', type: 'image/png', purpose: 'any' },
          { src: 'icon-512.png', sizes: '512x512', type: 'image/png', purpose: 'any' },
          { src: 'icon-maskable-192.png', sizes: '192x192', type: 'image/png', purpose: 'maskable' },
          { src: 'icon-maskable-512.png', sizes: '512x512', type: 'image/png', purpose: 'maskable' },
        ],
      },
    }),
  ],
  test: {
    include: ['src/**/*.test.ts', 'tests/db/**/*.test.ts'],
  },
});
