import { createContext, useCallback, useContext, useEffect, useState, type ReactNode } from 'react';
import type { Session } from '@supabase/supabase-js';
import { supabase } from '../lib/supabase';
import type { Profile, Shop } from '../lib/types';

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
    if (pe) setError(pe.message);
    let sh: Shop | null = null;
    if (p && !p.deleted_at) {
      const r = await supabase
        .from('shops')
        .select('id, name, phone, address, receipt_terms, warranty_days')
        .eq('id', p.shop_id)
        .maybeSingle();
      sh = (r.data as Shop) ?? null;
    }
    setProfile((p as Profile) ?? null);
    setShop(sh);
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
