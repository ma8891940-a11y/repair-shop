// طلب لقاعدة البيانات أو الدخول ما يفضلش معلّق للأبد لو الاتصال وقف في النص (نت المحل الضعيف):
// بعد المهلة بيتلغي برسالة فيها "Timeout"، فالبرنامج بيتعامل معاه زي انقطاع النت (الطابور بيكمّل، ومفيش تكرار بفضل مفاتيح العمليات).
// الصور (Storage) والدوال (Edge Functions) مش داخلين: الرفع ممكن ياخد وقت أطول.
export const REQUEST_TIMEOUT_MS = 30_000;

const timed = (url: string) => url.includes('/rest/v1/') || url.includes('/auth/v1/');

export function timeoutFetch(base?: typeof fetch, ms = REQUEST_TIMEOUT_MS): typeof fetch {
  return (input, init) => {
    const f = base ?? globalThis.fetch;
    const url = typeof input === 'string' ? input : input instanceof URL ? input.href : input.url;
    if (!timed(url)) return f(input, init);
    const ctl = new AbortController();
    const tm = setTimeout(() => ctl.abort(new DOMException('request took too long', 'TimeoutError')), ms);
    // لو الطلب نفسه ليه إلغاء (supabase-js بيبعت signal أحيانًا) الاتنين شغالين
    const outer = init?.signal;
    if (outer) {
      if (outer.aborted) ctl.abort(outer.reason);
      else outer.addEventListener('abort', () => ctl.abort(outer.reason), { once: true });
    }
    return f(input, { ...init, signal: ctl.signal }).finally(() => clearTimeout(tm));
  };
}
