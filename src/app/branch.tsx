import { createContext, useCallback, useContext, useEffect, useMemo, useState, type ReactNode } from 'react';
import { supabase } from '../lib/supabase';
import { setBranchHeader } from '../lib/branchHeader';
import { cacheGet, cacheSet, localDb } from '../offline/outbox';
import { useAuth } from './auth';
import { useTranslation } from 'react-i18next';
import DB_DEFAULTS from '../data/dbDefaults.json';

export interface Branch {
  id: string;
  name: string;
  prefix: string;
  is_main: boolean;
  phone: string | null;
  address: string | null;
  /** P: صيانة بس، أو مبيعات بس، أو الاتنين */
  kind?: 'repair' | 'sales' | 'both';
}

interface BranchState {
  /** كل فروع المحل (المفتوحة) */
  all: Branch[];
  /** الفروع اللي المستخدم يشتغل فيها */
  mine: Branch[];
  /** المحل فيه أكتر من فرع (لو لأ، مفيش أي حاجة عن الفروع بتظهر) */
  multi: boolean;
  /** الفرع اللي العمليات بتتسجل عليه (بيتبعت مع كل طلب) */
  working: Branch | null;
  /** العرض: فرع واحد أو "كل الفروع" (صاحب المحل بس) */
  view: string | 'all';
  setView: (v: string | 'all') => void;
  /** فلتر الفرع للقوايم والتقارير (null = كل الفروع) */
  filter: string | null;
  name: (id: string | null | undefined) => string;
  reload: () => Promise<void>;
  ready: boolean;
}

const Ctx = createContext<BranchState | null>(null);
const viewKey = (uid: string) => `branch-view:${uid}`;
const workKey = (uid: string) => `branch-work:${uid}`;
const read = (k: string) => {
  try {
    return localStorage.getItem(k);
  } catch {
    return null;
  }
};
const write = (k: string, v: string) => {
  try {
    localStorage.setItem(k, v);
  } catch {
    /* التخزين مقفول */
  }
};

/** الفروع: بتتحمّل مرة بعد الدخول، وبتتحفظ على الجهاز (من غير نت كل فرع بيشتغل لوحده) */
export function BranchProvider({ children }: { children: ReactNode }) {
  const { profile } = useAuth();
  const uid = profile?.id ?? '';
  const owner = profile?.role === 'owner';
  const { t } = useTranslation();
  const [rawAll, setAll] = useState<Branch[]>([]);
  // U6: اسم الفرع الرئيسي الافتراضي (اللي قاعدة البيانات حطته بالعربي) بيتترجم في الإنجليزي، لحد ما صاحب المحل يغيّره
  const all = useMemo(() => rawAll.map((b) => (b.is_main && b.name === DB_DEFAULTS.mainBranch ? { ...b, name: t('branch.mainName') } : b)), [rawAll, t]);
  const [mineIds, setMineIds] = useState<string[]>([]);
  const [ready, setReady] = useState(false);
  const [view, setViewState] = useState<string>(() => (uid ? (read(viewKey(uid)) ?? '') : ''));
  const [workId, setWorkId] = useState<string>(() => (uid ? (read(workKey(uid)) ?? '') : ''));

  const reload = useCallback(async () => {
    if (!uid) return;
    try {
      const [b, m] = await Promise.all([
        supabase.from('branches').select('id, name, prefix, is_main, phone, address, kind').is('deleted_at', null).order('is_main', { ascending: false }).order('created_at'),
        supabase.rpc('my_branch_ids'),
      ]);
      if (b.error) throw b.error;
      if (m.error) throw m.error;
      const list = (b.data ?? []) as Branch[];
      const ids = ((m.data ?? []) as string[]).filter((x) => list.some((y) => y.id === x));
      setAll(list);
      setMineIds(ids);
      void cacheSet(localDb(), `branches:${uid}`, { list, ids }).catch(() => undefined);
    } catch {
      const c = await cacheGet<{ list: Branch[]; ids: string[] }>(localDb(), `branches:${uid}`).catch(() => null);
      if (c) {
        setAll(c.value.list);
        setMineIds(c.value.ids);
      }
    } finally {
      setReady(true);
    }
  }, [uid]);

  useEffect(() => {
    setReady(false);
    setViewState(uid ? (read(viewKey(uid)) ?? '') : '');
    setWorkId(uid ? (read(workKey(uid)) ?? '') : '');
    void reload();
  }, [uid, reload]);

  const mine = useMemo(() => all.filter((b) => mineIds.includes(b.id)), [all, mineIds]);
  const multi = all.length > 1 && (owner || mine.length > 1);
  // الفرع الشغال: اللي اتختار آخر مرة (لو لسه من فروعه)، وإلا الرئيسي أو أول فرع ليه
  const working = mine.find((b) => b.id === workId) ?? mine.find((b) => b.is_main) ?? mine[0] ?? null;
  const viewOk = view === 'all' ? owner && multi : mine.some((b) => b.id === view);
  const effView: string = !multi ? (working?.id ?? 'all') : viewOk ? view : (working?.id ?? 'all');

  useEffect(() => {
    // محل بفرع واحد: مفيش هيدر (قاعدة البيانات بتشتغل على الرئيسي)
    setBranchHeader(multi ? (working?.id ?? null) : null);
  }, [multi, working?.id]);

  const setView = useCallback(
    (v: string | 'all') => {
      if (!uid) return;
      setViewState(v);
      write(viewKey(uid), v);
      if (v !== 'all') {
        setWorkId(v);
        write(workKey(uid), v);
      }
    },
    [uid],
  );
  const name = useCallback((id: string | null | undefined) => all.find((b) => b.id === id)?.name ?? '', [all]);

  const value: BranchState = {
    all,
    mine,
    multi,
    working,
    view: effView,
    setView,
    filter: multi && effView !== 'all' ? effView : null,
    name,
    reload,
    ready,
  };
  return <Ctx.Provider value={value}>{children}</Ctx.Provider>;
}

const EMPTY: BranchState = { all: [], mine: [], multi: false, working: null, view: 'all', setView: () => undefined, filter: null, name: () => '', reload: async () => undefined, ready: true };

export function useBranch(): BranchState {
  return useContext(Ctx) ?? EMPTY;
}
