import { useEffect, useMemo, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { useAuth } from './auth';
import { supabase } from '../lib/supabase';
import { accentCss, accentVars } from '../lib/accent';
import defaultLogo from '../assets/app-logo.png';

/**
 * U4: هوية صاحب المحل في التطبيق نفسه: اسم التطبيق ولوجوه ولون الإبراز (shops.extras.app).
 * "جوالك" ولوجوه هما الافتراضي لما المحل ما يغيّرش.
 * بيتحفظوا على الجهاز (آخر محل اتفتح)، عشان الافتتاحية وشاشة الدخول يظهروا بهوية المحل قبل ما حد يسجّل،
 * ولكل محل رابط دخول خاص (#/?shop=رقم المحل) بيجيب الاسم واللوجو بس (بيانات عامة، مفيش أي بيانات تانية).
 */
export interface AppBrand {
  name?: string | null;
  logo?: string | null;
  accent?: string | null;
}
const KEY = 'app-brand';

export function readAppBrand(extras: unknown): AppBrand {
  const a = extras && typeof extras === 'object' ? (extras as Record<string, unknown>).app : null;
  if (!a || typeof a !== 'object') return {};
  const o = a as Record<string, unknown>;
  const s = (v: unknown, max: number) => (typeof v === 'string' && v.trim() && v.length <= max ? v.trim() : null);
  return { name: s(o.name, 40), logo: typeof o.logo === 'string' && o.logo.startsWith('data:image/') ? o.logo : null, accent: s(o.accent, 7) };
}

export function cachedBrand(): AppBrand {
  try {
    return JSON.parse(localStorage.getItem(KEY) ?? '{}') as AppBrand;
  } catch {
    return {};
  }
}
function cacheBrand(b: AppBrand) {
  try {
    if (b.name || b.logo || b.accent) localStorage.setItem(KEY, JSON.stringify(b));
    else localStorage.removeItem(KEY);
  } catch {
    /* التخزين مقفول: الهوية بتفضل في الجلسة بس */
  }
}

/** رابط دخول المحل: ?shop=<id> في الرابط (قبل أو بعد #) */
function linkShop(): string | null {
  const q = new URLSearchParams(window.location.search).get('shop') ?? new URLSearchParams(window.location.hash.split('?')[1] ?? '').get('shop');
  return q && /^[0-9a-f-]{36}$/i.test(q) ? q : null;
}

export function useAppBrand(): { name: string; logo: string; accent: string | null; custom: boolean } {
  const { t } = useTranslation();
  const { shop } = useAuth();
  const [pre, setPre] = useState<AppBrand>(() => cachedBrand());
  const live = useMemo(() => (shop ? readAppBrand((shop as { extras?: unknown }).extras) : null), [shop]);
  // قبل الدخول: رابط محل معيّن بيجيب هويته من غير بيانات تانية
  useEffect(() => {
    if (shop) return;
    const id = linkShop();
    if (!id) return;
    void supabase.rpc('public_app_brand', { p_shop: id }).then(({ data }) => {
      if (data && typeof data === 'object') {
        const b = readAppBrand({ app: data });
        cacheBrand(b);
        setPre(b);
      }
    });
  }, [shop]);
  useEffect(() => {
    if (live) cacheBrand(live);
  }, [live]);
  const b = live ?? pre;
  return { name: b.name || t('app.name'), logo: b.logo || defaultLogo, accent: b.accent ?? null, custom: !!(b.name || b.logo) };
}

/** بيطبّق الهوية على الصفحة: لون الإبراز، وعنوان التبويب، وأيقونة المتصفح، والـ manifest (للتثبيت) */
export function AppBrandEffects() {
  const b = useAppBrand();
  useEffect(() => {
    let el = document.getElementById('brand-accent') as HTMLStyleElement | null;
    const v = b.accent ? accentVars(b.accent) : null;
    if (!v) return el?.remove();
    if (!el) {
      el = document.createElement('style');
      el.id = 'brand-accent';
      document.head.appendChild(el);
    }
    el.textContent = accentCss(v);
  }, [b.accent]);
  useEffect(() => {
    document.title = b.name;
    if (!b.custom) return;
    // أيقونة التبويب
    for (const l of document.querySelectorAll<HTMLLinkElement>('link[rel="icon"]')) l.href = b.logo;
    // manifest للتثبيت باسم المحل ولوجوه (الأجهزة اللي البرنامج متثبّت عليها محتاجة تثبيت جديد عشان يظهروا)
    void iconsFrom(b.logo).then((icons) => {
      const m = { name: b.name, short_name: b.name.slice(0, 12), start_url: './', display: 'standalone', dir: document.documentElement.dir || 'rtl', lang: document.documentElement.lang || 'ar', background_color: '#0b0f12', theme_color: '#0b0f12', icons };
      const url = URL.createObjectURL(new Blob([JSON.stringify(m)], { type: 'application/manifest+json' }));
      let link = document.querySelector<HTMLLinkElement>('link[rel="manifest"]');
      if (!link) {
        link = document.createElement('link');
        link.rel = 'manifest';
        document.head.appendChild(link);
      }
      link.href = url;
    });
  }, [b.name, b.logo, b.custom]);
  return null;
}

/** أيقونات 192 و512 من اللوجو (مربعة، واللوجو في النص) */
async function iconsFrom(src: string): Promise<{ src: string; sizes: string; type: string; purpose?: string }[]> {
  const img = new Image();
  img.src = src;
  try {
    await img.decode();
  } catch {
    return [];
  }
  return [192, 512].map((n) => {
    const c = document.createElement('canvas');
    c.width = c.height = n;
    const g = c.getContext('2d')!;
    g.fillStyle = '#0b0f12';
    g.fillRect(0, 0, n, n);
    const k = Math.min((n * 0.8) / img.naturalWidth, (n * 0.8) / img.naturalHeight);
    const w = img.naturalWidth * k;
    const h = img.naturalHeight * k;
    g.drawImage(img, (n - w) / 2, (n - h) / 2, w, h);
    return { src: c.toDataURL('image/png'), sizes: `${n}x${n}`, type: 'image/png', purpose: 'any' };
  });
}
