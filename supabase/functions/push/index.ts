// إشعارات على الجهاز (Web Push) — Supabase Edge Function (Deno)
//
// - مجاني: خدمات الإشعارات بتاعة المتصفحات مجانية. التشفير والتوقيع بـ Web Crypto (../_shared/webpush.ts) من غير أي مكتبة.
// - مفاتيح VAPID في أسرار Supabase بس: VAPID_PUBLIC_KEY و VAPID_PRIVATE_KEY و VAPID_SUBJECT (mailto:...).
//   بتتعمل مرة واحدة بـ: npm run push:keys
// - مفتاح السيرفر (service_role) موجود تلقائي جوه الدالة بس، وما بيطلعش برّه أبدًا.
//
// الطلبات:
// - GET: المفتاح العام (الواجهة محتاجاه عشان تشترك). لو مفيش مفاتيح: E_PUSH_DISABLED.
// - POST {"test": true} بتوكن المستخدم: إشعار تجربة لأجهزته هو بس.
// - POST {} بالهيدر x-cron-secret = PUSH_CRON_SECRET: بيبعت الإشعارات الجديدة لكل الأجهزة (كل ساعة من Supabase Cron).
//   كل إشعار بيتبعت مرة واحدة بس، وفي الوقت اللي صاحب المحل محدده بس (push_due في قاعدة البيانات).
//
// النشر: supabase functions deploy push --no-verify-jwt
import { sendPush, type VapidKeys } from '../_shared/webpush.ts';
import { planMessages, testMessage, type DueRow } from '../_shared/pushText.ts';
import { TEXTS } from './texts.ts';

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
};
const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), { status, headers: { ...cors, 'Content-Type': 'application/json' } });
const env = (k: string) => Deno.env.get(k) ?? '';

function vapid(): VapidKeys | null {
  const k = { publicKey: env('VAPID_PUBLIC_KEY'), privateKey: env('VAPID_PRIVATE_KEY'), subject: env('VAPID_SUBJECT') };
  return k.publicKey && k.privateKey && /^(mailto:|https:\/\/)/.test(k.subject) ? k : null;
}

// مقارنة من غير تسريب بالتوقيت
function same(a: string, b: string): boolean {
  if (!a || !b || a.length !== b.length) return false;
  let x = 0;
  for (let i = 0; i < a.length; i++) x |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return x === 0;
}

async function rest(path: string, init: RequestInit & { auth: string }): Promise<Response> {
  return fetch(`${env('SUPABASE_URL')}${path}`, {
    ...init,
    headers: { apikey: env('SUPABASE_ANON_KEY'), Authorization: init.auth, 'Content-Type': 'application/json', ...(init.headers ?? {}) },
  });
}

// بيبعت بالتوازي (10 في نفس الوقت بالكتير)
async function sendAll(items: { sub: { id: string; endpoint: string; p256dh: string; auth: string }; message: unknown }[], keys: VapidKeys) {
  const results: { sub_id: string; status: number; gone: boolean }[] = [];
  let i = 0;
  async function worker() {
    while (i < items.length) {
      const it = items[i++];
      try {
        const r = await sendPush(it.sub, it.message, keys);
        results.push({ sub_id: it.sub.id, ...r });
      } catch {
        results.push({ sub_id: it.sub.id, status: 0, gone: false });
      }
    }
  }
  await Promise.all(Array.from({ length: Math.min(10, items.length) }, worker));
  return results;
}

async function report(results: { sub_id: string; status: number; gone: boolean }[]) {
  if (!results.length) return;
  await rest('/rest/v1/rpc/push_result', { method: 'POST', auth: `Bearer ${env('SUPABASE_SERVICE_ROLE_KEY')}`, body: JSON.stringify({ p_rows: results }) });
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });
  const keys = vapid();
  if (req.method === 'GET') return keys ? json({ publicKey: keys.publicKey }) : json({ error: 'E_PUSH_DISABLED' }, 503);
  if (req.method !== 'POST') return json({ error: 'E_BAD_INPUT' }, 405);
  if (!keys) return json({ error: 'E_PUSH_DISABLED' }, 503);

  let body: { test?: boolean } = {};
  try {
    body = await req.json();
  } catch {
    body = {};
  }

  // إشعار تجربة: لأجهزة المستخدم نفسه بس (RLS: كل واحد يشوف اشتراكاته بس)
  if (body.test === true) {
    const auth = req.headers.get('Authorization') ?? '';
    if (!auth.startsWith('Bearer ')) return json({ error: 'E_AUTH_REQUIRED' }, 401);
    const r = await rest('/rest/v1/push_subscriptions?select=id,endpoint,p256dh,auth,locale&deleted_at=is.null', { method: 'GET', auth });
    if (!r.ok) return json({ error: 'E_AUTH_REQUIRED' }, 401);
    const subs = (await r.json()) as { id: string; endpoint: string; p256dh: string; auth: string; locale: string }[];
    const results = await sendAll(subs.map((s) => ({ sub: s, message: testMessage(TEXTS, s.locale) })), keys);
    await report(results);
    return json({ sent: results.filter((x) => x.status >= 200 && x.status < 300).length, devices: subs.length });
  }

  // الإرسال الدوري: بسر الجدولة بس
  if (!same(req.headers.get('x-cron-secret') ?? '', env('PUSH_CRON_SECRET'))) return json({ error: 'E_FORBIDDEN' }, 403);
  const service = `Bearer ${env('SUPABASE_SERVICE_ROLE_KEY')}`;
  const r = await rest('/rest/v1/rpc/push_due', { method: 'POST', auth: service, body: '{}' });
  if (!r.ok) return json({ error: 'E_PUSH_DB' }, 502);
  const rows = (await r.json()) as DueRow[];
  // زرار "اتقرا" في الإشعار: بيكلّم push_ack بالمفتاح العام (anon) والـ token بتاع الإشعار ده بس
  const ack = { url: `${env('SUPABASE_URL')}/rest/v1/rpc/push_ack`, key: env('SUPABASE_ANON_KEY') };
  const results = await sendAll(planMessages(TEXTS, rows, ack), keys);
  await report(results);
  return json({ sent: results.filter((x) => x.status >= 200 && x.status < 300).length, gone: results.filter((x) => x.gone).length });
});
