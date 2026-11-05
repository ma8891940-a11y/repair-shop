/** قوة كلمة السر من 0 (ضعيفة جدًا) لـ 4 (قوية جدًا)، والقواعد اللي اتحققت */
export interface PasswordCheck {
  score: 0 | 1 | 2 | 3 | 4;
  rules: { len: boolean; num: boolean; case: boolean; sym: boolean };
}

export function checkPassword(pw: string): PasswordCheck {
  const rules = {
    len: pw.length >= 8,
    num: /\d/.test(pw),
    case: /[a-z]/.test(pw) && /[A-Z]/.test(pw),
    sym: /[^A-Za-z0-9]/.test(pw),
  };
  let score = Object.values(rules).filter(Boolean).length;
  if (!rules.len) score = Math.min(score, 1);
  if (pw.length >= 14 && score >= 3) score = 4;
  if (pw.length === 0) score = 0;
  return { score: Math.min(4, score) as PasswordCheck['score'], rules };
}

export function isEmail(v: string): boolean {
  return /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(v.trim());
}
