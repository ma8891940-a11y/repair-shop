import { errorMessage } from '../lib/errors';

/**
 * C3: كلمة السر الرئيسية. لما عملية حساسة ترجع E_MASTER_REQUIRED، بتظهر نافذة الكلمة (MasterPrompt في master.tsx)،
 * ولو اتكتبت صح العملية بتتعاد مرة واحدة. الفتح 5 دقايق لحساب اللي على الجهاز ده بس.
 */
export const isMasterError = (e: unknown) => /E_MASTER_REQUIRED/.test(errorMessage(e) + JSON.stringify((e as { message?: string })?.message ?? ''));

type Ask = (ok: boolean) => void;
let pending: Ask[] = [];
export const openers = new Set<() => void>();

/** النافذة بتقول النتيجة لكل اللي مستنيين */
export function settle(ok: boolean) {
  const list = pending;
  pending = [];
  for (const r of list) r(ok);
}

/** بيفتح نافذة الكلمة ويستنى: true لو اتفتح، false لو اتلغى */
export function askMaster(): Promise<boolean> {
  if (!openers.size) return Promise.resolve(false);
  return new Promise((resolve) => {
    pending.push(resolve);
    for (const o of openers) o();
  });
}

/** بيشغّل العملية، ولو محتاجة الكلمة بيسأل ويعيدها مرة واحدة */
export async function withMaster<T>(run: () => Promise<T>): Promise<T> {
  try {
    return await run();
  } catch (e) {
    if (!isMasterError(e) || !(await askMaster())) throw e;
    return run();
  }
}

/** نفس الفكرة للعمليات اللي بترجع { error } (تحديث الجداول مباشرة) */
export async function withMasterResult<R extends { error: unknown }>(run: () => PromiseLike<R>): Promise<R> {
  const r = await run();
  if (!r.error || !isMasterError(r.error) || !(await askMaster())) return r;
  return run();
}

