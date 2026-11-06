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
  refresh: () => Promise<void>;
  signOut: () => Promise<void>;
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
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(async (s: Session | null) => {
    setError(null);
    if (!s) {
      setProfile(null);
      setShop(null);
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
    setProfile((p as Profile) ?? null);
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

  return <Ctx.Provider value={{ loading, session, profile, shop, error, refresh, signOut }}>{children}</Ctx.Provider>;
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
