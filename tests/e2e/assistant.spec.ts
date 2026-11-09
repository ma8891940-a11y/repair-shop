import { expect, test } from '@playwright/test';
import { activateInvite, afterSplash, noHorizontalScroll, prefs, registerShop, uniq } from './helpers';

// المساعد الذكي: ليه صفحة في القايمة الجانبية، ومن غير مفتاح (أو من غير الدالة) بيظهر بالسبب وخطوات الحل، مش بيختفي
test('المساعد الذكي: في القايمة، و"محتاج مفتاح" من غير مفتاح، و"مش منشور" من غير الدالة، والدليل المدمج شغال', async ({ page, browser }, info) => {
  test.setTimeout(180_000);
  await prefs(page, info);
  await registerShop(page, uniq('assist'));

  // 1) Supabase المحلي: الدالة منشورة ومن غير GEMINI_API_KEY (نفس حالة صاحب المشروع)
  const link = info.project.name.startsWith('mobile') ? null : page.getByRole('link', { name: 'المساعد الذكي' });
  if (link) await link.click();
  else await page.goto('/#/assistant');
  await expect(page.getByRole('heading', { name: 'المساعد الذكي' })).toBeVisible();
  const note = page.getByTestId('assistant-disabled');
  await expect(note).toHaveAttribute('data-state', 'no-key');
  await expect(note).toContainText('المساعد محتاج مفتاح');
  await expect(note).toContainText('aistudio.google.com');
  await expect(note).toContainText('GEMINI_API_KEY');
  await page.getByTestId('assistant-issue').fill('الشاشة سودا ومفيش صورة');
  await page.getByRole('button', { name: 'دليل الأعطال المدمج' }).click();
  await expect(page.getByTestId('assistant-guide')).toContainText('مشكلة في الشاشة');
  await noHorizontalScroll(page);

  // 2) الدالة مش منشورة (404): رسالة تانية بخطوات النشر
  await page.route('**/functions/v1/assistant', (route) =>
    route.request().method() === 'OPTIONS'
      ? route.fulfill({ status: 200, headers: { 'access-control-allow-origin': '*', 'access-control-allow-headers': '*' } })
      : route.fulfill({ status: 404, contentType: 'application/json', headers: { 'access-control-allow-origin': '*' }, body: '{"code":"NOT_FOUND"}' }),
  );
  await page.reload();
  await afterSplash(page);
  await expect(page.getByTestId('assistant-disabled')).toHaveAttribute('data-state', 'no-function');
  await expect(page.getByTestId('assistant-disabled')).toContainText('functions deploy assistant');

  // 3) الفني بيشوف المساعد برضه، ولو مقفول بيتقاله يكلّم صاحب المحل (من غير خطوات السيرفر)
  await page.unroute('**/functions/v1/assistant');
  await page.goto('/#/users');
  const techEmail = uniq('tech-ai');
  await page.getByLabel('الاسم').fill('فني');
  await page.getByLabel('الإيميل').fill(techEmail);
  await page.getByLabel('الدور').selectOption('technician');
  await page.getByRole('button', { name: 'إرسال الدعوة' }).click();
  await expect(page.getByText('اتعملت الدعوة')).toBeVisible();
  const tech = await activateInvite(browser, info, techEmail);
  await tech.page.goto('/#/assistant');
  await afterSplash(tech.page);
  await expect(tech.page.getByTestId('assistant-disabled')).toContainText('كلّم صاحب المحل');
  await expect(tech.page.getByTestId('assistant-disabled')).not.toContainText('GEMINI_API_KEY');
  await tech.ctx.close();
});
