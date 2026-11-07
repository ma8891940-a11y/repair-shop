/**
 * تنظيف أي نص قبل ما يخرج للمساعد الذكي: من غير بيانات العميل أبدًا.
 * بيشيل: أرقام الموبايل، والـ IMEI وأي رقم طويل، والإيميلات، والروابط، والأسماء اللي اتبعتت صراحة.
 * نفس الكود في supabase/functions/_shared/scrub.ts (فيه اختبار بيتأكد إنهم متطابقين).
 */
export function scrub(text: string, names: string[] = []): string {
  let s = String(text ?? '');
  // الأرقام العربية الأول
  s = s.replace(/[\u0660-\u0669]/g, (d) => String(d.charCodeAt(0) - 0x0660)).replace(/[\u06F0-\u06F9]/g, (d) => String(d.charCodeAt(0) - 0x06f0));
  s = s.replace(/[\w.+-]+@[\w-]+\.[\w.-]+/g, '[email]');
  s = s.replace(/https?:\/\/\S+/g, '[link]');
  // أي رقم طويل (موبايل، IMEI، رقم طلب) حتى لو فيه مسافات أو شرط
  s = s.replace(/\+?\d[\d\s-]{6,}\d/g, '[number]');
  // الاسم كامل الأول، وبعدين كل جزء منه لوحده (الاسم الأول بس ممكن يتكتب في وصف العطل)
  const parts = names.flatMap((n) => {
    const v = n?.trim() ?? '';
    return v.length >= 2 ? [v, ...v.split(/\s+/).filter((w) => w.length >= 3)] : [];
  });
  for (const v of parts.sort((a, b) => b.length - a.length)) s = s.split(v).join('[name]');
  return s.replace(/\s{2,}/g, ' ').trim().slice(0, 1500);
}

/** اللي بيتبعت للمساعد: الموديل ووصف العطل بس (متنضّفين). من غير سؤال حر ولا أي بيانات للعميل */
export function assistantPayload(o: { brand?: string; model?: string; issue?: string; names?: string[] }) {
  const names = o.names ?? [];
  return {
    device: scrub(`${o.brand ?? ''} ${o.model ?? ''}`, names).slice(0, 80),
    issue: scrub(o.issue ?? '', names).slice(0, 500),
  };
}
