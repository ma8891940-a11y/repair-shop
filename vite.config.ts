import { defineConfig } from 'vitest/config';
import react from '@vitejs/plugin-react';
import tailwindcss from '@tailwindcss/vite';
import { VitePWA } from 'vite-plugin-pwa';
import { readFileSync } from 'node:fs';

/** اللوجو الثابت اللي بيظهر من أول لحظة (قبل ما الكود يحمّل) بيتحط جوه index.html نفسه، من غير أي طلب للشبكة */
const bootLogo = () => ({
  name: 'boot-logo',
  transformIndexHtml(html: string) {
    const b64 = readFileSync(new URL('./src/assets/boot-logo.webp', import.meta.url)).toString('base64');
    return html.replace('%BOOT_LOGO%', `data:image/webp;base64,${b64}`);
  },
});

/**
 * الخط العربي الأساسي (عادي ومتوسط) بيتطلب من أول لحظة مع الكود، بدل ما المتصفح يكتشفه وهو بيرسم الكلام.
 * كده الكلام ما بيترسمش مرتين وسط الافتتاحية (فرق واضح على الأجهزة الضعيفة). في نسخة الإنتاج بس.
 */
const preloadFonts = () => ({
  name: 'preload-fonts',
  transformIndexHtml(_html: string, ctx: { bundle?: Record<string, unknown> }) {
    if (!ctx.bundle) return [];
    return Object.keys(ctx.bundle)
      .filter((f) => /ibm-plex-sans-arabic-arabic-(400|500)-normal-[\w-]+\.woff2$/.test(f))
      .map((f) => ({ tag: 'link', attrs: { rel: 'preload', as: 'font', type: 'font/woff2', href: `./${f}`, crossorigin: '' }, injectTo: 'head' as const }));
  },
});

export default defineConfig({
  // مسارات نسبية عشان التطبيق يشتغل جوه Electron/Tauri/Capacitor كمان
  base: './',
  plugins: [
    react(),
    preloadFonts(),
    tailwindcss(),
    bootLogo(),
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
  // النسخة النهائية (npm run preview) على نفس عنوان npm run dev، عشان رابط تأكيد الإيميل (Site URL) يشتغل في الاتنين
  preview: { port: 5173, strictPort: true },
  test: {
    include: ['src/**/*.test.ts', 'tests/db/**/*.test.ts'],
  },
});
