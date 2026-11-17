// Web Push من غير أي مكتبة: بـ Web Crypto بس (موجودة في Deno والمتصفح وNode).
//
// - التشفير: RFC 8291 (aes128gcm، RFC 8188) — الرسالة بتتشفّر لجهاز المستخدم بس،
//   وخدمة الإشعارات بتاعة المتصفح (Google/Mozilla/Apple) ما تقدرش تقراها.
// - الهوية: VAPID (RFC 8292) — توقيع ES256 بمفتاح المحل الخاص (في أسرار Supabase بس).
// - مجاني: خدمات الإشعارات بتاعة المتصفحات مجانية، ومفيش أي خدمة مدفوعة.
//
// الملف ده بيتجرّب في src/lib/webpush.test.ts (مقارنة بمثال الـ RFC ومكتبة http_ece المرجعية).

export interface PushSubscriptionKeys {
  endpoint: string;
  p256dh: string; // المفتاح العام بتاع الجهاز (base64url، 65 بايت)
  auth: string; // السر المشترك (base64url، 16 بايت)
}

export interface VapidKeys {
  publicKey: string; // base64url، 65 بايت (0x04 || x || y)
  privateKey: string; // base64url، 32 بايت (d)
  subject: string; // mailto:... أو https://...
}

const enc = new TextEncoder();

export function b64urlEncode(bytes: Uint8Array): string {
  let s = '';
  for (const b of bytes) s += String.fromCharCode(b);
  return btoa(s).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

export function b64urlDecode(s: string): Uint8Array {
  const t = s.replace(/-/g, '+').replace(/_/g, '/');
  const bin = atob(t + '='.repeat((4 - (t.length % 4)) % 4));
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}

function concat(...parts: Uint8Array[]): Uint8Array {
  const out = new Uint8Array(parts.reduce((n, p) => n + p.length, 0));
  let o = 0;
  for (const p of parts) {
    out.set(p, o);
    o += p.length;
  }
  return out;
}

// TS 5.7+: Uint8Array<ArrayBufferLike> مش مقبول كـ BufferSource في بعض الأماكن
const buf = (u: Uint8Array): ArrayBuffer => u.slice().buffer as ArrayBuffer;

async function hmac(key: Uint8Array, data: Uint8Array): Promise<Uint8Array> {
  const k = await crypto.subtle.importKey('raw', buf(key), { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']);
  return new Uint8Array(await crypto.subtle.sign('HMAC', k, buf(data)));
}

// HKDF (RFC 5869) بخطوتين، بطول أقل من 32 بايت
async function hkdf(salt: Uint8Array, ikm: Uint8Array, info: Uint8Array, len: number): Promise<Uint8Array> {
  const prk = await hmac(salt, ikm);
  return (await hmac(prk, concat(info, new Uint8Array([1])))).slice(0, len);
}

function publicJwk(raw: Uint8Array): JsonWebKey {
  if (raw.length !== 65 || raw[0] !== 4) throw new Error('E_PUSH_KEY');
  return { kty: 'EC', crv: 'P-256', x: b64urlEncode(raw.slice(1, 33)), y: b64urlEncode(raw.slice(33, 65)), ext: true };
}

/**
 * تشفير الرسالة لجهاز واحد (RFC 8291). salt والمفتاح المؤقت بيتعملوا عشوائي،
 * والاختبار بس هو اللي بيبعتهم ثابتين عشان يقارن بمثال الـ RFC.
 */
export async function encryptPayload(
  sub: Pick<PushSubscriptionKeys, 'p256dh' | 'auth'>,
  plaintext: Uint8Array,
  fixed?: { salt: Uint8Array; asPrivate: string; asPublic: string },
): Promise<Uint8Array> {
  const uaPublic = b64urlDecode(sub.p256dh);
  const authSecret = b64urlDecode(sub.auth);
  if (authSecret.length < 16) throw new Error('E_PUSH_KEY');
  if (plaintext.length > 3992) throw new Error('E_PUSH_TOO_BIG');
  const salt = fixed?.salt ?? crypto.getRandomValues(new Uint8Array(16));

  // المفتاح المؤقت بتاع السيرفر (جديد لكل رسالة)
  let asPriv: CryptoKey;
  let asPublic: Uint8Array;
  if (fixed) {
    asPublic = b64urlDecode(fixed.asPublic);
    asPriv = await crypto.subtle.importKey('jwk', { ...publicJwk(asPublic), d: fixed.asPrivate }, { name: 'ECDH', namedCurve: 'P-256' }, false, ['deriveBits']);
  } else {
    const kp = (await crypto.subtle.generateKey({ name: 'ECDH', namedCurve: 'P-256' }, true, ['deriveBits'])) as CryptoKeyPair;
    asPriv = kp.privateKey;
    asPublic = new Uint8Array(await crypto.subtle.exportKey('raw', kp.publicKey));
  }
  const uaKey = await crypto.subtle.importKey('jwk', publicJwk(uaPublic), { name: 'ECDH', namedCurve: 'P-256' }, false, []);
  const shared = new Uint8Array(await crypto.subtle.deriveBits({ name: 'ECDH', public: uaKey }, asPriv, 256));

  // RFC 8291 §3.4
  const ikm = await hkdf(authSecret, shared, concat(enc.encode('WebPush: info\0'), uaPublic, asPublic), 32);
  const cek = await hkdf(salt, ikm, enc.encode('Content-Encoding: aes128gcm\0'), 16);
  const nonce = await hkdf(salt, ikm, enc.encode('Content-Encoding: nonce\0'), 12);

  // سجل واحد: الرسالة + 0x02 (آخر سجل)
  const key = await crypto.subtle.importKey('raw', buf(cek), 'AES-GCM', false, ['encrypt']);
  const cipher = new Uint8Array(await crypto.subtle.encrypt({ name: 'AES-GCM', iv: buf(nonce) }, key, buf(concat(plaintext, new Uint8Array([2])))));

  // الرأس (RFC 8188 §2.1): salt (16) + rs (4) + idlen (1) + keyid (المفتاح العام المؤقت)
  const rs = new Uint8Array([0, 0, 16, 0]); // 4096
  return concat(salt, rs, new Uint8Array([asPublic.length]), asPublic, cipher);
}

/** توقيع VAPID: JWT بـ ES256، صالح 12 ساعة (الحد الأقصى 24) */
export async function vapidAuthorization(endpoint: string, keys: VapidKeys, nowSec = Math.floor(Date.now() / 1000)): Promise<string> {
  const pub = b64urlDecode(keys.publicKey);
  const priv = await crypto.subtle.importKey('jwk', { ...publicJwk(pub), d: keys.privateKey }, { name: 'ECDSA', namedCurve: 'P-256' }, false, ['sign']);
  const header = b64urlEncode(enc.encode(JSON.stringify({ typ: 'JWT', alg: 'ES256' })));
  const claims = b64urlEncode(enc.encode(JSON.stringify({ aud: new URL(endpoint).origin, exp: nowSec + 12 * 3600, sub: keys.subject })));
  const unsigned = `${header}.${claims}`;
  // Web Crypto بيرجّع التوقيع r||s (64 بايت) زي ما JWT محتاج بالظبط
  const sig = new Uint8Array(await crypto.subtle.sign({ name: 'ECDSA', hash: 'SHA-256' }, priv, buf(enc.encode(unsigned))));
  return `vapid t=${unsigned}.${b64urlEncode(sig)}, k=${keys.publicKey}`;
}

/** العنوان لازم يكون https، ومن غير عناوين داخلية (حماية من SSRF) */
export function safeEndpoint(endpoint: string): boolean {
  let u: URL;
  try {
    u = new URL(endpoint);
  } catch {
    return false;
  }
  if (u.protocol !== 'https:' || u.username || u.password || (u.port && u.port !== '443')) return false;
  const h = u.hostname.toLowerCase();
  if (h === 'localhost' || h.endsWith('.local') || h.endsWith('.internal') || !h.includes('.')) return false;
  // أرقام IP مباشرة (v4 أو v6) ممنوعة: خدمات الإشعارات الحقيقية دايمًا باسم
  if (/^[\d.]+$/.test(h) || h.startsWith('[')) return false;
  return true;
}

export interface SendResult {
  status: number; // 0 = ما اتبعتش أصلًا
  gone: boolean; // الجهاز لغى الاشتراك (404/410): يتشال
}

/** بعت رسالة واحدة لجهاز واحد */
export async function sendPush(
  sub: PushSubscriptionKeys,
  payload: unknown,
  keys: VapidKeys,
  opts: { ttl?: number; urgency?: 'very-low' | 'low' | 'normal' | 'high'; fetcher?: typeof fetch } = {},
): Promise<SendResult> {
  if (!safeEndpoint(sub.endpoint)) return { status: 0, gone: true };
  const body = await encryptPayload(sub, enc.encode(JSON.stringify(payload)));
  const res = await (opts.fetcher ?? fetch)(sub.endpoint, {
    method: 'POST',
    headers: {
      Authorization: await vapidAuthorization(sub.endpoint, keys),
      'Content-Encoding': 'aes128gcm',
      'Content-Type': 'application/octet-stream',
      TTL: String(opts.ttl ?? 24 * 3600),
      Urgency: opts.urgency ?? 'normal',
    },
    body: buf(body),
    redirect: 'manual',
  });
  return { status: res.status, gone: res.status === 404 || res.status === 410 };
}
