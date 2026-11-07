/**
 * خدمة الذكاء الاصطناعي اللي المساعد بيستخدمها (من غير أي خدمة مدفوعة).
 *
 * الاختيار بإعداد واحد في أسرار Supabase:
 *   AI_PROVIDER = gemini   (الافتراضي، ودلوقتي هو الوحيد)
 *   GEMINI_API_KEY = المفتاح المجاني من Google AI Studio
 *   GEMINI_MODEL = (اختياري) اسم الموديل لو عايز تغيّره
 *
 * عشان تضيف خدمة مجانية تانية بعدين: ضيف عنصر في PROVIDERS بنفس الشكل، وغيّر AI_PROVIDER.
 * الملف ده من غير Deno عشان يتختبر بـ Vitest.
 */
import { scrub } from './scrub.ts';

export type Env = (name: string) => string | undefined;

export interface Provider {
  /** اسم الإعداد اللي فيه المفتاح */
  keyName: string;
  /** الموديلات بالترتيب: لو الأول مش موجود (اتشال)، بيجرّب اللي بعده */
  models: (env: Env) => string[];
  request: (model: string, key: string, system: string, user: string) => { url: string; init: RequestInit };
  text: (json: unknown) => string;
}

/** موديلات Gemini المجانية (Flash). الأسماء بتتغيّر مع الوقت، فلو واحد اتشال بيتجرّب اللي بعده */
export const GEMINI_DEFAULT_MODELS = ['gemini-flash-latest', 'gemini-3-flash', 'gemini-2.5-flash'];

export const PROVIDERS: Record<string, Provider> = {
  gemini: {
    keyName: 'GEMINI_API_KEY',
    models: (env) => {
      const own = env('GEMINI_MODEL')?.trim();
      return own ? [own, ...GEMINI_DEFAULT_MODELS.filter((m) => m !== own)] : GEMINI_DEFAULT_MODELS;
    },
    request: (model, key, system, user) => ({
      url: `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(model)}:generateContent`,
      init: {
        method: 'POST',
        // المفتاح في الهيدر، مش في الرابط (عشان ما يتسجلش في أي log)
        headers: { 'x-goog-api-key': key, 'Content-Type': 'application/json' },
        body: JSON.stringify({
          systemInstruction: { parts: [{ text: system }] },
          contents: [{ role: 'user', parts: [{ text: user }] }],
          generationConfig: { maxOutputTokens: 700, temperature: 0.4 },
        }),
      },
    }),
    text: (json) => {
      const c = (json as { candidates?: { content?: { parts?: { text?: string }[] } }[] })?.candidates?.[0];
      return (c?.content?.parts ?? []).map((p) => p.text ?? '').join('').trim();
    },
  },
};

/** الخدمة المختارة ومفتاحها. لو مفيش مفتاح: null (والمساعد بيبقى مقفول) */
export function pickProvider(env: Env): { name: string; provider: Provider; key: string } | null {
  const name = (env('AI_PROVIDER') ?? 'gemini').trim().toLowerCase() || 'gemini';
  const provider = PROVIDERS[name];
  if (!provider) return null;
  const key = env(provider.keyName)?.trim();
  return key ? { name, provider, key } : null;
}

export const SYSTEM = `إنت مساعد لفني صيانة موبايلات في محل في مصر. ردّك بالعربي المصري، مختصر ومرتب في خطوات:
1) الأسباب المحتملة بالترتيب من الأكتر حدوثًا. 2) خطوات فحص عملية. 3) القطعة أو الحل المقترح. 4) تحذيرات أمان (بطارية، حرارة، كهربا).
المصطلحات الفنية بالإنجليزي عادي (IC, PMIC, Flex). ما تسألش ولا تطلب أي بيانات شخصية عن العميل.`;

/**
 * الرسالة اللي بتخرج: الموديل ووصف العطل بس (متنضّفين تاني هنا)، وسؤال ثابت.
 * أي حقل تاني في الطلب (اسم، رقم، سؤال حر...) بيتجاهل.
 */
export function buildUserMessage(body: unknown): string | null {
  const b = (body ?? {}) as { device?: unknown; issue?: unknown };
  const device = scrub(String(b.device ?? '')).slice(0, 80);
  const issue = scrub(String(b.issue ?? '')).slice(0, 500);
  if (!issue) return null;
  return `الجهاز: ${device || 'غير محدد'}\nالعطل: ${issue}\nالمطلوب: الأسباب المحتملة وخطوات الفحص بالترتيب.`;
}

/** بيسأل الخدمة، ولو الموديل مش موجود (404) بيجرّب اللي بعده */
export async function askProvider(p: { provider: Provider; key: string }, env: Env, user: string, doFetch: typeof fetch = fetch): Promise<string | null> {
  for (const model of p.provider.models(env)) {
    const { url, init } = p.provider.request(model, p.key, SYSTEM, user);
    const r = await doFetch(url, init);
    if (r.status === 404) continue;
    if (!r.ok) return null;
    const answer = p.provider.text(await r.json());
    return answer || null;
  }
  return null;
}
