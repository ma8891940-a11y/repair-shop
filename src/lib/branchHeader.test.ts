import { afterEach, describe, expect, it } from 'vitest';
import { branchFetch, setBranchHeader } from './branchHeader';

describe('هيدر الفرع الشغال', () => {
  afterEach(() => setBranchHeader(null));
  const seen: { url: string; h: string | null }[] = [];
  const base = (async (input: RequestInfo | URL, init?: RequestInit) => {
    seen.push({ url: String(input), h: new Headers(init?.headers).get('x-branch-id') });
    return new Response('{}');
  }) as typeof fetch;

  it('بيتبعت لقاعدة البيانات بس، ومش للدخول ولا الصور ولا الدوال', async () => {
    seen.length = 0;
    setBranchHeader('b-2');
    const f = branchFetch(base);
    await f('https://x.supabase.co/rest/v1/devices?select=*', { headers: { apikey: 'k' } });
    await f('https://x.supabase.co/auth/v1/token');
    await f('https://x.supabase.co/storage/v1/object/a.png');
    await f('https://x.supabase.co/functions/v1/assist');
    expect(seen.map((s) => s.h)).toEqual(['b-2', null, null, null]);
  });
  it('من غير فرع (محل بفرع واحد) مفيش هيدر، والطلب اللي فيه فرعه (من الطابور) بيفضل زي ما هو', async () => {
    seen.length = 0;
    const f = branchFetch(base);
    await f('https://x/rest/v1/rpc/record_sale');
    setBranchHeader('b-2');
    await f('https://x/rest/v1/rpc/record_sale', { headers: { 'x-branch-id': 'b-1' } });
    expect(seen.map((s) => s.h)).toEqual([null, 'b-1']);
  });
});
