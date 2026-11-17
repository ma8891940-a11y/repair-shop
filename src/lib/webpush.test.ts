// Web Push من غير مكتبة (supabase/functions/_shared/webpush.ts): مقارنة بمثال RFC 8291 بالحرف، وتوقيع VAPID، وحماية العنوان
import { describe, expect, it } from 'vitest';
import { b64urlDecode, b64urlEncode, encryptPayload, safeEndpoint, sendPush, vapidAuthorization } from '../../supabase/functions/_shared/webpush';

// RFC 8291 Appendix A (نفس النتيجة اتأكدت كمان بمكتبة http_ece المرجعية)
const RFC = {
  plaintext: 'When I grow up, I want to be a watermelon',
  asPrivate: 'yfWPiYE-n46HLnH0KqZOF1fJJU3MYrct3AELtAQ-oRw',
  asPublic: 'BP4z9KsN6nGRTbVYI_c7VJSPQTBtkgcy27mlmlMoZIIgDll6e3vCYLocInmYWAmS6TlzAC8wEqKK6PBru3jl7A8',
  uaPublic: 'BCVxsr7N_eNgVRqvHtD0zTZsEc6-VV-JvLexhqUzORcxaOzi6-AYWXvTBHm4bjyPjs7Vd8pZGH6SRpkNtoIAiw4',
  uaPrivate: 'q1dXpw3UpT5VOmu_cf_v6ih07Aems3njxI-JWgLcM94',
  auth: 'BTBZMqHH6r4Tts7J_aSIgg',
  salt: 'DGv6ra1nlYgDCS1FRnbzlw',
  body: 'DGv6ra1nlYgDCS1FRnbzlwAAEABBBP4z9KsN6nGRTbVYI_c7VJSPQTBtkgcy27mlmlMoZIIgDll6e3vCYLocInmYWAmS6TlzAC8wEqKK6PBru3jl7A_yl95bQpu6cVPTpK4Mqgkf1CXztLVBSt2Ks3oZwbuwXPXLWyouBWLVWGNWQexSgSxsj_Qulcy4a-fN',
};
const enc = new TextEncoder();
// Web Crypto في TS محتاج ArrayBuffer صريح
const raw = (u: Uint8Array) => u.slice().buffer as ArrayBuffer;

async function newVapid() {
  const kp = (await crypto.subtle.generateKey({ name: 'ECDSA', namedCurve: 'P-256' }, true, ['sign', 'verify'])) as CryptoKeyPair;
  const pub = new Uint8Array(await crypto.subtle.exportKey('raw', kp.publicKey));
  const jwk = await crypto.subtle.exportKey('jwk', kp.privateKey);
  return { keys: { publicKey: b64urlEncode(pub), privateKey: jwk.d!, subject: 'mailto:owner@example.com' }, verifyKey: kp.publicKey };
}

describe('Web Push: التشفير (RFC 8291)', () => {
  it('نفس نتيجة مثال الـ RFC بالحرف', async () => {
    const out = await encryptPayload({ p256dh: RFC.uaPublic, auth: RFC.auth }, enc.encode(RFC.plaintext), { salt: b64urlDecode(RFC.salt), asPrivate: RFC.asPrivate, asPublic: RFC.asPublic });
    expect(b64urlEncode(out)).toBe(RFC.body);
  });

  it('الجهاز بس اللي يقدر يفكّها (بمفتاحه الخاص)، وكل رسالة شكلها مختلف', async () => {
    const msg = enc.encode(JSON.stringify({ title: 'قسط متأخر', body: 'عميل: 1,250' }));
    const a = await encryptPayload({ p256dh: RFC.uaPublic, auth: RFC.auth }, msg);
    const b = await encryptPayload({ p256dh: RFC.uaPublic, auth: RFC.auth }, msg);
    expect(b64urlEncode(a)).not.toBe(b64urlEncode(b));
    // فك التشفير من ناحية الجهاز (RFC 8291 §3.4) بمفتاح الجهاز في مثال الـ RFC
    const salt = a.slice(0, 16);
    const asPub = a.slice(21, 21 + a[20]);
    const uaPub = b64urlDecode(RFC.uaPublic);
    const uaPriv = await crypto.subtle.importKey('jwk', { kty: 'EC', crv: 'P-256', x: b64urlEncode(uaPub.slice(1, 33)), y: b64urlEncode(uaPub.slice(33)), d: RFC.uaPrivate }, { name: 'ECDH', namedCurve: 'P-256' }, false, ['deriveBits']);
    const asKey = await crypto.subtle.importKey('raw', asPub, { name: 'ECDH', namedCurve: 'P-256' }, false, []);
    const shared = new Uint8Array(await crypto.subtle.deriveBits({ name: 'ECDH', public: asKey }, uaPriv, 256));
    const ab = (u: Uint8Array) => u.slice().buffer as ArrayBuffer;
    const hmac = async (k: Uint8Array, d: Uint8Array) => new Uint8Array(await crypto.subtle.sign('HMAC', await crypto.subtle.importKey('raw', ab(k), { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']), ab(d)));
    const hk = async (s: Uint8Array, ikm: Uint8Array, info: Uint8Array, n: number) => (await hmac(await hmac(s, ikm), new Uint8Array([...info, 1]))).slice(0, n);
    const ikm = await hk(b64urlDecode(RFC.auth), shared, new Uint8Array([...enc.encode('WebPush: info\0'), ...uaPub, ...asPub]), 32);
    const cek = await hk(salt, ikm, enc.encode('Content-Encoding: aes128gcm\0'), 16);
    const nonce = await hk(salt, ikm, enc.encode('Content-Encoding: nonce\0'), 12);
    const key = await crypto.subtle.importKey('raw', cek, 'AES-GCM', false, ['decrypt']);
    const plain = new Uint8Array(await crypto.subtle.decrypt({ name: 'AES-GCM', iv: nonce }, key, a.slice(21 + a[20])));
    expect(plain[plain.length - 1]).toBe(2);
    expect(JSON.parse(new TextDecoder().decode(plain.slice(0, -1)))).toEqual({ title: 'قسط متأخر', body: 'عميل: 1,250' });
  });

  it('مفاتيح غلط أو رسالة كبيرة: بترفض', async () => {
    await expect(encryptPayload({ p256dh: 'AAAA', auth: RFC.auth }, enc.encode('x'))).rejects.toThrow(/E_PUSH_KEY/);
    await expect(encryptPayload({ p256dh: RFC.uaPublic, auth: 'AAAA' }, enc.encode('x'))).rejects.toThrow(/E_PUSH_KEY/);
    await expect(encryptPayload({ p256dh: RFC.uaPublic, auth: RFC.auth }, new Uint8Array(4000))).rejects.toThrow(/E_PUSH_TOO_BIG/);
  });
});

describe('Web Push: VAPID والإرسال', () => {
  it('التوقيع ES256 صحيح بالمفتاح العام، والـ aud هو أصل خدمة الإشعارات، والمدة 12 ساعة', async () => {
    const { keys, verifyKey } = await newVapid();
    const h = await vapidAuthorization('https://fcm.googleapis.com/fcm/send/abc', keys, 1_000_000);
    const m = /^vapid t=([^.]+)\.([^.]+)\.([^,]+), k=(.+)$/.exec(h)!;
    expect(m[4]).toBe(keys.publicKey);
    const claims = JSON.parse(new TextDecoder().decode(b64urlDecode(m[2])));
    expect(claims).toEqual({ aud: 'https://fcm.googleapis.com', exp: 1_000_000 + 12 * 3600, sub: 'mailto:owner@example.com' });
    const ok = await crypto.subtle.verify({ name: 'ECDSA', hash: 'SHA-256' }, verifyKey, raw(b64urlDecode(m[3])), enc.encode(`${m[1]}.${m[2]}`));
    expect(ok).toBe(true);
  });

  it('العنوان: https لخدمة حقيقية بس (مفيش عناوين داخلية)', () => {
    expect(safeEndpoint('https://fcm.googleapis.com/fcm/send/x')).toBe(true);
    expect(safeEndpoint('https://web.push.apple.com/abc')).toBe(true);
    for (const bad of ['http://fcm.googleapis.com/x', 'https://localhost/x', 'https://127.0.0.1/x', 'https://[::1]/x', 'https://kong:8000/x', 'https://db.internal/x', 'https://a:b@push.example.com/x', 'https://push.example.com:8443/x', 'not a url']) {
      expect(safeEndpoint(bad), bad).toBe(false);
    }
  });

  it('الإرسال: الهيدرز الصح، و410 معناه الجهاز اتشال، والعنوان الداخلي ما بيتبعتلوش أصلًا', async () => {
    const { keys } = await newVapid();
    const calls: { url: string; init: RequestInit }[] = [];
    const fetcher = (async (url: string, init: RequestInit) => {
      calls.push({ url, init });
      return new Response(null, { status: url.endsWith('gone') ? 410 : 201 });
    }) as unknown as typeof fetch;
    const sub = { endpoint: 'https://push.example.com/ok', p256dh: RFC.uaPublic, auth: RFC.auth };
    expect(await sendPush(sub, { title: 'x' }, keys, { fetcher })).toEqual({ status: 201, gone: false });
    const hd = calls[0].init.headers as Record<string, string>;
    expect(hd['Content-Encoding']).toBe('aes128gcm');
    expect(hd.TTL).toBe('86400');
    expect(hd.Authorization).toMatch(/^vapid t=.+, k=/);
    expect(calls[0].init.redirect).toBe('manual');
    expect(await sendPush({ ...sub, endpoint: 'https://push.example.com/gone' }, {}, keys, { fetcher })).toEqual({ status: 410, gone: true });
    expect(await sendPush({ ...sub, endpoint: 'https://localhost/x' }, {}, keys, { fetcher })).toEqual({ status: 0, gone: true });
    expect(calls).toHaveLength(2);
  });
});

describe('npm run push:keys', () => {
  it('بيعمل مفاتيح VAPID صالحة (التوقيع بيتأكد بالمفتاح العام) وسر جدولة عشوائي', async () => {
    // @ts-expect-error سكريبت JS من غير أنواع
    const { makePushKeys } = await import('../../scripts/push-keys.mjs');
    const k = await makePushKeys();
    expect(b64urlDecode(k.VAPID_PUBLIC_KEY)).toHaveLength(65);
    expect(b64urlDecode(k.VAPID_PRIVATE_KEY)).toHaveLength(32);
    expect(k.PUSH_CRON_SECRET).toMatch(/^[A-Za-z0-9_-]{32}$/);
    expect((await makePushKeys()).PUSH_CRON_SECRET).not.toBe(k.PUSH_CRON_SECRET);
    const h = await vapidAuthorization('https://push.example.com/x', { publicKey: k.VAPID_PUBLIC_KEY, privateKey: k.VAPID_PRIVATE_KEY, subject: 'mailto:a@b.c' });
    const [, t] = /^vapid t=(\S+), k=/.exec(h)!;
    const [hd, cl, sig] = t.split('.');
    const pub = await crypto.subtle.importKey('raw', raw(b64urlDecode(k.VAPID_PUBLIC_KEY)), { name: 'ECDSA', namedCurve: 'P-256' }, false, ['verify']);
    expect(await crypto.subtle.verify({ name: 'ECDSA', hash: 'SHA-256' }, pub, raw(b64urlDecode(sig)), enc.encode(`${hd}.${cl}`))).toBe(true);
  });
});
