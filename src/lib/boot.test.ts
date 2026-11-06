import { describe, expect, it } from 'vitest';
import { readFileSync } from 'node:fs';

const read = (p: string) => readFileSync(new URL(`../../${p}`, import.meta.url), 'utf8');

describe('أول لحظة قبل ما الكود يحمّل', () => {
  const tokens = read('src/styles/tokens.css');
  const darkBg = /--bg:\s*(#[0-9a-f]{6})/i.exec(tokens)![1].toLowerCase();
  const lightBg = /\[data-theme='light'\][\s\S]*?--bg:\s*(#[0-9a-f]{6})/i.exec(tokens)?.[1].toLowerCase() ?? /--bg:\s*#[0-9a-f]{6}[\s\S]*?--bg:\s*(#[0-9a-f]{6})/i.exec(tokens)![1].toLowerCase();

  it('لون الخلفية في الـ manifest (شاشة فتح التطبيق المثبّت) هو نفس لون خلفية البرنامج بالظبط', () => {
    const cfg = read('vite.config.ts');
    expect(/background_color:\s*'(#[0-9a-f]{6})'/i.exec(cfg)![1].toLowerCase()).toBe(darkBg);
    expect(/theme_color:\s*'(#[0-9a-f]{6})'/i.exec(cfg)![1].toLowerCase()).toBe(darkBg);
  });

  it('index.html بيعرض نفس الخلفية واللوجو ثابت في النص (بنفس مقاس وشفافية بداية الافتتاحية)', () => {
    const html = read('index.html');
    expect(html).toContain(`html { background: ${darkBg}; }`);
    expect(html).toContain(`html[data-theme='light'] { background: ${lightBg}; }`);
    expect(html).toMatch(/<div id="boot"[^>]*>.*<img src="%BOOT_LOGO%"/);
    // نفس اللي بتبدأ منه الافتتاحية: ارتفاع 150، وتصغير 0.92، وشفافية 0.55
    expect(html).toMatch(/#boot img \{[^}]*height: 150px;[^}]*scale\(0\.92\);[^}]*opacity: 0\.55;/);
    const splash = read('src/screens/SplashScreen.tsx');
    expect(splash).toContain('SPLASH_LOGO_H = 150');
    expect(splash).toContain('initial={calm ? { opacity: 0.55 } : { opacity: 0.55, scale: 0.92 }}');
  });
});
