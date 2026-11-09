import { defineConfig, devices } from '@playwright/test';

/**
 * اختبارات المتصفح (E2E). محتاجة Supabase محلي شغّال:
 *   E2E_SUPABASE_URL و E2E_SUPABASE_ANON_KEY (من `supabase status`)
 * مشروع لكل شاشة (كمبيوتر/موبايل) ولكل وضع (داكن/فاتح).
 */
const url = process.env.E2E_SUPABASE_URL ?? 'http://127.0.0.1:54321';
const anon = process.env.E2E_SUPABASE_ANON_KEY ?? '';
const PORT = 5180;

export default defineConfig({
  testDir: 'tests/e2e',
  // قاعدة الاختبار المحلية بتتنضف قبل التشغيل، وكل اللي التشغيل عمله بيتمسح في الآخر
  globalSetup: './tests/e2e/globalSetup.ts',
  timeout: 90_000,
  expect: { timeout: 10_000 },
  fullyParallel: false,
  workers: 1,
  retries: 0,
  reporter: [['list']],
  use: { baseURL: `http://127.0.0.1:${PORT}/`, trace: 'retain-on-failure', locale: 'ar-EG' },
  projects: [
    { name: 'desktop-dark', use: { viewport: { width: 1440, height: 900 }, colorScheme: 'dark' }, metadata: { theme: 'dark' } },
    { name: 'desktop-light', use: { viewport: { width: 1440, height: 900 }, colorScheme: 'light' }, metadata: { theme: 'light' } },
    { name: 'mobile-dark', use: { ...devices['Pixel 7'], colorScheme: 'dark' }, metadata: { theme: 'dark' } },
    { name: 'mobile-light', use: { ...devices['Pixel 7'], colorScheme: 'light' }, metadata: { theme: 'light' } },
  ],
  webServer: {
    // E2E_PROD=1: نفس الاختبارات على النسخة النهائية (build ثم preview) بدل سيرفر التطوير
    command: process.env.E2E_PROD
      ? `npx vite build --outDir dist-e2e --emptyOutDir && npx vite preview --outDir dist-e2e --port ${PORT} --strictPort`
      : `npx vite --port ${PORT} --strictPort`,
    url: `http://127.0.0.1:${PORT}/`,
    reuseExistingServer: true,
    env: { VITE_SUPABASE_URL: url, VITE_SUPABASE_ANON_KEY: anon },
    timeout: process.env.E2E_PROD ? 180_000 : 60_000,
  },
});
