/**
 * أنواع أسئلة المساعد في البرنامج كله (S3). لكل نوع:
 *   - المكان (area) اللي قاعدة البيانات بتتأكد إنه مفتوح والمستخدم مسموح له (ai_take_area)
 *   - الحقول المسموحة بس (أي حاجة تانية في الطلب بتتجاهل)، وكل نص بيتنضّف تاني هنا (scrub)
 *   - تعليمات ثابتة للموديل، وشكل الرد (نص أو JSON)
 * ممنوع أي بيانات عميل: من غير اسم ولا رقم ولا عنوان. الأرقام المالية مجمّعة بس.
 * الملف ده من غير Deno عشان يتختبر بـ Vitest.
 */
import { scrub } from './scrub.ts';

export const KINDS = ['diagnose', 'intake', 'purchase', 'finance_qa', 'finance_week', 'whatsapp', 'report', 'screen'] as const;
export type Kind = (typeof KINDS)[number];
export type Area = 'tech' | 'intake' | 'inventory' | 'finance' | 'customers' | 'reports' | 'screen';

export const KIND_AREA: Record<Kind, Area> = {
  diagnose: 'tech',
  intake: 'intake',
  purchase: 'inventory',
  finance_qa: 'finance',
  finance_week: 'finance',
  whatsapp: 'customers',
  report: 'reports',
  screen: 'screen',
};

export interface BuiltRequest {
  kind: Kind;
  area: Area;
  system: string;
  user: string;
  json: boolean;
}

const BASE = 'إنت مساعد داخل برنامج إدارة محل صيانة موبايلات في مصر. ردّك بالعربي المصري، مختصر وعملي. ما تسألش ولا تطلب أي بيانات شخصية عن أي عميل، ولو لقيت حاجة شبه بيانات شخصية تجاهلها.';

const txt = (v: unknown, max: number) => scrub(String(v ?? '')).slice(0, max);
/** عدد صحيح بس (القروش والكميات). أي كسر أو نص بيترفض */
const int = (v: unknown): number | null => (typeof v === 'number' && Number.isSafeInteger(v) ? v : null);
/** الفلوس بتتبعت للموديل بالجنيه الصحيح (من غير كسور) */
const pounds = (piasters: number | null) => (piasters == null ? '-' : String(Math.round(piasters / 100)));
const list = <T>(v: unknown, max: number, f: (x: Record<string, unknown>) => T | null): T[] =>
  (Array.isArray(v) ? v : [])
    .slice(0, max)
    .map((x) => (x && typeof x === 'object' ? f(x as Record<string, unknown>) : null))
    .filter((x): x is T => x != null);

/** الأرقام المالية المسموحة (مجمّعة)، بالقروش */
export const FINANCE_KEYS = ['cash', 'receivables', 'payables', 'inventory', 'revenue', 'expenses', 'profit', 'net_worth', 'delivered'] as const;
const numbers = (v: unknown) => {
  const o = (v && typeof v === 'object' ? v : {}) as Record<string, unknown>;
  return FINANCE_KEYS.map((k) => [k, int(o[k])] as const).filter(([, n]) => n != null);
};
const numbersText = (v: unknown) => numbers(v).map(([k, n]) => `${k}: ${k === 'delivered' ? n : pounds(n)}`).join('\n');

export const SCREENS = ['dashboard', 'intake', 'devices', 'device', 'customers', 'finance', 'inventory', 'reports', 'partners', 'settings', 'work', 'other'] as const;

/** الطلب اللي بيخرج للموديل، أو null لو الطلب ناقص أو غلط */
export function buildRequest(body: unknown): BuiltRequest | null {
  const b = (body ?? {}) as Record<string, unknown>;
  const kind = (typeof b.kind === 'string' ? b.kind : 'diagnose') as Kind;
  if (!KINDS.includes(kind)) return null;
  const area = KIND_AREA[kind];
  const out = (system: string, user: string, json = false): BuiltRequest | null => (user.trim() ? { kind, area, system: `${BASE}\n${system}`, user, json } : null);

  switch (kind) {
    case 'diagnose': {
      const issue = txt(b.issue, 500);
      if (!issue) return null;
      return out(
        'المستخدم فني. رتّب ردّك: 1) الأسباب المحتملة من الأكتر حدوثًا 2) خطوات فحص عملية 3) القطعة أو الحل 4) تحذيرات أمان (بطارية، حرارة، كهربا). المصطلحات الفنية بالإنجليزي عادي (IC, PMIC, Flex).',
        `الجهاز: ${txt(b.device, 80) || 'غير محدد'}\nالعطل: ${issue}\nالمطلوب: الأسباب المحتملة وخطوات الفحص بالترتيب.`,
      );
    }
    case 'intake': {
      const device = txt(b.device, 80);
      if (!device) return null;
      const hist = list(b.history, 12, (x) => {
        const issue = txt(x.issue, 120);
        return issue ? `- ${issue} (عدد: ${int(x.count) ?? 1}، متوسط التكلفة: ${pounds(int(x.cost))} جنيه)` : null;
      });
      return out(
        'المستخدم موظف استقبال بيستلم جهاز. اقترح وصف واضح للعطل، وتكلفة تقريبية بالجنيه (أعداد صحيحة) من تاريخ المحل لو موجود، وأسئلة قصيرة يسألها للعميل. رد JSON بس بالشكل: {"issue": "...", "cost_min": 0, "cost_max": 0, "questions": ["..."]}',
        `الجهاز: ${device}\nكلام العميل: ${txt(b.issue, 300) || 'مش مكتوب'}\nأعطال نفس الموديل في المحل قبل كده:\n${hist.join('\n') || 'مفيش'}`,
        true,
      );
    }
    case 'purchase': {
      const items = list(b.items, 40, (x) => {
        const name = txt(x.name, 60);
        const qty = int(x.qty);
        return name && qty != null ? `- ${name}: الموجود ${qty}، الحد الأدنى ${int(x.min) ?? 0}، اتباع آخر 30 يوم ${int(x.sold30) ?? 0}، متوسط التكلفة ${pounds(int(x.cost))} جنيه` : null;
      });
      if (!items.length) return null;
      return out(
        'المستخدم صاحب المحل وعايز يعرف يشتري إيه. اختار من الأصناف اللي في القايمة بس (بنفس الاسم بالظبط)، وكمية بعدد صحيح، وسبب قصير. رد JSON بس بالشكل: {"lines": [{"name": "...", "qty": 1, "why": "..."}], "note": "..."}',
        `الأصناف:\n${items.join('\n')}`,
        true,
      );
    }
    case 'finance_qa': {
      const q = txt(b.question, 300);
      const n = numbersText(b.numbers);
      if (!q || !n) return null;
      return out('المستخدم صاحب المحل. جاوب سؤاله من الأرقام دي بس (مبالغ مجمّعة بالجنيه للفترة). لو الأرقام مش كفاية قول كده. ما تخترعش أرقام.', `الفترة: ${txt(b.period, 40)}\nالأرقام:\n${n}\nالسؤال: ${q}`);
    }
    case 'finance_week': {
      const now = numbersText(b.numbers);
      if (!now) return null;
      return out('اكتب لصاحب المحل ملخص أسبوعي قصير (5 سطور بالكتير): إيه اللي اتحسن، وإيه اللي محتاج انتباه، ونصيحة عملية واحدة. من الأرقام دي بس.', `الأسبوع ده:\n${now}\nالأسبوع اللي قبله:\n${numbersText(b.previous) || 'مش متاح'}`);
    }
    case 'whatsapp': {
      const purpose = txt(b.purpose, 30);
      if (!purpose) return null;
      return out(
        'اكتب مسودة رسالة واتساب قصيرة ومحترمة من المحل للعميل. ممنوع تكتب أي اسم أو رقم: استخدم المتغيرات دي بس زي ما هي بين الأقواس: {name} {order} {device} {status} {cost} {link} {shop} {days} {balance} {eta}. رد بنص الرسالة بس.',
        `الغرض: ${purpose}\nالحالة: ${txt(b.device_status, 30) || '-'}\nالأسلوب: ${txt(b.tone, 30) || 'ودود'}\nملاحظة: ${txt(b.note, 200) || '-'}`,
      );
    }
    case 'report': {
      const title = txt(b.title, 60);
      const rows = list(b.rows, 30, (x) => {
        const label = txt(x.label, 60);
        const vals = list(x.values, 8, (v) => {
          const k = txt(v.k, 30);
          const n = int(v.n);
          return k && n != null ? `${k}: ${v.money ? pounds(n) : n}` : null;
        });
        return label && vals.length ? `- ${label}: ${vals.join('، ')}` : null;
      });
      if (!title || !rows.length) return null;
      return out('اكتب لصاحب المحل ملخص مكتوب قصير للتقرير ده: أهم 3 ملاحظات، وحاجة واحدة يعملها. الأسماء متشفّرة (فني 1، فني 2) سيبها زي ما هي.', `التقرير: ${title}\nالفترة: ${txt(b.period, 40)}\n${rows.join('\n')}`);
    }
    case 'screen': {
      const screen = (SCREENS as readonly string[]).includes(String(b.screen)) ? String(b.screen) : 'other';
      const q = txt(b.question, 300);
      if (!q) return null;
      const ctx = list(b.context, 10, (x) => {
        const k = txt(x.k, 30);
        const n = int(x.n);
        return k && n != null ? `${k}: ${n}` : null;
      });
      return out('المستخدم جوه شاشة في البرنامج وعنده سؤال. اشرحله يعمل إيه خطوة بخطوة في البرنامج، ولو السؤال فني عن صيانة جاوبه باختصار.', `الشاشة: ${screen}\nأرقام الشاشة: ${ctx.join('، ') || '-'}\nالسؤال: ${q}`);
    }
  }
}

/** رد JSON من الموديل (ساعات بيلفّه في ```json): بيرجع object أو null */
export function parseJsonAnswer(text: string): Record<string, unknown> | null {
  const m = /\{[\s\S]*\}/.exec(text.replace(/```(?:json)?/g, ''));
  if (!m) return null;
  try {
    const v = JSON.parse(m[0]);
    return v && typeof v === 'object' && !Array.isArray(v) ? (v as Record<string, unknown>) : null;
  } catch {
    return null;
  }
}
