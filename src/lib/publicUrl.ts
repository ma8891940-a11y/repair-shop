/**
 * البند 12: "رابط البرنامج العام" (اللي العميل بيفتح منه صفحة التتبع). بيتحفظ في الإعدادات (shops.extras.public_url).
 * من غيره البرنامج بيستخدم العنوان اللي مفتوح دلوقتي، ولو ده localhost أو شبكة داخلية أو من غير https،
 * العميل مش هيقدر يفتح الرابط من موبايله، فبيظهر تنبيه.
 */
export type UrlProblem = 'bad' | 'notHttps' | 'local' | null;

const LOCAL = /^(localhost|127\.\d+\.\d+\.\d+|0\.0\.0\.0|\[?::1\]?|10\.\d+\.\d+\.\d+|192\.168\.\d+\.\d+|172\.(1[6-9]|2\d|3[01])\.\d+\.\d+|[^.]+\.local|[^.]+)$/i;

export function urlProblem(u: string): UrlProblem {
  let url: URL;
  try {
    url = new URL(u.trim());
  } catch {
    return 'bad';
  }
  if (url.protocol !== 'https:' && url.protocol !== 'http:') return 'bad';
  if (LOCAL.test(url.hostname)) return 'local';
  if (url.protocol !== 'https:') return 'notHttps';
  return null;
}

/** الرابط بعد التنضيف: من غير #... ومن غير / في الآخر */
export function cleanBase(u: string): string {
  return u.trim().replace(/#.*$/, '').replace(/[?].*$/, '').replace(/\/+$/, '');
}

export function readPublicUrl(extras: unknown): string {
  const v = extras && typeof extras === 'object' ? (extras as Record<string, unknown>).public_url : null;
  return typeof v === 'string' && urlProblem(v) === null ? cleanBase(v) : '';
}

/** القاعدة اللي بتتبني منها روابط التتبع: الرابط العام لو متسجل، وإلا العنوان الحالي */
export function appBase(extras: unknown, current: string): string {
  return readPublicUrl(extras) || cleanBase(current);
}
