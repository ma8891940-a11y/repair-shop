import { createContext, useCallback, useContext, useEffect, useState, type ReactNode } from 'react';
import type { Session } from '@supabase/supabase-js';
import { supabase } from '../lib/supabase';
import { SHOP_COLUMNS, type Profile, type Shop } from '../lib/types';
import { isNetworkError, localDb } from '../offline/outbox';
import { mayHaveSessionNow } from '../lib/authFast';

interface AuthState {
  loading: boolean;
  session: Session | null;
  profile: Profile | null;
  shop: Shop | null;
  error: string | null;
  /** مشرف المنصة (لوحة المشرف) */
  isAdmin: boolean;
  /** المحل موقوف من المشرف */
  suspended: boolean;
  /** C3: الحساب مفعّل عليه 2FA والدخول لسه ما عدّاش الخطوة التانية */
  mfaNeeded: boolean;
  refresh: () => Promise<void>;
  signOut: () => Promise<void>;
}

interface Account {
  profile: Profile | null;
  shop: { id: string; name: string; theme: 'dark' | 'light'; locale: 'ar' | 'en'; suspended: boolean } | null;
  is_admin: boolean;
}
/** محل بأقل بيانات (لمدير التسويق أو المحل الموقوف): الاسم والمظهر بس */
function minimalShop(a: NonNullable<Account['shop']>): Shop {
  return { id: a.id, name: a.name, theme: a.theme, locale: a.locale, phone: null, address: null, receipt_terms: '', warranty_days: 0, country: 'EG', currency: 'EGP', payment_methods: [], logo_path: null, setup_completed_at: 'x' };
}

const Ctx = createContext<AuthState | null>(null);

const ME_KEY = 'me';
function readMe(uid: string): { profile: Profile; shop: Shop } | null {
  try {
    const v = JSON.parse(localStorage.getItem(ME_KEY) ?? 'null') as { uid: string; profile: Profile; shop: Shop } | null;
    return v && v.uid === uid ? { profile: v.profile, shop: v.shop } : null;
  } catch {
    return null;
  }
}
function writeMe(uid: string, v: { profile: Profile; shop: Shop }) {
  try {
    localStorage.setItem(ME_KEY, JSON.stringify({ uid, ...v }));
  } catch {
    /* */
  }
}

export function AuthProvider({ children }: { children: ReactNode }) {
  const [session, setSession] = useState<Session | null>(null);
  const [profile, setProfile] = useState<Profile | null>(null);
  const [shop, setShop] = useState<Shop | null>(null);
  // من غير جلسة محفوظة ولا رابط تأكيد: مش داخل أكيد، فشاشة الدخول بتظهر على طول (src/lib/authFast.ts)
  const [loading, setLoading] = useState(mayHaveSessionNow);
  const [isAdmin, setIsAdmin] = useState(false);
  const [suspended, setSuspended] = useState(false);
  const [mfaNeeded, setMfaNeeded] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(async (s: Session | null) => {
    setError(null);
    if (!s) {
      setProfile(null);
      setShop(null);
      setIsAdmin(false);
      setSuspended(false);
      setMfaNeeded(false);
      setLoading(false);
      return;
    }
    // C3: 2FA: لو الحساب عليه تطبيق تحقق والجلسة لسه aal1، الخطوة التانية الأول (قاعدة البيانات نفسها مش هتفتح البيانات من غيرها)
    const aal = await supabase.auth.mfa.getAuthenticatorAssuranceLevel().catch(() => null);
    const needs = aal?.data?.nextLevel === 'aal2' && aal.data.currentLevel !== 'aal2';
    setMfaNeeded(needs);
    if (needs) {
      setProfile(null);
      setShop(null);
      setLoading(false);
      return;
    }
    const one = async (cols: string) => {
      const r = await supabase.from('profiles').select(cols).eq('id', s.user.id).maybeSingle();
      return { data: r.data as unknown as Profile | null, error: r.error };
    };
    let { data: p, error: pe } = await one('id, shop_id, full_name, email, role, deleted_at, can_correct');
    // قاعدة بيانات لسه ما اتحدّثتش بملف 0026 (من غير عمود الإذن): الدخول يشتغل عادي، والإذن بيبقى مقفول
    if (pe && /can_correct/.test(pe.message)) ({ data: p, error: pe } = await one('id, shop_id, full_name, email, role, deleted_at'));
    // بدون نت: البرنامج بيفتح بآخر بيانات محفوظة للمستخدم ده على الجهاز
    if (pe && isNetworkError(pe)) {
      const cached = readMe(s.user.id);
      if (cached) {
        setProfile(cached.profile);
        setShop(cached.shop);
        setLoading(false);
        return;
      }
    }
    if (pe) setError(pe.message);
    let sh: Shop | null = null;
    if (p && !p.deleted_at) {
      const r = await supabase
        .from('shops')
        .select(SHOP_COLUMNS)
        .eq('id', p.shop_id)
        .maybeSingle();
      sh = (r.data as Shop) ?? null;
    }
    // حالة الحساب: مدير التسويق والمحل الموقوف ملهمش محل في الصلاحيات العادية، فبنعرف دورهم ومحلهم من my_account
    let prof = (p as Profile | null) ?? null;
    const acc = pe ? null : ((await supabase.rpc('my_account')).data as Account | null);
    setIsAdmin(Boolean(acc?.is_admin));
    setSuspended(Boolean(acc?.shop?.suspended));
    // بس للتسويق أو المحل الموقوف (مش وقت التسجيل، عشان الحساب ممكن يكون لسه بيتعمل)
    if (!prof && acc?.profile && acc.shop && (acc.profile.role === 'marketing' || acc.shop.suspended)) {
      prof = acc.profile;
      sh = minimalShop(acc.shop);
    }
    setProfile(prof);
    setShop(sh);
    if (p && sh) writeMe(s.user.id, { profile: p as Profile, shop: sh });
    setLoading(false);
  }, []);

  useEffect(() => {
    let active = true;
    void supabase.auth.getSession().then(({ data }) => {
      performance.mark('auth-session');
      if (!active) return;
      setSession(data.session);
      void load(data.session);
    });
    const { data: sub } = supabase.auth.onAuthStateChange((event, s) => {
      setSession(s);
      if (event === 'SIGNED_IN' || event === 'SIGNED_OUT' || event === 'USER_UPDATED' || event === 'MFA_CHALLENGE_VERIFIED') {
        // خارج callback المصادقة عشان ما يحصلش قفل
        setTimeout(() => void load(s), 0);
      }
    });
    return () => {
      active = false;
      sub.subscription.unsubscribe();
    };
  }, [load]);

  const refresh = useCallback(async () => {
    const { data } = await supabase.auth.getSession();
    await load(data.session);
  }, [load]);

  const signOut = useCallback(async () => {
    // الخروج بيمسح البيانات المحفوظة على الجهاز (عشان خصوصية العملاء لو الجهاز مشترك). العمليات اللي لسه ما اتبعتتش بتفضل
    try {
      localStorage.removeItem(ME_KEY);
      await localDb().cache.clear();
    } catch {
      /* التخزين ممكن يكون مقفول */
    }
    await endSession();
  }, []);

  return <Ctx.Provider value={{ loading, session, profile, shop, error, isAdmin, suspended, mfaNeeded, refresh, signOut }}>{children}</Ctx.Provider>;
}

/** مفاتيح جلسة Supabase المحفوظة على الجهاز */
const sessionKeys = () => {
  try {
    return Object.keys(localStorage).filter((k) => /^sb-.+-auth-token/.test(k));
  } catch {
    return [];
  }
};

/**
 * الخروج من غير أخطاء حتى لو الجلسة منتهية أو المستخدم اتحذف:
 * 1) لو الجلسة لسه صالحة: بنلغيها على السيرفر بدالة end_my_session (بترجع نجاح دايمًا، فمفيش 403 في الـ console).
 * 2) بنمسح الجلسة من الجهاز بس، من غير ما Supabase يكلّم السيرفر تاني (هو اللي كان بيطلّع 403).
 */
async function endSession() {
  let token: { access_token?: string; expires_at?: number } | null = null;
  for (const k of sessionKeys()) {
    try {
      const v = JSON.parse(localStorage.getItem(k) ?? 'null') as { access_token?: string; expires_at?: number } | null;
      if (v?.access_token) token = v;
    } catch {
      /* مش جلسة */
    }
  }
  const valid = token?.access_token && (token.expires_at ?? 0) * 1000 > Date.now() + 5_000;
  if (valid && (typeof navigator === 'undefined' || navigator.onLine)) {
    await supabase.rpc('end_my_session').then(
      () => undefined,
      () => undefined,
    );
  }
  for (const k of sessionKeys()) {
    try {
      localStorage.removeItem(k);
    } catch {
      /* التخزين ممكن يكون مقفول */
    }
  }
  // الجلسة مش متخزنة خلاص: Supabase بيمسحها من الذاكرة ويبلّغ إن المستخدم خرج، من غير أي طلب للسيرفر
  await supabase.auth.signOut({ scope: 'local' }).catch(() => undefined);
}

export function useAuth(): AuthState {
  const v = useContext(Ctx);
  if (!v) throw new Error('useAuth outside AuthProvider');
  return v;
}

/** للشاشات اللي جوه البرنامج: المستخدم داخل وليه محل */
export function useMe(): { profile: Profile; shop: Shop; refresh: () => Promise<void> } {
  const { profile, shop, refresh } = useAuth();
  if (!profile || !shop) throw new Error('not signed in');
  return { profile, shop, refresh };
}
