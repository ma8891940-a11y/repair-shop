import Dexie, { type Table } from 'dexie';

/**
 * التخزين على الجهاز (IndexedDB عن طريق Dexie):
 * - outbox: طابور العمليات اللي اتعملت بدون نت، بالترتيب. كل عملية ليها id من التطبيق، فلو اتبعتت مرتين ما بتتكررش.
 * - cache: آخر نسخة من البيانات اللي اتشافت (للفتح بدون نت).
 * - blobs: صور الاستلام اللي لسه ما اترفعتش.
 */
// البند 14: الشغل اليومي كله من غير نت: + التكلفة، والملاحظة الداخلية، والفحص السريع، والبيع
export type OpKind = 'intake' | 'status' | 'payment' | 'photo' | 'cost' | 'note' | 'check' | 'sale';
export interface OutboxItem {
  id: string; // نفس id العملية (للمنع من التكرار)
  seq: number; // ترتيب الإرسال
  kind: OpKind;
  payload: Record<string, unknown>;
  createdAt: number;
  tries: number;
  status: 'pending' | 'failed';
  lastError?: string;
}
export interface CacheItem {
  key: string;
  value: unknown;
  updatedAt: number;
}
export interface BlobItem {
  id: string;
  deviceId: string;
  shopId: string;
  blob: Blob;
  createdAt: number;
}

export class LocalDB extends Dexie {
  outbox!: Table<OutboxItem, string>;
  cache!: Table<CacheItem, string>;
  blobs!: Table<BlobItem, string>;
  // اسم قاعدة البيانات على الجهاز فاضل 'warsha' من قبل تغيير اسم التطبيق: لو اتغيّر، العمليات اللي لسه ما اتبعتتش على الأجهزة هتضيع
  constructor(name = 'warsha') {
    super(name);
    this.version(1).stores({ outbox: 'id, seq, status', cache: 'key', blobs: 'id, deviceId' });
  }
}

let shared: LocalDB | null = null;
export const localDb = () => (shared ??= new LocalDB());

let counter = 0;
/** يضيف عملية للطابور. لو نفس الـ id موجود، ما بيتضافش تاني */
export async function enqueue(db: LocalDB, kind: OpKind, id: string, payload: Record<string, unknown>, now = Date.now()): Promise<boolean> {
  return db.transaction('rw', db.outbox, async () => {
    if (await db.outbox.get(id)) return false;
    counter = (counter + 1) % 1000;
    await db.outbox.add({ id, seq: now * 1000 + counter, kind, payload, createdAt: now, tries: 0, status: 'pending' });
    return true;
  });
}

export const pendingCount = (db: LocalDB) => db.outbox.where('status').equals('pending').count();
export const failedItems = (db: LocalDB) => db.outbox.where('status').equals('failed').sortBy('seq');

/** نتيجة تنفيذ عملية: تمت، أو مشكلة شبكة (نوقف ونحاول بعدين بنفس الترتيب)، أو رفض نهائي من السيرفر */
export type RunResult = { ok: true } | { ok: false; network: true; error: string } | { ok: false; network: false; error: string };
export type Runner = (item: OutboxItem) => Promise<RunResult>;

/** بيبعت الطابور بالترتيب. مشكلة الشبكة بتوقف الإرسال (عشان الترتيب يفضل صح). الرفض النهائي بيتعلّم "فشل" ويكمّل */
export async function flush(db: LocalDB, run: Runner): Promise<{ sent: number; failed: number; stopped: boolean }> {
  let sent = 0;
  let failed = 0;
  const items = await db.outbox.where('status').equals('pending').sortBy('seq');
  for (const item of items) {
    const r = await run(item).catch((e: unknown) => ({ ok: false as const, network: true as const, error: String((e as Error)?.message ?? e) }));
    if (r.ok) {
      await db.outbox.delete(item.id); // اتبعتت للسيرفر: الطابور مكان مؤقت بس
      sent++;
      continue;
    }
    if (r.network) {
      await db.outbox.update(item.id, { tries: item.tries + 1, lastError: r.error });
      return { sent, failed, stopped: true };
    }
    await db.outbox.update(item.id, { tries: item.tries + 1, lastError: r.error, status: 'failed' });
    failed++;
  }
  return { sent, failed, stopped: false };
}

/** رجّع العمليات اللي فشلت للطابور (بعد ما المستخدم يصلّح السبب) */
export async function retryFailed(db: LocalDB): Promise<number> {
  const f = await failedItems(db);
  await Promise.all(f.map((x) => db.outbox.update(x.id, { status: 'pending' })));
  return f.length;
}

export async function cacheSet(db: LocalDB, key: string, value: unknown, now = Date.now()) {
  await db.cache.put({ key, value, updatedAt: now });
}
export async function cacheGet<T>(db: LocalDB, key: string): Promise<{ value: T; updatedAt: number } | null> {
  const r = await db.cache.get(key);
  return r ? { value: r.value as T, updatedAt: r.updatedAt } : null;
}

/** خطأ من الشبكة ولا من السيرفر؟ (أخطاء الشبكة بتتعاد، والسيرفر لأ) */
export function isNetworkError(e: unknown): boolean {
  const m = String((e as { message?: unknown })?.message ?? e ?? '');
  return /Failed to fetch|NetworkError|network|Load failed|fetch failed|ECONNREFUSED|timeout/i.test(m);
}
/** المفتاح اتسجل قبل كده (العملية وصلت فعلًا في محاولة قبل كده): نعتبرها تمت */
export function isDuplicate(e: unknown): boolean {
  const o = e as { code?: string; message?: string } | null;
  return o?.code === '23505' || /duplicate key/i.test(o?.message ?? '');
}
