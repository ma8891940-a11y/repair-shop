// الفرع الشغال: بيتبعت مع كل طلب لقاعدة البيانات في الهيدر x-branch-id.
// قاعدة البيانات بتتأكد إن الموظف ليه الفرع ده (op_branch)، وإلا بتشتغل على فرعه الافتراضي.
// المحل اللي ليه فرع واحد: مفيش هيدر خالص.
let current: string | null = null;

export const BRANCH_HEADER = 'x-branch-id';

export function setBranchHeader(id: string | null) {
  current = id;
}
export function getBranchHeader(): string | null {
  return current;
}

/**
 * fetch لعميل Supabase: بيزوّد الهيدر في طلبات قاعدة البيانات بس (rest/v1)، مش Auth ولا Storage ولا Edge Functions
 * (عشان الـ CORS بتاعهم). لو الطلب نفسه فيه الهيدر (عملية من الطابور بفرعها الأصلي) بيفضل زي ما هو.
 */
export function branchFetch(base?: typeof fetch): typeof fetch {
  return (input, init) => {
    const f = base ?? globalThis.fetch;
    const b = current;
    const url = typeof input === 'string' ? input : input instanceof URL ? input.href : input.url;
    if (!b || !url.includes('/rest/v1/')) return f(input, init);
    const headers = new Headers(init?.headers ?? (input instanceof Request ? input.headers : undefined));
    if (!headers.has(BRANCH_HEADER)) headers.set(BRANCH_HEADER, b);
    return f(input, { ...init, headers });
  };
}
