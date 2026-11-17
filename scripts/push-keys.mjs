// مفاتيح إشعارات الجهاز (VAPID) + سر الجدولة. بتتعمل مرة واحدة بس على جهاز صاحب المشروع.
// الاستخدام: npm run push:keys
// النتيجة بتتحط في أسرار Supabase (Edge Functions ← Secrets) أو بـ supabase secrets set، ومش في .env.local ولا في الكود.
// المفتاح الخاص سر: ما تبعتهوش لحد، وما تحطوش في أي ملف في المستودع.
import { webcrypto } from 'node:crypto';

const b64url = (b) => Buffer.from(b).toString('base64url');

export async function makePushKeys() {
  const kp = await webcrypto.subtle.generateKey({ name: 'ECDSA', namedCurve: 'P-256' }, true, ['sign', 'verify']);
  const pub = new Uint8Array(await webcrypto.subtle.exportKey('raw', kp.publicKey));
  const jwk = await webcrypto.subtle.exportKey('jwk', kp.privateKey);
  return { VAPID_PUBLIC_KEY: b64url(pub), VAPID_PRIVATE_KEY: jwk.d, PUSH_CRON_SECRET: b64url(webcrypto.getRandomValues(new Uint8Array(24))) };
}

if (import.meta.url === `file://${process.argv[1]}`) {
  const k = await makePushKeys();
  console.log('# حط دول في Supabase: Edge Functions ← Secrets (أو supabase secrets set ...)');
  console.log('# وزوّد VAPID_SUBJECT=mailto:<إيميلك>');
  for (const [n, v] of Object.entries(k)) console.log(`${n}=${v}`);
}
