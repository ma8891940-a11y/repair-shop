import { createContext, useCallback, useContext, useEffect, useState, type ReactNode } from 'react';
import { useReducedMotion } from 'motion/react';
import i18n, { type Lang } from '../i18n';

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
  /** وضع خفيف للأجهزة الضعيفة: بيوقف الخلفية الحية والتأثيرات التقيلة */
  lite: boolean;
  setLite: (v: boolean) => void;
  /** true لو المفروض نوقف الحركة التقيلة (وضع خفيف أو "تقليل الحركة" في الجهاز) */
  calm: boolean;
  lang: Lang;
  setLang: (l: Lang) => void;
  toggleLang: () => void;
}

const Ctx = createContext<Prefs | null>(null);

export function PrefsProvider({ children }: { children: ReactNode }) {
  const [theme, setThemeState] = useState<Theme>(() => read('theme', ['dark', 'light'] as const, 'dark'));
  const [lite, setLiteState] = useState<boolean>(() => read('lite', ['1', '0'] as const, '0') === '1');
  const [lang, setLangState] = useState<Lang>(() => (i18n.language === 'en' ? 'en' : 'ar'));
  const reduced = useReducedMotion() ?? false;

  useEffect(() => {
    document.documentElement.setAttribute('data-theme', theme);
    document.querySelector('meta[name="theme-color"]')?.setAttribute('content', theme === 'dark' ? '#0b0f12' : '#eef3f9');
    write('theme', theme);
  }, [theme]);

  useEffect(() => {
    document.documentElement.toggleAttribute('data-lite', lite);
    write('lite', lite ? '1' : '0');
  }, [lite]);

  useEffect(() => {
    void i18n.changeLanguage(lang);
  }, [lang]);

  const setTheme = useCallback((t: Theme) => setThemeState(t), []);
  const toggleTheme = useCallback(() => setThemeState((t) => (t === 'dark' ? 'light' : 'dark')), []);
  const setLite = useCallback((v: boolean) => setLiteState(v), []);
  const setLang = useCallback((l: Lang) => setLangState(l), []);
  const toggleLang = useCallback(() => setLangState((l) => (l === 'ar' ? 'en' : 'ar')), []);

  return (
    <Ctx.Provider value={{ theme, setTheme, toggleTheme, lite, setLite, calm: lite || reduced, lang, setLang, toggleLang }}>
      {children}
    </Ctx.Provider>
  );
}

export function usePrefs(): Prefs {
  const v = useContext(Ctx);
  if (!v) throw new Error('usePrefs outside PrefsProvider');
  return v;
}
