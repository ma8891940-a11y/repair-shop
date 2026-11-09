import i18n from '../i18n';

const ARABIC = /[\u0600-\u06FF]/;

/** يحوّل أي خطأ (Supabase/شبكة/قاعدة بيانات) لرسالة مفهومة باللغة الحالية */
export function errorMessage(e: unknown): string {
  const t = i18n.t.bind(i18n);
  const msg =
    typeof e === 'string' ? e : e && typeof e === 'object' && 'message' in e ? String((e as { message: unknown }).message) : '';
  // أكواد قاعدة البيانات (E_XXX) بتتترجم للغة الحالية
  const code = /\b(E_[A-Z_]+)\b/.exec(msg)?.[1];
  if (code && i18n.exists(`errors.db.${code}`)) return t(`errors.db.${code}`);
  if (/Invalid login credentials/i.test(msg)) return t('errors.badLogin');
  if (/Email not confirmed/i.test(msg)) return t('errors.notConfirmed');
  if (/already registered|already been registered/i.test(msg)) return t('errors.exists');
  if (/Password should be at least/i.test(msg)) return t('errors.weakPassword');
  if (/duplicate key.*customers_phone/i.test(msg)) return t('errors.dupPhone');
  if (/Failed to fetch|NetworkError|network/i.test(msg)) return t('errors.network');
  if (/row-level security|permission denied/i.test(msg)) return t('errors.forbidden');
  // البند 13: إرسال الإيميل (الكود أو رابط التأكيد) فشل: السبب بوضوح
  const wait = retryAfterSeconds(msg);
  if (wait != null) return t('errors.waitSeconds', { s: wait });
  if (/email rate limit|over_email_send_rate_limit/i.test(msg)) return t('errors.emailRate');
  if (/error sending|sending (confirmation|recovery|magic|invite)|smtp|unexpected_failure.*mail|mail.*(failed|error)/i.test(msg)) return t('errors.emailSend');
  if (/rate limit|too many/i.test(msg)) return t('errors.rateLimit');
  if (/IMAGE_PROCESSING_FAILED/.test(msg)) return t('errors.imageFail');
  if (/token has expired|otp|invalid token/i.test(msg)) return t('errors.otp');
  if (ARABIC.test(msg)) return i18n.language === 'ar' ? msg : t('errors.generic');
  // رسالة إنجليزي مش معروفة: ما تظهرش في الواجهة العربي (البند 11)، وبتتسجل في الـ console للمطوّر
  if (msg && i18n.language === 'ar') {
    console.warn('unmapped error:', msg);
    return t('errors.generic');
  }
  return msg || t('errors.generic');
}

/** "For security purposes, you can only request this after 37 seconds." ← 37 */
export function retryAfterSeconds(e: unknown): number | null {
  const msg = typeof e === 'string' ? e : e && typeof e === 'object' && 'message' in e ? String((e as { message: unknown }).message) : '';
  const m = /after (\d+) seconds?/i.exec(msg);
  return m ? Math.min(Number(m[1]), 3600) : null;
}

