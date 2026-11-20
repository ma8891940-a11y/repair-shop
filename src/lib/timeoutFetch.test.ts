import { describe, expect, it } from 'vitest';
import { timeoutFetch } from './timeoutFetch';
import { isNetworkError } from '../offline/outbox';

/** fetch وهمي: بيرد بعد وقت، أو بيفضل معلّق لحد ما الطلب يتلغي */
const slow = (ms: number | null) =>
  ((_: RequestInfo | URL, init?: RequestInit) =>
    new Promise<Response>((resolve, reject) => {
      const tm = ms == null ? null : setTimeout(() => resolve(new Response('{}')), ms);
      init?.signal?.addEventListener('abort', () => {
        if (tm) clearTimeout(tm);
        reject(init.signal!.reason);
      });
    })) as typeof fetch;

describe('مهلة الطلبات', () => {
  it('طلب معلّق لقاعدة البيانات أو الدخول بيتلغي بعد المهلة، والخطأ بيتعامل زي انقطاع النت', async () => {
    for (const u of ['https://x/rest/v1/customers', 'https://x/auth/v1/token']) {
      const e = await timeoutFetch(slow(null), 30)(u).catch((x) => x);
      expect(String(e?.name)).toBe('TimeoutError');
      // نفس شكل رسالة supabase-js لما الـ fetch يفشل
      expect(isNetworkError({ message: `${e.name}: ${e.message}` })).toBe(true);
    }
  });
  it('الطلب اللي بيرد قبل المهلة بيرجع عادي', async () => {
    const r = await timeoutFetch(slow(5), 200)('https://x/rest/v1/devices');
    expect(r.ok).toBe(true);
  });
  it('الصور والدوال من غير مهلة (الرفع ممكن ياخد وقت)', async () => {
    const r = await timeoutFetch(slow(60), 20)('https://x/storage/v1/object/a.png');
    expect(r.ok).toBe(true);
  });
  it('إلغاء من برّه بيوصل للطلب', async () => {
    const c = new AbortController();
    const p = timeoutFetch(slow(null), 10_000)('https://x/rest/v1/devices', { signal: c.signal }).catch((x) => x);
    c.abort(new DOMException('stop', 'AbortError'));
    expect(String((await p)?.name)).toBe('AbortError');
  });
});
