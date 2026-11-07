import { describe, expect, it, vi } from 'vitest';
import { askProvider, buildUserMessage, GEMINI_DEFAULT_MODELS, pickProvider, PROVIDERS } from '../../supabase/functions/_shared/ai';

// المساعد: خدمة مجانية (Gemini) والمفتاح على السيرفر بس، ومن غير مفتاح بيبقى مقفول
const envOf = (o: Record<string, string>) => (k: string) => o[k];

describe('اختيار خدمة المساعد', () => {
  it('من غير مفتاح: مقفول', () => {
    expect(pickProvider(envOf({}))).toBeNull();
    expect(pickProvider(envOf({ GEMINI_API_KEY: '  ' }))).toBeNull();
  });
  it('الافتراضي Gemini بمفتاح GEMINI_API_KEY، والاختيار بإعداد AI_PROVIDER', () => {
    expect(pickProvider(envOf({ GEMINI_API_KEY: 'k' }))?.name).toBe('gemini');
    expect(pickProvider(envOf({ AI_PROVIDER: 'Gemini', GEMINI_API_KEY: 'k' }))?.name).toBe('gemini');
    // خدمة مش معروفة: مقفول (مش بيرجع لخدمة تانية من نفسه)
    expect(pickProvider(envOf({ AI_PROVIDER: 'other', GEMINI_API_KEY: 'k' }))).toBeNull();
  });
  it('مفيش أي خدمة مدفوعة في القايمة (Anthropic وOpenAI مرفوضين)', () => {
    expect(Object.keys(PROVIDERS)).toEqual(['gemini']);
    expect(pickProvider(envOf({ AI_PROVIDER: 'anthropic', ANTHROPIC_API_KEY: 'k' }))).toBeNull();
  });
  it('الموديل من GEMINI_MODEL الأول، وبعده الموديلات المجانية الافتراضية', () => {
    expect(PROVIDERS.gemini.models(envOf({}))).toEqual(GEMINI_DEFAULT_MODELS);
    expect(PROVIDERS.gemini.models(envOf({ GEMINI_MODEL: 'gemini-x' }))[0]).toBe('gemini-x');
  });
});

describe('اللي بيخرج للخدمة', () => {
  it('الموديل ووصف العطل بس، ومتنضّفين، وأي حقل تاني بيتجاهل', () => {
    const m = buildUserMessage({ device: 'Samsung A54', issue: 'مش بيشحن، كلّم العميل على 01099998888', question: 'اسمه أحمد', name: 'أحمد', phone: '01099998888' })!;
    expect(m).toContain('Samsung A54');
    expect(m).toContain('مش بيشحن');
    expect(m).not.toContain('01099998888');
    expect(m).not.toContain('أحمد');
    expect(buildUserMessage({ device: 'A54', issue: '' })).toBeNull();
  });
  it('الطلب لـ Gemini: المفتاح في الهيدر مش في الرابط، والإجابة بتتقري صح', () => {
    const { url, init } = PROVIDERS.gemini.request('gemini-flash-latest', 'SECRET', 'sys', 'msg');
    expect(url).toBe('https://generativelanguage.googleapis.com/v1beta/models/gemini-flash-latest:generateContent');
    expect(url).not.toContain('SECRET');
    expect((init.headers as Record<string, string>)['x-goog-api-key']).toBe('SECRET');
    const body = JSON.parse(String(init.body));
    expect(body.systemInstruction.parts[0].text).toBe('sys');
    expect(body.contents[0].parts[0].text).toBe('msg');
    expect(PROVIDERS.gemini.text({ candidates: [{ content: { parts: [{ text: 'أ' }, { text: 'ب' }] } }] })).toBe('أب');
    expect(PROVIDERS.gemini.text({})).toBe('');
  });
  it('لو الموديل اتشال (404) بيجرّب اللي بعده، ولو الخدمة وقعت بيرجع null', async () => {
    const p = pickProvider(envOf({ GEMINI_API_KEY: 'k' }))!;
    const ok = { candidates: [{ content: { parts: [{ text: 'افحص السوكت' }] } }] };
    const f = vi.fn().mockResolvedValueOnce(new Response('', { status: 404 })).mockResolvedValueOnce(new Response(JSON.stringify(ok), { status: 200 }));
    expect(await askProvider(p, envOf({}), 'msg', f as unknown as typeof fetch)).toBe('افحص السوكت');
    expect(f.mock.calls[1][0]).toContain(GEMINI_DEFAULT_MODELS[1]);
    const bad = vi.fn().mockResolvedValue(new Response('', { status: 429 }));
    expect(await askProvider(p, envOf({}), 'msg', bad as unknown as typeof fetch)).toBeNull();
    expect(bad).toHaveBeenCalledTimes(1);
  });
});
