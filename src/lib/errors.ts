// تحويل رسائل الأخطاء التقنية لكلام مفهوم بالعربي
export function arabicError(e: unknown): string {
  const msg =
    typeof e === 'string'
      ? e
      : e && typeof e === 'object' && 'message' in e
        ? String((e as { message: unknown }).message)
        : 'حصل خطأ غير متوقع';
  if (/[؀-ۿ]/.test(msg)) return msg; // رسالة عربية جاية من قاعدة البيانات
  if (/Invalid login credentials/i.test(msg)) return 'الإيميل أو كلمة السر غلط';
  if (/Email not confirmed/i.test(msg)) return 'لازم تأكّد الإيميل الأول من الرسالة اللي وصلتك';
  if (/User already registered/i.test(msg)) return 'الإيميل ده عنده حساب بالفعل. سجّل دخول';
  if (/Password should be at least/i.test(msg)) return 'كلمة السر لازم تكون 6 حروف على الأقل';
  if (/duplicate key.*customers_phone/i.test(msg)) return 'فيه عميل متسجّل بنفس الرقم';
  if (/Failed to fetch|NetworkError|network/i.test(msg)) return 'مفيش اتصال بالإنترنت أو السيرفر مش متاح';
  if (/row-level security|permission denied/i.test(msg)) return 'مش مسموح لك تعمل العملية دي';
  if (/rate limit/i.test(msg)) return 'محاولات كتير. استنى شوية وجرّب تاني';
  return msg;
}
