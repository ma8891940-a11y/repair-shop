import 'fake-indexeddb/auto';
import { beforeEach, describe, expect, it } from 'vitest';
import { WarshaDB, cacheGet, cacheSet, enqueue, failedItems, flush, isDuplicate, isNetworkError, pendingCount, retryFailed, type OutboxItem, type RunResult } from './outbox';

let db: WarshaDB;
let n = 0;
beforeEach(async () => {
  db = new WarshaDB(`test-${++n}`);
  await db.open();
});

describe('طابور العمليات بدون نت (outbox)', () => {
  it('نفس العملية لو اتضافت مرتين بتتسجل مرة واحدة', async () => {
    expect(await enqueue(db, 'payment', 'p1', { amount: 100 })).toBe(true);
    expect(await enqueue(db, 'payment', 'p1', { amount: 100 })).toBe(false);
    expect(await pendingCount(db)).toBe(1);
  });

  it('بيتبعت بنفس ترتيب الإضافة، وبيتشال من الطابور بعد ما يوصل', async () => {
    await enqueue(db, 'intake', 'd1', {}, 1000);
    await enqueue(db, 'status', 's1', {}, 1000);
    await enqueue(db, 'payment', 'p1', {}, 999); // اتعملت قبلهم بالوقت
    const order: string[] = [];
    const r = await flush(db, async (i) => {
      order.push(i.id);
      return { ok: true };
    });
    expect(order).toEqual(['p1', 'd1', 's1']);
    expect(r).toEqual({ sent: 3, failed: 0, stopped: false });
    expect(await pendingCount(db)).toBe(0);
  });

  it('النت قطع في النص: بيقف ويحافظ على الترتيب، ويكمّل من نفس النقطة بعدين', async () => {
    for (const id of ['a', 'b', 'c']) await enqueue(db, 'status', id, {});
    let online = true;
    const sent: string[] = [];
    const run = async (i: OutboxItem): Promise<RunResult> => {
      if (i.id === 'b' && online) {
        online = false;
        return { ok: false, network: true, error: 'Failed to fetch' };
      }
      sent.push(i.id);
      return { ok: true };
    };
    expect(await flush(db, run)).toEqual({ sent: 1, failed: 0, stopped: true });
    expect(await pendingCount(db)).toBe(2);
    expect((await db.outbox.get('b'))?.tries).toBe(1);
    expect(await flush(db, run)).toEqual({ sent: 2, failed: 0, stopped: false });
    expect(sent).toEqual(['a', 'b', 'c']);
  });

  it('رفض نهائي من السيرفر: العملية بتتعلّم "فشل" والباقي بيكمّل، وتقدر تتعاد', async () => {
    await enqueue(db, 'payment', 'x', {});
    await enqueue(db, 'payment', 'y', {});
    const r = await flush(db, async (i) => (i.id === 'x' ? { ok: false, network: false, error: 'E_BAD_AMOUNT' } : { ok: true }));
    expect(r).toEqual({ sent: 1, failed: 1, stopped: false });
    const f = await failedItems(db);
    expect(f.map((x) => [x.id, x.lastError])).toEqual([['x', 'E_BAD_AMOUNT']]);
    expect(await retryFailed(db)).toBe(1);
    expect(await pendingCount(db)).toBe(1);
  });

  it('أي خطأ غير متوقع بيتعامل كمشكلة شبكة (مفيش عملية بتضيع)', async () => {
    await enqueue(db, 'intake', 'z', {});
    const r = await flush(db, async () => {
      throw new TypeError('Failed to fetch');
    });
    expect(r.stopped).toBe(true);
    expect(await pendingCount(db)).toBe(1);
  });

  it('الكاش بيحفظ آخر نسخة ووقتها', async () => {
    await cacheSet(db, 'devices', [{ id: 1 }], 5);
    expect(await cacheGet(db, 'devices')).toEqual({ value: [{ id: 1 }], updatedAt: 5 });
    expect(await cacheGet(db, 'none')).toBeNull();
  });

  it('تمييز أخطاء الشبكة والتكرار', () => {
    expect(isNetworkError(new TypeError('Failed to fetch'))).toBe(true);
    expect(isNetworkError({ message: 'E_UNPAID' })).toBe(false);
    expect(isDuplicate({ code: '23505', message: 'duplicate key value' })).toBe(true);
    expect(isDuplicate({ code: '42501' })).toBe(false);
  });
});
