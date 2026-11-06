import { createContext, useCallback, useContext, useEffect, useState, type ReactNode } from 'react';
import type { Session } from '@supabase/supabase-js';
import { supabase } from '../lib/supabase';
import { SHOP_COLUMNS, type Profile, type Shop } from '../lib/types';
import { isNetworkError, localDb } from '../offline/outbox';

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
  const [loading, setLoading] = useState(true);
  const [isAdmin, setIsAdmin] = useState(false);
  const [suspended, setSuspended] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(async (s: Session | null) => {
    setError(null);
    if (!s) {
      setProfile(null);
      setShop(null);
      setIsAdmin(false);
      setSuspended(false);
      setLoading(false);
      return;
    }
    const { data: p, error: pe } = await supabase
      .from('profiles')
      .select('id, shop_id, full_name, email, role, deleted_at')
      .eq('id', s.user.id)
      .maybeSingle();
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
      if (!active) return;
      setSession(data.session);
      void load(data.session);
    });
    const { data: sub } = supabase.auth.onAuthStateChange((event, s) => {
      setSession(s);
      if (event === 'SIGNED_IN' || event === 'SIGNED_OUT' || event === 'USER_UPDATED') {
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
    await supabase.auth.signOut();
  }, []);

  return <Ctx.Provider value={{ loading, session, profile, shop, error, isAdmin, suspended, refresh, signOut }}>{children}</Ctx.Provider>;
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
