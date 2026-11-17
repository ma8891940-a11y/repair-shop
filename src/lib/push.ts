import { supabase } from './supabase';

/**
 * إشعارات على الجهاز (Web Push) من ناحية الواجهة:
 * - المفتاح العام بييجي من Edge Function اسمها push (مفيش أي مفتاح في الواجهة).
 * - الاشتراك (endpoint + مفاتيح الجهاز العامة) بيتحفظ في قاعدة البيانات لصاحبه بس.
 * - عند الخروج: الاشتراك بيتشال، عشان اللي يدخل بعده على نفس الجهاز ما يوصلوش إشعارات حد تاني.
 */

export type PushState = 'unsupported' | 'denied' | 'off' | 'on';

export function pushSupported(): boolean {
  return typeof window !== 'undefined' && 'serviceWorker' in navigator && 'PushManager' in window && 'Notification' in window;
}

export function b64urlToBytes(s: string): Uint8Array<ArrayBuffer> {
  const t = s.replace(/-/g, '+').replace(/_/g, '/');
  const bin = atob(t + '='.repeat((4 - (t.length % 4)) % 4));
  const out = new Uint8Array(new ArrayBuffer(bin.length));
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}

export function bytesToB64url(b: ArrayBuffer | null): string {
  if (!b) return '';
  let s = '';
  for (const x of new Uint8Array(b)) s += String.fromCharCode(x);
  return btoa(s).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

/** الـ service worker لو موجود (في وضع التطوير مش موجود)، من غير ما نستنى للأبد */
async function registration(): Promise<ServiceWorkerRegistration | null> {
  if (!pushSupported()) return null;
  const r = await navigator.serviceWorker.getRegistration().catch(() => undefined);
  if (!r) return null;
  if (r.active) return r;
  return Promise.race([navigator.serviceWorker.ready, new Promise<null>((res) => setTimeout(() => res(null), 4000))]);
}

export async function currentSubscription(): Promise<PushSubscription | null> {
  const r = await registration();
  return r ? r.pushManager.getSubscription().catch(() => null) : null;
}

export async function pushState(): Promise<PushState> {
  if (!pushSupported()) return 'unsupported';
  if (Notification.permission === 'denied') return 'denied';
  return (await currentSubscription()) ? 'on' : 'off';
}

/** المفتاح العام من السيرفر، أو null لو صاحب المشروع لسه ما جهّزش المفاتيح */
export async function serverKey(): Promise<string | null> {
  const { data, error } = await supabase.functions.invoke('push', { method: 'GET' });
  const k = !error && data && typeof data === 'object' ? (data as { publicKey?: unknown }).publicKey : null;
  return typeof k === 'string' && /^[A-Za-z0-9_-]{80,100}$/.test(k) ? k : null;
}

export type EnableResult = 'on' | 'unsupported' | 'denied' | 'not_configured';

export async function enablePush(locale: string): Promise<EnableResult> {
  if (!pushSupported()) return 'unsupported';
  const reg = await registration();
  if (!reg) return 'unsupported';
  const key = await serverKey();
  if (!key) return 'not_configured';
  if ((await Notification.requestPermission()) !== 'granted') return 'denied';
  let sub = await reg.pushManager.getSubscription();
  // اتغيّر مفتاح السيرفر: اشتراك جديد
  const old = sub?.options.applicationServerKey ? bytesToB64url(sub.options.applicationServerKey) : null;
  if (sub && old !== key) {
    await sub.unsubscribe().catch(() => undefined);
    sub = null;
  }
  sub ??= await reg.pushManager.subscribe({ userVisibleOnly: true, applicationServerKey: b64urlToBytes(key) });
  const { error } = await supabase.rpc('save_push_subscription', {
    p_endpoint: sub.endpoint,
    p_p256dh: bytesToB64url(sub.getKey('p256dh')),
    p_auth: bytesToB64url(sub.getKey('auth')),
    p_locale: locale === 'en' ? 'en' : 'ar',
    p_user_agent: navigator.userAgent.slice(0, 300),
  });
  if (error) throw error;
  return 'on';
}

export async function disablePush(): Promise<void> {
  const sub = await currentSubscription();
  if (!sub) return;
  await supabase.rpc('remove_push_subscription', { p_endpoint: sub.endpoint }).then(
    () => undefined,
    () => undefined,
  );
  await sub.unsubscribe().catch(() => undefined);
}

export async function sendTestPush(): Promise<{ sent: number; devices: number }> {
  const { data, error } = await supabase.functions.invoke('push', { body: { test: true } });
  if (error) throw error;
  const d = (data ?? {}) as { sent?: number; devices?: number };
  return { sent: Number(d.sent ?? 0), devices: Number(d.devices ?? 0) };
}
