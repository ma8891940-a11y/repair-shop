import { expect, test, type Page } from '@playwright/test';
import { activateInvite, prefs, quickIntake, registerShop, uniq, fillAmount } from './helpers';
import { dataRows, readXlsx } from './xlsxRead';

// S4: التصدير Excel (xlsx حقيقي) وPDF بنفس الفلتر والترتيب اللي على الشاشة
async function downloadXlsx(page: Page, testid: string) {
  await page.getByTestId(testid).click();
  const [dl] = await Promise.all([page.waitForEvent('download'), page.getByTestId(`${testid}-xlsx`).click()]);
  expect(dl.suggestedFilename()).toMatch(/^[a-z-]+-\d{4}-\d{2}-\d{2}\.xlsx$/);
  return readXlsx((await dl.path())!);
}

test('التصدير: الأجهزة والعملاء وكشف الحساب بنفس اللي على الشاشة، من اليمين للشمال، وأرقام كأرقام، وإجمالي، وPDF بلوجو المحل', async ({ page, browser }, info) => {
  test.setTimeout(240_000);
  await prefs(page, info);
  await registerShop(page, uniq('export'), 'محل التصدير');
  const p1 = `010${String(Date.now()).slice(-8)}`;
  const p2 = `011${String(Date.now() + 7).slice(-8)}`;
  const d1 = await quickIntake(page, p1, 'عميل أول');
  await page.getByLabel('التكلفة النهائية').fill('1,250.50');
  await page.getByRole('button', { name: 'حفظ التكلفة' }).click();
  await expect(page.getByText('اتحفظت التكلفة')).toBeVisible();
  await page.getByRole('button', { name: 'تسجيل دفعة' }).click();
  await fillAmount(page.getByRole('dialog'), '1,000.25');
  await page.getByRole('dialog').getByRole('button', { name: 'سجّل' }).click();
  await expect(page.getByText('اتسجلت العملية')).toBeVisible();
  // الجهاز الأول دخل الفحص (عشان فلتر الحالة على الشاشة يفرّق بينهم)
  await page.getByRole('button', { name: 'جاري الفحص', exact: true }).click();
  await expect(page.getByText('الحالة اتغيّرت').first()).toBeVisible();
  await quickIntake(page, p2, 'عميل تاني');

  // 1) الأجهزة: كل الأجهزة بنفس ترتيب الشاشة (الأحدث الأول)
  await page.goto('/#/devices');
  const orders = async () => (await page.locator('a[href*="#/devices/"]').filter({ visible: true }).allInnerTexts()).map((x) => x.trim().split('\n')[0].trim()).filter((x) => /\d/.test(x));
  await expect.poll(async () => (await orders()).length).toBe(2);
  const screen = await orders();
  let x = await downloadXlsx(page, 'devices-export');
  expect(x.rtl).toBe(true);
  expect(x.rows[0][0]).toBe('الأجهزة');
  expect(x.rows[1][0]).toBe('محل التصدير');
  let d = dataRows(x, 'رقم الطلب');
  expect(d.head).toContain('العميل');
  expect(d.rows.map((r) => r[0])).toEqual(screen);
  expect(d.rows[0]).toContain('عميل تاني');
  expect(d.rows[0]).toContain(p2);
  // فلتر الحالة (على الشاشة): الملف فيه الجهاز اللي ظاهر بس، والفلتر مكتوب فوق
  await page.getByRole('tab', { name: /جاري الفحص/ }).click();
  await expect.poll(async () => (await orders()).length).toBe(1);
  x = await downloadXlsx(page, 'devices-export');
  d = dataRows(x, 'رقم الطلب');
  expect(d.rows.map((r) => r[0])).toEqual(await orders());
  expect(d.rows[0]).toContain('عميل أول');
  expect(x.rows.some((r) => String(r[0] ?? '') === 'الفلتر: جاري الفحص')).toBe(true);
  await page.getByRole('tab', { name: /الكل/ }).click();
  await expect.poll(async () => (await orders()).length).toBe(2);
  // البحث: سطر واحد بس، والفلتر مكتوب فوق
  await page.getByRole('textbox', { name: 'بحث', exact: true }).fill('عميل أول');
  await expect.poll(async () => (await orders()).length).toBe(1);
  x = await downloadXlsx(page, 'devices-export');
  d = dataRows(x, 'رقم الطلب');
  expect(d.rows).toHaveLength(1);
  expect(d.rows[0]).toContain('عميل أول');
  expect(x.rows.some((r) => String(r[0] ?? '').includes('عميل أول') && String(r[0]).startsWith('البحث'))).toBe(true);

  // 2) العملاء: المدفوع رقم (مش نص)، وسطر الإجمالي بمعادلة SUM
  await page.goto('/#/customers');
  await expect(page.getByText('عميل تاني').first()).toBeVisible();
  x = await downloadXlsx(page, 'customers-export');
  d = dataRows(x, 'العميل');
  expect(d.rows).toHaveLength(2);
  const spent = d.head.indexOf('المدفوع');
  const devs = d.head.indexOf('الأجهزة');
  expect(d.rows.every((r) => typeof r[spent] === 'number')).toBe(true);
  expect(d.total?.[devs]).toBe(2);
  expect(x.formulas.some((f) => f.startsWith('SUM('))).toBe(true);

  // 3) كشف حساب الخزنة: المبلغ بالجنيه رقم بالقروش بالظبط، والإجمالي = مجموع الحركات، والـ PDF بنفس السطور
  await page.goto('/#/finance');
  await page.getByTestId('cashbox-card').filter({ hasText: 'كاش الدرج' }).click();
  await expect(page.getByTestId('move-row').first()).toBeVisible();
  const moves = await page.getByTestId('move-row').count();
  x = await downloadXlsx(page, 'statement-export');
  d = dataRows(x, 'رقم القيد');
  const amount = d.head.indexOf('المبلغ');
  expect(d.rows).toHaveLength(moves);
  expect(d.rows.map((r) => r[amount])).toContain(1000.25);
  expect(d.total?.[amount]).toBe(1000.25);
  await page.getByTestId('statement-export').click();
  await page.getByTestId('statement-export-pdf').click();
  await expect(page).toHaveURL(/#\/print\/table/);
  const tp = page.getByTestId('table-print');
  await expect(tp.locator('tbody tr')).toHaveCount(moves);
  await expect(page.getByText('محل التصدير').first()).toBeVisible();
  await expect(page.getByText(/الفترة:/).first()).toBeVisible();
  await expect(page.getByText(/تاريخ الطباعة:/).first()).toBeVisible();
  await expect(page.getByTestId('table-print-total')).toContainText('1,000.25');

  // 4) الفني: تصدير الأجهزة من غير اسم العميل ولا تليفونه
  await page.goto('/#/users');
  const em = uniq('tech-exp');
  await page.getByLabel('الاسم').fill('فني التصدير');
  await page.getByLabel('الإيميل').fill(em);
  await page.getByLabel('الدور').selectOption('technician');
  await page.getByRole('button', { name: 'إرسال الدعوة' }).click();
  await expect(page.getByText('اتعملت الدعوة')).toBeVisible();
  const T = await activateInvite(browser, info, em);
  await T.page.goto('/#/devices');
  await expect.poll(async () => (await T.page.locator('a[href*="#/devices/"]').filter({ visible: true }).count())).toBeGreaterThan(1);
  const tx = await downloadXlsx(T.page, 'devices-export');
  const td = dataRows(tx, 'رقم الطلب');
  expect(td.head).not.toContain('العميل');
  expect(JSON.stringify(tx.rows)).not.toContain('عميل أول');
  expect(JSON.stringify(tx.rows)).not.toContain(p1);
  await T.ctx.close();
  void d1;
});
