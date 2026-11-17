// تحويل صفوف push_due لرسايل جاهزة للجهاز (بلغة كل جهاز). من غير أي حساب عشري في الفلوس.
// بيتجرّب في src/lib/pushText.test.ts.

export type Locale = 'ar' | 'en';
export interface LocaleTexts {
  kinds: Readonly<Record<string, string>>;
  titles: Readonly<Record<string, string>>;
  summary: string;
  test: string;
  open: string;
  read: string;
}
export type Texts = Readonly<Record<Locale, LocaleTexts>>;

export interface DueRow {
  sub_id: string;
  endpoint: string;
  p256dh: string;
  auth: string;
  locale: string;
  key: string;
  kind: string;
  args: Record<string, unknown> | null;
  link: string | null;
  token: string | null;
}

export interface PushMessage {
  title: string;
  body: string;
  tag: string;
  url: string; // جوه البرنامج (بعد #)
  lang: Locale;
  dir: 'rtl' | 'ltr';
  actions: { action: 'open' | 'read'; title: string }[];
  ack?: { url: string; key: string; token: string };
}

export interface Outgoing {
  sub: { id: string; endpoint: string; p256dh: string; auth: string };
  message: PushMessage;
}

const loc = (l: string): Locale => (l === 'en' ? 'en' : 'ar');

/** المبلغ بالقروش => نص (1,250 أو 1,250.50). القسمة كأعداد صحيحة بس */
export function moneyText(minor: number): string {
  if (!Number.isSafeInteger(minor)) return '';
  const abs = Math.abs(minor);
  const major = Math.floor(abs / 100);
  const rest = abs % 100;
  const body = major.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ',') + (rest ? '.' + String(rest).padStart(2, '0') : '');
  return minor < 0 ? '-' + body : body;
}

/** 2026-11-17 => 17/11/2026 */
export function dateText(iso: string): string {
  const m = /^(\d{4})-(\d{2})-(\d{2})/.exec(iso);
  return m ? `${m[3]}/${m[2]}/${m[1]}` : iso;
}

export function fill(tpl: string, vars: Record<string, unknown>): string {
  return tpl.replace(/\{\{\s*(\w+)\s*\}\}/g, (_, k: string) => (vars[k] == null ? '' : String(vars[k])));
}

function argsText(args: Record<string, unknown> | null): Record<string, unknown> {
  const a = { ...(args ?? {}) };
  if (a.amount != null) a.amount = moneyText(Number(a.amount));
  if (typeof a.due === 'string') a.due = dateText(a.due);
  return a;
}

// الرابط جوه البرنامج بس (مسار بيبدأ بـ /)، عشان الإشعار ما يفتحش أي موقع تاني
const safeLink = (l: string | null) => (l && /^\/[\w\-/]*$/.test(l) ? l : '/');

export function messageFor(texts: Texts, row: DueRow, ack: { url: string; key: string } | null): PushMessage {
  const lang = loc(row.locale);
  const t = texts[lang];
  const canAck = !!(ack && row.token);
  return {
    title: t.titles[row.kind] ?? t.titles.summary,
    body: fill(t.kinds[row.kind] ?? '', argsText(row.args)),
    tag: row.key,
    url: safeLink(row.link),
    lang,
    dir: lang === 'ar' ? 'rtl' : 'ltr',
    actions: [{ action: 'open', title: t.open }, ...(canAck ? [{ action: 'read' as const, title: t.read }] : [])],
    ...(canAck ? { ack: { url: ack!.url, key: ack!.key, token: row.token! } } : {}),
  };
}

/**
 * لكل جهاز: لو الجديد 3 أو أقل، كل إشعار لوحده. لو أكتر، إشعار واحد ملخّص (عشان الجهاز ما يتملاش).
 */
export function planMessages(texts: Texts, rows: DueRow[], ack: { url: string; key: string } | null, max = 3): Outgoing[] {
  const bySub = new Map<string, DueRow[]>();
  for (const r of rows) bySub.set(r.sub_id, [...(bySub.get(r.sub_id) ?? []), r]);
  const out: Outgoing[] = [];
  for (const list of bySub.values()) {
    const s = list[0];
    const sub = { id: s.sub_id, endpoint: s.endpoint, p256dh: s.p256dh, auth: s.auth };
    if (list.length <= max) {
      for (const r of list) out.push({ sub, message: messageFor(texts, r, ack) });
    } else {
      const lang = loc(s.locale);
      const t = texts[lang];
      out.push({
        sub,
        message: { title: t.titles.summary, body: fill(t.summary, { n: list.length }), tag: 'summary', url: '/', lang, dir: lang === 'ar' ? 'rtl' : 'ltr', actions: [{ action: 'open', title: t.open }] },
      });
    }
  }
  return out;
}

export function testMessage(texts: Texts, locale: string): PushMessage {
  const lang = loc(locale);
  const t = texts[lang];
  return { title: t.titles.test, body: t.test, tag: 'test', url: '/settings', lang, dir: lang === 'ar' ? 'rtl' : 'ltr', actions: [{ action: 'open', title: t.open }] };
}
