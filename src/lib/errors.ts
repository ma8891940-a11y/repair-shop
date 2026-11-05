import i18n from '../i18n';

const ARABIC = /[\u0600-\u06FF]/;

/** يحوّل أي خطأ (Supabase/شبكة/قاعدة بيانات) لرسالة مفهومة باللغة الحالية */
export function errorMessage(e: unknown): string {
  const t = i18n.t.bind(i18n);
  const msg =
    typeof e === 'string' ? e : e && typeof e === 'object' && 'message' in e ? String((e as { message: unknown }).message) : '';
  if (/Invalid login credentials/i.test(msg)) return t('errors.badLogin');
  if (/Email not confirmed/i.test(msg)) return t('errors.notConfirmed');
  if (/already registered|already been registered/i.test(msg)) return t('errors.exists');
  if (/Password should be at least/i.test(msg)) return t('errors.weakPassword');
  if (/duplicate key.*customers_phone/i.test(msg)) return t('errors.dupPhone');
  if (/Failed to fetch|NetworkError|network/i.test(msg)) return t('errors.network');
  if (/row-level security|permission denied/i.test(msg)) return t('errors.forbidden');
  if (/rate limit|too many/i.test(msg)) return t('errors.rateLimit');
  if (/IMAGE_PROCESSING_FAILED/.test(msg)) return t('errors.imageFail');
  if (/token has expired|otp|invalid token/i.test(msg)) return t('errors.otp');
  // رسايل قاعدة البيانات لسه بالعربي (هتتحول لأكواد في المرحلة 1)
  if (ARABIC.test(msg)) return i18n.language === 'ar' ? msg : t('errors.generic');
  return msg || t('errors.generic');
}

/** اسم قديم، لسه مستخدم في كام مكان */
export const arabicError = errorMessage;
