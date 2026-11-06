import { createContext, useCallback, useContext, useEffect, useRef, useState, type ReactNode } from 'react';
import { supabase } from '../lib/supabase';
import { uploadDevicePhoto } from '../lib/photos';
import { enqueue, failedItems, flush, isDuplicate, isNetworkError, localDb, pendingCount, retryFailed, type OpKind, type OutboxItem, type RunResult } from './outbox';

/**
 * المزامنة: العمليات الأساسية (استلام، تغيير حالة، دفعة، صور) بتتسجل على الجهاز الأول لو النت فاصل،
 * وبتتبعت لوحدها بالترتيب أول ما النت يرجع. تغيير الحالة بيتبعت بقاعدة "آخر تعديل بالوقت يكسب" (apply_status_lww).
 */
interface SyncState {
  online: boolean;
  pending: number;
  failed: number;
  syncing: boolean;
  lastSync: number | null;
  /** يسجّل عملية في الطابور ويحاول يبعتها على طول لو فيه نت */
  queue: (kind: OpKind, id: string, payload: Record<string, unknown>) => Promise<void>;
  syncNow: () => Promise<void>;
  retry: () => Promise<void>;
}
const Ctx = createContext<SyncState>({
  online: true,
  pending: 0,
  failed: 0,
  syncing: false,
  lastSync: null,
  queue: async () => {},
  syncNow: async () => {},
  retry: async () => {},
});
export const useSync = () => useContext(Ctx);

const res = (error: unknown): RunResult => (isNetworkError(error) ? { ok: false, network: true, error: String((error as Error)?.message ?? error) } : { ok: false, network: false, error: String((error as { message?: string })?.message ?? error) });
/** إضافة صف ممكن تكون وصلت في محاولة قبل كده: التكرار = تمت */
async function insertOnce(table: string, row: Record<string, unknown>) {
  const { error } = await supabase.from(table).insert(row);
  if (error && !isDuplicate(error)) throw error;
}

/** تنفيذ عملية من الطابور على السيرفر */
export async function runItem(item: OutboxItem): Promise<RunResult> {
  const p = item.payload;
  try {
    if (item.kind === 'status') {
      const { data, error } = await supabase.rpc('apply_status_lww', { p_device: p.device, p_status: p.status, p_client_ts: new Date(item.createdAt).toISOString() });
      if (error) throw error;
      return { ok: true, ...(data as object) } as RunResult;
    }
    if (item.kind === 'payment') {
      const { error } = await supabase.rpc('record_payment', p);
      if (error) throw error;
      return { ok: true };
    }
    if (item.kind === 'intake') {
      const device = { ...(p.device as Record<string, unknown>) };
      if (p.customer) {
        const c = p.customer as { id: string; phone: string };
        const { error } = await supabase.from('customers').insert(c);
        if (error && isDuplicate(error)) {
          // الرقم متسجل قبل كده (اتضاف من جهاز تاني وانت بدون نت): الجهاز بيتربط بالعميل الموجود
          const { data: ex } = await supabase.from('customers').select('id').eq('phone', c.phone).is('deleted_at', null).maybeSingle();
          if (ex && ex.id !== c.id) device.customer_id = ex.id;
        } else if (error) throw error;
      }
      await insertOnce('devices', device);
      await insertOnce('device_costs', p.cost as Record<string, unknown>);
      if (p.check) await insertOnce('device_checks', p.check as Record<string, unknown>);
      const dev = p.device as { id: string };
      if (p.route) {
        // المسار مرة واحدة بس (لو الجهاز ملوش خطوات)
        const { count } = await supabase.from('repair_steps').select('id', { count: 'exact', head: true }).eq('device_id', dev.id);
        if (!count) {
          const { error } = await supabase.rpc('set_route', { p_device: dev.id, p_route: p.route });
          if (error) throw error;
        }
      }
      if (p.lock) {
        const { error } = await supabase.rpc('set_device_passcode', { p_device_id: dev.id, ...(p.lock as object) });
        if (error) throw error;
      }
      return { ok: true };
    }
    if (item.kind === 'photo') {
      const blob = await localDb().blobs.get(item.id);
      if (!blob) return { ok: true };
      await uploadDevicePhoto(blob.shopId, blob.deviceId, new File([blob.blob], 'photo.jpg', { type: blob.blob.type || 'image/jpeg' }));
      await localDb().blobs.delete(item.id);
      return { ok: true };
    }
    return { ok: false, network: false, error: 'E_UNKNOWN_OP' };
  } catch (e) {
    return res(e);
  }
}

export function SyncProvider({ children, run = runItem }: { children: ReactNode; run?: (i: OutboxItem) => Promise<RunResult> }) {
  const [online, setOnline] = useState(() => (typeof navigator === 'undefined' ? true : navigator.onLine));
  const [pending, setPending] = useState(0);
  const [failed, setFailed] = useState(0);
  const [syncing, setSyncing] = useState(false);
  const [lastSync, setLastSync] = useState<number | null>(null);
  const busy = useRef(false);

  const refresh = useCallback(async () => {
    const db = localDb();
    setPending(await pendingCount(db));
    setFailed((await failedItems(db)).length);
  }, []);

  const syncNow = useCallback(async () => {
    if (busy.current || !navigator.onLine) return;
    busy.current = true;
    setSyncing(true);
    try {
      const r = await flush(localDb(), run);
      if (!r.stopped) setLastSync(Date.now());
      if (r.stopped) setOnline(false);
    } finally {
      busy.current = false;
      setSyncing(false);
      await refresh();
    }
  }, [run, refresh]);

  const queue = useCallback(
    async (kind: OpKind, id: string, payload: Record<string, unknown>) => {
      await enqueue(localDb(), kind, id, payload);
      await refresh();
      void syncNow();
    },
    [refresh, syncNow],
  );
  const retry = useCallback(async () => {
    await retryFailed(localDb());
    await refresh();
    await syncNow();
  }, [refresh, syncNow]);

  useEffect(() => {
    void refresh().then(() => syncNow());
    const on = () => {
      setOnline(true);
      void syncNow();
    };
    const off = () => setOnline(false);
    window.addEventListener('online', on);
    window.addEventListener('offline', off);
    // محاولة كل 20 ثانية لو فيه حاجة مستنية (النت ممكن يرجع من غير حدث online)
    const iv = window.setInterval(() => {
      if (navigator.onLine) void syncNow();
    }, 20_000);
    return () => {
      window.removeEventListener('online', on);
      window.removeEventListener('offline', off);
      clearInterval(iv);
    };
  }, [refresh, syncNow]);

  return <Ctx.Provider value={{ online, pending, failed, syncing, lastSync, queue, syncNow, retry }}>{children}</Ctx.Provider>;
}

/** هل الخطأ ده معناه إن العملية لازم تتسجل على الجهاز وتتبعت بعدين؟ */
export const shouldQueue = (e: unknown) => (typeof navigator !== 'undefined' && !navigator.onLine) || isNetworkError(e);
