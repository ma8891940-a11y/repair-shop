/**
 * هل ممكن يكون فيه مستخدم داخل؟ (من غير ما نستنى Supabase)
 * لو مفيش جلسة محفوظة على الجهاز، والرابط مش راجع من إيميل تأكيد، يبقى أكيد مش داخل،
 * فشاشة الدخول بتترسم من أول لحظة بدل ما تستنى (فرق واضح في الافتتاحية على الأجهزة الضعيفة).
 * في أي شك: بنستنى Supabase زي الأول.
 */
export function mayHaveSession(storageKeys: string[], hash: string, search: string): boolean {
  // جلسة Supabase المحفوظة (sb-<project>-auth-token) أو خطوة تسجيل لسه ما خلصتش
  if (storageKeys.some((k) => /^sb-.+-auth-token/.test(k))) return true;
  // راجع من رابط تأكيد الإيميل أو رابط فيه كود أو خطأ
  if (/access_token=|refresh_token=|error=|error_code=|type=|token_hash=/.test(hash)) return true;
  if (/[?&](code|token_hash|error)=/.test(search)) return true;
  return false;
}

/** نفس الكلام من المتصفح نفسه (ولو الوصول للتخزين فشل: بنعتبر إن ممكن يكون فيه جلسة) */
export function mayHaveSessionNow(): boolean {
  try {
    const keys: string[] = [];
    for (let i = 0; i < localStorage.length; i++) keys.push(localStorage.key(i) ?? '');
    return mayHaveSession(keys, window.location.hash, window.location.search);
  } catch {
    return true;
  }
}
