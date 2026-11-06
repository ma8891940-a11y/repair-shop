// المساعد الذكي (Supabase Edge Function، Deno)
//
// - لازم المستخدم يكون داخل (Authorization) وبيتسجل الاستخدام بـ ai_take (الحد اليومي من الخطة).
// - النص بيتنضف تاني هنا (من غير بيانات العميل) حتى لو الواجهة نضّفته.
// - لو مفيش مفتاح ANTHROPIC_API_KEY في أسرار Supabase، الدالة بترجع E_AI_DISABLED، والواجهة بتستخدم دليل الأعطال المدمج (مجاني).
// - السؤال والإجابة ما بيتخزنوش في أي مكان.
//
// النشر: supabase functions deploy assistant
// تفعيل الذكاء (اختياري، بيحتاج اشتراك عند Anthropic): supabase secrets set ANTHROPIC_API_KEY=...
import { scrub } from '../_shared/scrub.ts';

const MODEL = Deno.env.get('ASSISTANT_MODEL') ?? 'claude-haiku-5-5';
const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};
const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), { status, headers: { ...cors, 'Content-Type': 'application/json' } });

const SYSTEM = `إنت مساعد لفني صيانة موبايلات في محل في مصر. ردّك بالعربي المصري، مختصر ومرتب في خطوات:
1) الأسباب المحتملة بالترتيب من الأكتر حدوثًا. 2) خطوات فحص عملية. 3) القطعة أو الحل المقترح. 4) تحذيرات أمان (بطارية، حرارة، كهربا).
المصطلحات الفنية بالإنجليزي عادي (IC, PMIC, Flex). ما تسألش ولا تطلب أي بيانات شخصية عن العميل.`;

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });
  if (req.method !== 'POST') return json({ error: 'E_BAD_INPUT' }, 405);
  const auth = req.headers.get('Authorization') ?? '';
  if (!auth.startsWith('Bearer ')) return json({ error: 'E_AUTH_REQUIRED' }, 401);
  const url = Deno.env.get('SUPABASE_URL')!;
  const anon = Deno.env.get('SUPABASE_ANON_KEY')!;
  const key = Deno.env.get('ANTHROPIC_API_KEY');
  if (!key) return json({ error: 'E_AI_DISABLED' }, 503);

  let body: { device?: string; issue?: string; question?: string };
  try {
    body = await req.json();
  } catch {
    return json({ error: 'E_BAD_INPUT' }, 400);
  }
  const question = scrub(body.question ?? '');
  if (!question) return json({ error: 'E_BAD_INPUT' }, 400);

  // الحد اليومي (وبيتأكد إن المستخدم موظف في محل شغال)
  const take = await fetch(`${url}/rest/v1/rpc/ai_take`, { method: 'POST', headers: { Authorization: auth, apikey: anon, 'Content-Type': 'application/json' }, body: '{}' });
  if (!take.ok) {
    const t = await take.text();
    return json({ error: /E_PLAN_LIMIT/.test(t) ? 'E_PLAN_LIMIT' : /E_FORBIDDEN/.test(t) ? 'E_FORBIDDEN' : 'E_AUTH_REQUIRED' }, take.status === 401 ? 401 : 403);
  }
  const left = ((await take.json()) as { left?: number }).left ?? null;

  const user = `الجهاز: ${scrub(body.device ?? '').slice(0, 80) || 'غير محدد'}\nالعطل: ${scrub(body.issue ?? '').slice(0, 500) || 'غير محدد'}\nالسؤال: ${question}`;
  const r = await fetch('https://api.anthropic.com/v1/messages', {
    method: 'POST',
    headers: { 'x-api-key': key, 'anthropic-version': '2023-06-01', 'content-type': 'application/json' },
    body: JSON.stringify({ model: MODEL, max_tokens: 700, system: SYSTEM, messages: [{ role: 'user', content: user }] }),
  });
  if (!r.ok) return json({ error: 'E_AI_UNAVAILABLE' }, 502);
  const data = (await r.json()) as { content?: { type: string; text?: string }[] };
  const answer = (data.content ?? []).filter((c) => c.type === 'text').map((c) => c.text).join('\n').trim();
  return json({ answer, left });
});
