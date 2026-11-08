import { createContext, useCallback, useContext, useEffect, useState, type ReactNode } from 'react';
import i18n, { type Lang } from '../i18n';
import { LOGO_ANIMS, type LogoAnim } from '../ui/LogoIntro';

/** شكل الحركة الافتراضي لحد ما صاحب المشروع يختار (نفس القيمة في index.html) */
export const DEFAULT_LOGO_ANIM: LogoAnim = 'draw';

export type Theme = 'dark' | 'light';

function read<T extends string>(key: string, allowed: readonly T[], fallback: T): T {
  try {
    const v = localStorage.getItem(key) as T | null;
    if (v && allowed.includes(v)) return v;
  } catch {
    /* التخزين ممكن يكون مقفول */
  }
  return fallback;
}
function write(key: string, v: string) {
  try {
    localStorage.setItem(key, v);
  } catch {
    /* تجاهل */
  }
}

interface Prefs {
  theme: Theme;
  setTheme: (t: Theme) => void;
  toggleTheme: () => void;
  /** المؤثرات الكاملة (الخلفية الحية والتوهج والزجاج): مقفولة افتراضيًا، والاختيار محفوظ لكل جهاز لوحده */
  effects: boolean;
  setEffects: (v: boolean) => void;
  /** true لو الجهاز طالب "تقليل الحركة": كل الحركة بتقف (حتى الأساسية) */
  calm: boolean;
  /** المؤثرات الكاملة شغالة فعلًا: التوهج اللي بيتبع الماوس، ونبض الأرقام، والزجاج والـ blur. الحركة الأساسية مش محتاجاها */
  rich: boolean;
  /** شكل حركة لوجو التطبيق في الافتتاحية (من الإعدادات ← المظهر) */
  logoAnim: LogoAnim;
  setLogoAnim: (a: LogoAnim) => void;
  lang: Lang;
  setLang: (l: Lang) => void;
  toggleLang: () => void;
}

const Ctx = createContext<Prefs | null>(null);

const REDUCE = '(prefers-reduced-motion: reduce)';
/**
 * "تقليل الحركة" من الجهاز، وبيتحدّث على طول لو اتغيّر والبرنامج مفتوح (من غير ما تحدّث الصفحة).
 * (useReducedMotion بتاعة motion بتقرا مرة واحدة بس.)
 */
function useReducedMotionLive(): boolean {
  const [v, setV] = useState(() => {
    try {
      return window.matchMedia(REDUCE).matches;
    } catch {
      return false;
    }
  });
  useEffect(() => {
    let mq: MediaQueryList;
    try {
      mq = window.matchMedia(REDUCE);
    } catch {
      return;
    }
    const on = () => setV(mq.matches);
    on();
    mq.addEventListener('change', on);
    return () => mq.removeEventListener('change', on);
  }, []);
  return v;
}

export function PrefsProvider({ children }: { children: ReactNode }) {
  const [theme, setThemeState] = useState<Theme>(() => read('theme', ['dark', 'light'] as const, 'dark'));
  const [effects, setEffectsState] = useState<boolean>(() => read('effects', ['1', '0'] as const, '0') === '1');
  const [lang, setLangState] = useState<Lang>(() => (i18n.language === 'en' ? 'en' : 'ar'));
  const [logoAnim, setLogoAnimState] = useState<LogoAnim>(() => read('logo-anim', LOGO_ANIMS, DEFAULT_LOGO_ANIM));
  const reduced = useReducedMotionLive();

  useEffect(() => {
    document.documentElement.setAttribute('data-theme', theme);
    document.querySelector('meta[name="theme-color"]')?.setAttribute('content', theme === 'dark' ? '#0b0f12' : '#eef3f9');
    write('theme', theme);
  }, [theme]);

  useEffect(() => {
    // data-lite = المؤثرات الكاملة مقفولة (الـ CSS بيشيل الزجاج والتوهج)
    document.documentElement.toggleAttribute('data-lite', !effects);
    write('effects', effects ? '1' : '0');
  }, [effects]);

  useEffect(() => {
    void i18n.changeLanguage(lang);
  }, [lang]);

  const setTheme = useCallback((t: Theme) => setThemeState(t), []);
  const toggleTheme = useCallback(() => setThemeState((t) => (t === 'dark' ? 'light' : 'dark')), []);
  const setEffects = useCallback((v: boolean) => setEffectsState(v), []);
  const setLang = useCallback((l: Lang) => setLangState(l), []);
  const setLogoAnim = useCallback((a: LogoAnim) => {
    setLogoAnimState(a);
    write('logo-anim', a);
    // index.html بيقرا ده قبل ما الكود يحمّل (عشان أول لحظة تبقى زي أول فريم في الحركة)
    document.documentElement.setAttribute('data-logo-anim', a);
  }, []);
  const toggleLang = useCallback(() => setLangState((l) => (l === 'ar' ? 'en' : 'ar')), []);

  return (
    <Ctx.Provider value={{ theme, setTheme, toggleTheme, effects, setEffects, calm: reduced, rich: effects && !reduced, logoAnim, setLogoAnim, lang, setLang, toggleLang }}>
      {children}
    </Ctx.Provider>
  );
}

export function usePrefs(): Prefs {
  const v = useContext(Ctx);
  if (!v) throw new Error('usePrefs outside PrefsProvider');
  return v;
}
