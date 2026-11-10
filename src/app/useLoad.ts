import { useCallback, useEffect, useRef, useState, type DependencyList } from 'react';
import { errorMessage } from '../lib/errors';
import { cacheGet, cacheSet, isNetworkError, localDb } from '../offline/outbox';

export interface Loaded<T> {
  data: T | undefined;
  error: string | null;
  loading: boolean;
  reload: () => void;
  /** وقت النسخة المحفوظة على الجهاز لو البيانات المعروضة منها (بدون نت) */
  stale: number | null;
}

/**
 * تحميل بيانات بحالات واضحة: تحميل / خطأ / بيانات.
 * أي رد قديم (من طلب اتلغى) بيتجاهل، فما يحصلش لخبطة لو المستخدم كتب بسرعة.
 */
export function useLoad<T>(fn: () => Promise<T>, deps: DependencyList, opts: { pollMs?: number; cacheKey?: string } = {}): Loaded<T> {
  const [data, setData] = useState<T>();
  const [stale, setStale] = useState<number | null>(null);
  const keyRef = useRef(opts.cacheKey);
  keyRef.current = opts.cacheKey;
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [tick, setTick] = useState(0);
  const seq = useRef(0);
  // محاولات تانية بعد فشل شبكة والنت شغال (طلب واحد ممكن يفشل والسيرفر مشغول)
  const retries = useRef(0);
  const fnRef = useRef(fn);
  fnRef.current = fn;

  useEffect(() => {
    const my = ++seq.current;
    setLoading(true);
    fnRef
      .current()
      .then((d) => {
        if (my !== seq.current) return;
        retries.current = 0;
        setData(d);
        setError(null);
        setStale(null);
        // نسخة على الجهاز عشان تتفتح بدون نت
        if (keyRef.current) void cacheSet(localDb(), keyRef.current, d).catch(() => undefined);
      })
      .catch(async (e: unknown) => {
        if (my !== seq.current) return;
        const online = typeof navigator === 'undefined' || navigator.onLine;
        // فشل شبكة والنت شغال: نحاول تاني لوحدنا (بعد 1 ثم 2 ثم 4 ثواني)، بدل ما نفضل على النسخة القديمة
        if (isNetworkError(e) && online && retries.current < 3) {
          const wait = 1000 * 2 ** retries.current++;
          setTimeout(() => {
            if (my === seq.current) setTick((x) => x + 1);
          }, wait);
        }
        if (keyRef.current && (isNetworkError(e) || !online)) {
          const c = await cacheGet<T>(localDb(), keyRef.current).catch(() => null);
          if (my !== seq.current) return;
          if (c) {
            setData(c.value);
            setStale(c.updatedAt);
            setError(null);
            return;
          }
        }
        setError(errorMessage(e));
      })
      .finally(() => {
        if (my === seq.current) setLoading(false);
      });
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [...deps, tick]);

  useEffect(() => {
    if (!opts.pollMs) return;
    const t = setInterval(() => setTick((x) => x + 1), opts.pollMs);
    return () => clearInterval(t);
  }, [opts.pollMs]);

  // النسخة المعروضة قديمة (من الجهاز): أول ما النت يرجع بنحمّل تاني
  useEffect(() => {
    if (stale == null) return;
    const on = () => setTick((x) => x + 1);
    window.addEventListener('online', on);
    return () => window.removeEventListener('online', on);
  }, [stale]);

  const reload = useCallback(() => {
    retries.current = 0;
    setTick((x) => x + 1);
  }, []);
  return { data, error, loading: loading && data === undefined, reload, stale };
}

/** يرمي الخطأ لو رد Supabase فيه خطأ، ويرجّع البيانات */
export function must<T>(r: { data: T | null; error: unknown }): T {
  if (r.error) throw r.error;
  return r.data as T;
}
