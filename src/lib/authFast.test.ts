import { describe, expect, it } from 'vitest';
import { mayHaveSession } from './authFast';

describe('معرفة إن مفيش مستخدم داخل من غير ما نستنى', () => {
  it('مفيش جلسة محفوظة ولا رابط تأكيد: أكيد مش داخل', () => {
    expect(mayHaveSession([], '', '')).toBe(false);
    expect(mayHaveSession(['theme', 'lang', 'bg-still-v2'], '#/', '')).toBe(false);
    expect(mayHaveSession(['theme'], '#/register', '')).toBe(false);
  });
  it('فيه جلسة محفوظة: نستنى Supabase', () => {
    expect(mayHaveSession(['sb-abcd1234-auth-token'], '#/', '')).toBe(true);
    expect(mayHaveSession(['sb-127-auth-token-code-verifier'], '', '')).toBe(true);
  });
  it('راجع من رابط تأكيد الإيميل أو فيه خطأ: نستنى Supabase', () => {
    expect(mayHaveSession([], '#access_token=x&refresh_token=y&type=signup', '')).toBe(true);
    expect(mayHaveSession([], '#error=access_denied&error_code=otp_expired', '')).toBe(true);
    expect(mayHaveSession([], '', '?code=123')).toBe(true);
    expect(mayHaveSession([], '', '?token_hash=abc&type=signup')).toBe(true);
  });
});
