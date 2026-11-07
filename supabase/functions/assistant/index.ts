// المساعد الذكي (Supabase Edge Function، Deno)
//
// - مجاني: Gemini API بمفتاح من Google AI Studio. ممنوع أي خدمة مدفوعة.
// - المفتاح في أسرار Supabase (GEMINI_API_KEY)، مش في الواجهة ولا في .env.local.
// - اختيار الخدمة بإعداد AI_PROVIDER (الافتراضي gemini). التفاصيل في ../_shared/ai.ts.
// - لو مفيش مفتاح: الدالة بترجع E_AI_DISABLED، والواجهة بتقول إن المساعد مقفول.
// - بيتبعت الموديل ووصف العطل بس (متنضّفين). أي بيانات تانية بتتجاهل.
// - لازم المستخدم يكون داخل، والاستخدام بيتسجل بـ ai_take (الحد اليومي من الخطة).
// - السؤال والإجابة ما بيتخزنوش في أي مكان.
//
// النشر: supabase functions deploy assistant
// المفتاح:  supabase secrets set GEMINI_API_KEY=...
import { askProvider, buildUserMessage, pickProvider } from '../_shared/ai.ts';

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};
const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), { status, headers: { ...cors, 'Content-Type': 'application/json' } });
const env = (k: string) => Deno.env.get(k);

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });
  if (req.method !== 'POST') return json({ error: 'E_BAD_INPUT' }, 405);
  const auth = req.headers.get('Authorization') ?? '';
  if (!auth.startsWith('Bearer ')) return json({ error: 'E_AUTH_REQUIRED' }, 401);
  const url = env('SUPABASE_URL')!;
  const anon = env('SUPABASE_ANON_KEY')!;

  let body: { status?: boolean; device?: string; issue?: string };
  try {
    body = await req.json();
  } catch {
    return json({ error: 'E_BAD_INPUT' }, 400);
  }
  const p = pickProvider(env);
  // الواجهة بتسأل الأول: المساعد متفعّل ولا لأ (من غير ما يتحسب من الحد اليومي)
  if (body.status) return json({ enabled: !!p });
  if (!p) return json({ error: 'E_AI_DISABLED' }, 503);

  const user = buildUserMessage(body);
  if (!user) return json({ error: 'E_BAD_INPUT' }, 400);

  // الحد اليومي (وبيتأكد إن المستخدم موظف في محل شغال)
  const take = await fetch(`${url}/rest/v1/rpc/ai_take`, { method: 'POST', headers: { Authorization: auth, apikey: anon, 'Content-Type': 'application/json' }, body: '{}' });
  if (!take.ok) {
    const t = await take.text();
    return json({ error: /E_PLAN_LIMIT/.test(t) ? 'E_PLAN_LIMIT' : /E_FORBIDDEN/.test(t) ? 'E_FORBIDDEN' : 'E_AUTH_REQUIRED' }, take.status === 401 ? 401 : 403);
  }
  const left = ((await take.json()) as { left?: number }).left ?? null;

  const answer = await askProvider(p, env, user);
  if (!answer) return json({ error: 'E_AI_UNAVAILABLE' }, 502);
  return json({ answer, left });
});
