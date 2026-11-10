import { expect, test } from '@playwright/test';
import { readFileSync, readdirSync } from 'node:fs';
import { prefs, quickIntake, registerShop, uniq, fillAmount } from './helpers';

// البند 11: سجل النشاط بجمل عربي مفهومة برابط، ومفيش أي اسم جدول أو عمود أو إنجليزي في الواجهة العربي
const sql = readdirSync('supabase/migrations').filter((f) => f.endsWith('.sql')).map((f) => readFileSync(`supabase/migrations/${f}`, 'utf8')).join('\n');
const TABLES = [...new Set([...sql.matchAll(/create table (?:if not exists )?public\.(\w+)/g)].map((m) => m[1]))];

test('سجل النشاط: جمل عربي، ورابط بيفتح الجهاز، ومن غير أسماء جداول أو أعمدة أو إنجليزي', async ({ page }, info) => {
  test.setTimeout(180_000);
  await prefs(page, info);
  await registerShop(page, uniq('audit11'), 'محل السجل');
  const dev = await quickIntake(page, `010${String(Date.now()).slice(-8)}`, 'عميل السجل');
  await page.getByRole('button', { name: 'جاري الفحص', exact: true }).click();
  await expect(page.getByText('الحالة اتغيّرت').first()).toBeVisible();
  await page.getByLabel('التكلفة النهائية').fill('700');
  await page.getByRole('button', { name: 'حفظ التكلفة' }).click();
  await expect(page.getByText('اتحفظت التكلفة')).toBeVisible();
  await page.getByRole('button', { name: 'تسجيل دفعة' }).click();
  await fillAmount(page.getByRole('dialog'), '200');
  await page.getByRole('dialog').getByRole('button', { name: 'سجّل' }).click();
  await expect(page.getByText('اتسجلت العملية')).toBeVisible();

  await page.goto('/#/audit');
  const rows = page.getByTestId('audit-row');
  await expect(rows.first()).toBeVisible();
  const sentences = page.getByTestId('audit-sentence');
  await expect(sentences.filter({ hasText: 'غيّر حالة الجهاز' }).first()).toContainText('من «تم الاستلام» لـ «جاري الفحص»');
  await expect(sentences.filter({ hasText: 'أضاف العميل عميل السجل' }).first()).toBeVisible();
  await expect(sentences.filter({ hasText: 'أنشأ المحل' }).first()).toBeVisible();

  // مفيش أي اسم جدول أو عمود أو كلمة إنجليزي (غير IMEI وأسماء الأجهزة اللي المستخدم كتبها)
  const text = await page.locator('main').innerText();
  // مصطلحات فنية مسموحة (IMEI وIC وPOS)، وInstaPay اسم الخدمة (مكتوب كده في البرنامج كله)، وSamsung A35 اللي المستخدم كتبه
  const words = (text.match(/[A-Za-z_]{2,}/g) ?? []).filter((w) => !['IMEI', 'IC', 'POS', 'InstaPay', 'Samsung', 'A35'].includes(w));
  expect(words).toEqual([]);
  for (const tb of TABLES) expect(text, tb).not.toContain(tb);
  expect(text).not.toMatch(/\{|\}|":/); // من غير JSON

  // الرابط بيفتح الجهاز
  await sentences.filter({ hasText: 'غيّر حالة الجهاز' }).first().getByTestId('audit-link').click();
  await expect(page).toHaveURL(new RegExp(dev.replace('/#', '#').replace(/[/]/g, '\\/') + '$'));
});
