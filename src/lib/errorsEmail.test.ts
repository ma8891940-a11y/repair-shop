import { describe, expect, it } from 'vitest';
import i18n from '../i18n';
import { errorMessage, retryAfterSeconds } from './errors';

// البند 13: سبب واضح لو إرسال الإيميل فشل، والعداد من رد Supabase، ومن غير إنجليزي في الواجهة العربي
describe('أخطاء إرسال الإيميل', () => {
  it('كل سبب بجملة عربي واضحة', async () => {
    await i18n.changeLanguage('ar');
    expect(errorMessage({ message: 'Error sending confirmation email' })).toContain('SMTP');
    expect(errorMessage({ message: 'Error sending confirmation email' })).toContain('Brevo');
    expect(errorMessage({ message: 'email rate limit exceeded' })).toContain('حد Supabase المجاني');
    expect(errorMessage({ message: 'For security purposes, you can only request this after 37 seconds.' })).toBe('استنى 37 ثانية وبعدين جرّب تاني (حماية من الإرسال الكتير).');
    // رسالة إنجليزي مش معروفة: ما تظهرش في الواجهة العربي
    expect(errorMessage({ message: 'Some weird upstream failure xyz' })).not.toMatch(/[A-Za-z]{3,}/);
  });
  it('العداد من رد Supabase', () => {
    expect(retryAfterSeconds({ message: 'For security purposes, you can only request this after 37 seconds.' })).toBe(37);
    expect(retryAfterSeconds('only request this after 1 second')).toBe(1);
    expect(retryAfterSeconds({ message: 'Error sending confirmation email' })).toBeNull();
  });
});
