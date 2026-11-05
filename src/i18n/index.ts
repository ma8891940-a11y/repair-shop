import i18n from 'i18next';
import { initReactI18next } from 'react-i18next';
import ar from './ar.json';
import en from './en.json';

export type Lang = 'ar' | 'en';
export const LANGS: readonly Lang[] = ['ar', 'en'];
const KEY = 'lang';

export function readSavedLang(): Lang {
  try {
    const v = localStorage.getItem(KEY);
    if (v === 'ar' || v === 'en') return v;
  } catch {
    /* التخزين ممكن يكون مقفول */
  }
  return 'ar';
}

/** يطبّق اللغة على الصفحة كلها: الاتجاه (RTL/LTR) واللغة */
export function applyLang(lang: Lang) {
  const root = document.documentElement;
  root.lang = lang;
  root.dir = lang === 'ar' ? 'rtl' : 'ltr';
  try {
    localStorage.setItem(KEY, lang);
  } catch {
    /* تجاهل */
  }
}

void i18n.use(initReactI18next).init({
  resources: { ar: { translation: ar }, en: { translation: en } },
  lng: readSavedLang(),
  fallbackLng: 'ar',
  interpolation: { escapeValue: false },
  returnNull: false,
});

applyLang(i18n.language as Lang);
i18n.on('languageChanged', (l) => applyLang(l as Lang));

export default i18n;
