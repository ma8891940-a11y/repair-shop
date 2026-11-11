import { createContext, useCallback, useContext, useEffect, useState, type ReactNode } from 'react';
import { supabase } from '../lib/supabase';
import { cacheGet, cacheSet, localDb } from '../offline/outbox';
import { useAuth } from './auth';
import { can, granted, type Perms } from './navGroups';

interface PermsState {
  /** null = صاحب المحل (كل حاجة) أو لسه بتتحمّل (الدور الأساسي بيحكم لحد ما توصل) */
  perms: Perms | null;
  can: (section: string, op?: string) => boolean;
  /** صلاحية زيادة على الدور الأساسي (P المرحلة التانية): صاحب المحل، أو موظف (مش فني) متعلّمله في الجدول */
  grant: (section: string, op?: string) => boolean;
  /** الجدول وصل (أو مش محتاجينه): قبلها الشاشات المفتوحة بصلاحية زيادة لسه مش معروفة */
  loaded: boolean;
  reload: () => Promise<void>;
}
const Ctx = createContext<PermsState | null>(null);
export const PERMS_CHANGED = 'gawalak:perms-changed';

/**
 * P: صلاحيات المستخدم الفعلية من قاعدة البيانات (my_perms). الحماية نفسها في قاعدة البيانات،
 * وده بيخفي من الواجهة اللي المستخدم ملوش صلاحية عليه (القايمة والشاشات والأزرار).
 * بتتحدّث لما ترجع للبرنامج، وبعد أي تعديل في الأدوار، فالتغيير بيتطبق على طول من غير خروج ودخول.
 */
export function PermsProvider({ children }: { children: ReactNode }) {
  const { profile } = useAuth();
  const uid = profile?.id ?? '';
  const owner = profile?.role === 'owner';
  const [perms, setPerms] = useState<Perms | null>(null);
  const [loaded, setLoaded] = useState(false);
  const reload = useCallback(async () => {
    if (!uid || owner) {
      setPerms(null);
      return setLoaded(true);
    }
    const { data, error } = await supabase.rpc('my_perms');
    if (error) {
      const c = await cacheGet<Perms>(localDb(), `perms:${uid}`).catch(() => null);
      if (c) setPerms(c.value);
      return setLoaded(true);
    }
    setPerms((data ?? {}) as Perms);
    setLoaded(true);
    void cacheSet(localDb(), `perms:${uid}`, data ?? {}).catch(() => undefined);
  }, [uid, owner]);
  useEffect(() => {
    void reload();
    const on = () => void reload();
    window.addEventListener('focus', on);
    window.addEventListener('online', on);
    window.addEventListener(PERMS_CHANGED, on);
    return () => {
      window.removeEventListener('focus', on);
      window.removeEventListener('online', on);
      window.removeEventListener(PERMS_CHANGED, on);
    };
  }, [reload]);
  const role = profile?.role ?? '';
  return <Ctx.Provider value={{ perms, can: (s, o = 'view') => can(perms, s, o), grant: (s, o = 'view') => granted(role, perms, s, o), loaded, reload }}>{children}</Ctx.Provider>;
}

const ALL: PermsState = { perms: null, can: () => true, grant: () => true, loaded: true, reload: async () => undefined };
export function usePerms(): PermsState {
  return useContext(Ctx) ?? ALL;
}
