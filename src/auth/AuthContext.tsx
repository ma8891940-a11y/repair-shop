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

  const loadProfile = useCallback(async (s: Session | null) => {
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
    if (p && !p.deleted_at) {
      const { data: sh } = await supabase
        .from('shops')
        .select('id, name, phone, address, receipt_terms, warranty_days')
        .eq('id', p.shop_id)
        .maybeSingle();
      setProfile(p as Profile);
      setShop((sh as Shop) ?? null);
    } else {
      setProfile(p ? (p as Profile) : null);
      setShop(null);
    }
    setLoading(false);
  }, []);

  useEffect(() => {
    let active = true;
    supabase.auth.getSession().then(({ data }) => {
      if (!active) return;
      setSession(data.session);
      void loadProfile(data.session);
    });
    const { data: sub } = supabase.auth.onAuthStateChange((event, s) => {
      setSession(s);
      // نأجل القراءة عشان ما نعملش طلب جوه callback المصادقة نفسه
      if (event === 'SIGNED_IN' || event === 'SIGNED_OUT' || event === 'USER_UPDATED') {
        setTimeout(() => void loadProfile(s), 0);
      }
    });
    return () => {
      active = false;
      sub.subscription.unsubscribe();
    };
  }, [loadProfile]);

  const refresh = useCallback(async () => {
    const { data } = await supabase.auth.getSession();
    await loadProfile(data.session);
  }, [loadProfile]);

  const signOut = useCallback(async () => {
    await supabase.auth.signOut();
  }, []);

  return (
    <Ctx.Provider value={{ loading, session, profile, shop, error, refresh, signOut }}>
      {children}
    </Ctx.Provider>
  );
}

export function useAuth(): AuthState {
  const v = useContext(Ctx);
  if (!v) throw new Error('useAuth outside AuthProvider');
  return v;
}

/** للصفحات اللي جوه البرنامج (بعد ما المستخدم يدخل ويبقى ليه محل) */
export function useMe(): { profile: Profile; shop: Shop; refresh: () => Promise<void> } {
  const { profile, shop, refresh } = useAuth();
  if (!profile || !shop) throw new Error('not signed in');
  return { profile, shop, refresh };
}
