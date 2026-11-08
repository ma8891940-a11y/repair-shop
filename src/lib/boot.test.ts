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
    // نفس أول فريم في حركة "ظهور بلمعة": ارتفاع 150، وتصغير 0.9، وشفافية 0.55
    expect(html).toMatch(/#boot img \{[^}]*height: 150px;[^}]*scale\(0\.9\);[^}]*opacity: 0\.55;/);
    const splash = read('src/screens/SplashScreen.tsx');
    expect(splash).toContain('SPLASH_LOGO_H = 150');
    const intro = read('src/ui/LogoIntro.tsx');
    expect(intro).toContain("initial: { opacity: 0.55, scale: 0.9 }");
    // "رسم" و"تجميع" بيبدأوا من غير لوجو، فاللوجو الثابت مستخبي فيهم (مفيش قفزة)
    expect(html).toContain("html:not([data-logo-anim='shine']) #boot img { opacity: 0; }");
    // نفس الشكل الافتراضي في index.html وفي الكود
    const def = /DEFAULT_LOGO_ANIM: LogoAnim = '(\w+)'/.exec(read('src/app/prefs.tsx'))![1];
    expect(html).toContain(`: '${def}');`);
  });
});
