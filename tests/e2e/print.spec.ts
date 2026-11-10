import { expect, test } from '@playwright/test';
import { afterSplash, prefs, registerShop, uniq, fillAmount } from './helpers';

// S5 الطباعة: الإعدادات لكل خطوة، والاستيكر الحراري فيه كل البيانات بالـ 3 مقاسات، وإيصال A4، وفاتورة التسليم
test('الطباعة: الافتراضي صح، والاستيكر كامل بكل مقاس، والطباعة التلقائية بالترتيب، وفاتورة التسليم فيها المدفوع والفاضل والضمان', async ({ page }, info) => {
  test.setTimeout(240_000);
  await prefs(page, info);
  await page.addInitScript(() => {
    window.print = () => undefined;
  });
  await registerShop(page, uniq('print'), 'محل الطباعة');

  // 1) الإعدادات ← الطباعة: الافتراضي (استيكر + ورقي في الاستلام، وورقي في التسليم، ومن غير تلقائي)
  await page.goto('/#/settings?tab=print');
  const box = (name: string) => page.getByTestId('print-settings').getByRole('checkbox', { name });
  await expect(box('استيكر حراري يتلزق على الجهاز')).toHaveAttribute('data-state', 'checked');
  await expect(box('إيصال استلام ورقي (A4)')).toHaveAttribute('data-state', 'checked');
  await expect(box('إيصال استلام حراري (80مم)')).toHaveAttribute('data-state', 'unchecked');
  await expect(box('فاتورة تسليم ورقية (A4)')).toHaveAttribute('data-state', 'checked');
  await expect(box('اطبع تلقائي بعد الاستلام')).toHaveAttribute('data-state', 'unchecked');
  await expect(page.getByTestId('sticker-size')).toHaveValue('80');
  await box('اطبع تلقائي بعد الاستلام').click();
  await expect(box('اطبع تلقائي بعد الاستلام')).toHaveAttribute('data-state', 'checked');

  // 2) الاستلام بتقدير 500: الحفظ بيفتح الاستيكر الأول، وبعده إيصال A4
  const phone = `010${String(Date.now()).slice(-8)}`;
  await page.goto('/#/intake');
  await page.locator('#intake-phone').fill(phone);
  await page.getByLabel('اسم العميل').fill('عميل الطباعة');
  await page.getByRole('button', { name: 'Samsung', exact: true }).click();
  await page.getByLabel('الموديل').fill('A35');
  await page.getByLabel('العطل زي ما العميل وصفه').fill('شاشة مكسورة');
  await page.getByLabel('التكلفة التقديرية').fill('500');
  await page.getByRole('button', { name: 'حفظ الاستلام' }).click();
  await expect(page).toHaveURL(/#\/print\/sticker\/.*next=receipt-a4/);
  const st = page.getByTestId('print-sticker');
  await expect(st).toHaveAttribute('data-size', '80');
  await expect(st.getByTestId('sticker-order')).not.toBeEmpty();
  await expect(st.getByTestId('sticker-customer')).toHaveText('عميل الطباعة');
  await expect(st.getByTestId('sticker-phone')).toHaveText(phone);
  await expect(st.getByTestId('sticker-issue')).toContainText('شاشة مكسورة');
  await expect(st.getByTestId('sticker-issue')).toContainText('A35');
  await expect(st.getByTestId('sticker-total')).toContainText('500');
  await expect(st.getByTestId('sticker-paid')).toContainText('0');
  await expect(st.getByTestId('sticker-due')).toContainText('500');
  await expect(st.getByTestId('sticker-date')).not.toBeEmpty();
  await expect(st.locator('img')).toHaveCount(1); // QR صغير
  const stickerUrl = page.url().replace(/^.*#/, '/#').split('?')[0];
  const id = stickerUrl.split('/').pop()!;

  await page.getByTestId('print-next').click();
  await expect(page).toHaveURL(new RegExp(`#/print/receipt-a4/${id}`));
  const a4 = page.getByTestId('print-receipt-a4');
  await expect(a4).toBeVisible();
  await expect(a4.getByTestId('shop-name-big').or(a4.locator('img[alt="محل الطباعة"]')).first()).toBeVisible();
  await expect(a4).toContainText('شاشة مكسورة');
  await expect(a4.getByTestId('print-terms')).toBeVisible();

  // 3) المقاسين التانيين: نفس البيانات كلها
  for (const size of ['50x30', '58x40']) {
    await page.goto(`${stickerUrl}?size=${size}`);
    await afterSplash(page);
    const s = page.getByTestId('print-sticker');
    await expect(s).toHaveAttribute('data-size', size);
    for (const k of ['order', 'customer', 'phone', 'issue', 'total', 'paid', 'due', 'date']) await expect(s.getByTestId(`sticker-${k}`)).toBeVisible();
    await expect(s.getByTestId('sticker-customer')).toHaveText('عميل الطباعة');
  }

  // 4) الجهاز: دفعة 200 ← الاستيكر بيقول مدفوع 200 وفاضل 300
  await page.goto(`/#/devices/${id}`);
  await afterSplash(page);
  await page.getByLabel('التكلفة النهائية').fill('500');
  await page.getByRole('button', { name: 'حفظ التكلفة' }).click();
  await expect(page.getByText('اتحفظت التكلفة')).toBeVisible();
  await page.getByRole('button', { name: 'تسجيل دفعة' }).click();
  await fillAmount(page.getByRole('dialog'), '200');
  await page.getByRole('dialog').getByRole('button', { name: 'سجّل' }).click();
  await expect(page.getByText('اتسجلت العملية')).toBeVisible();
  await page.getByTestId('print-sticker-link').click();
  await expect(page.getByTestId('sticker-paid')).toContainText('200');
  await expect(page.getByTestId('sticker-due')).toContainText('300');

  // 5) الباقي ← التسليم ← "فاتورة التسليم" فيها الإصلاح والمبلغ والمدفوع والفاضل والضمان
  await page.goto(`/#/devices/${id}`);
  await afterSplash(page);
  await page.getByRole('button', { name: 'تسجيل دفعة' }).click();
  await fillAmount(page.getByRole('dialog'), '300');
  await page.getByRole('dialog').getByRole('button', { name: 'سجّل' }).click();
  await expect(page.getByText('اتسجلت العملية').first()).toBeVisible();
  for (const s of ['جاري الفحص', 'جاري الصيانة', 'تم الإصلاح', 'جاهز للاستلام']) {
    await page.getByRole('button', { name: s, exact: true }).click();
    await expect(page.getByRole('button', { name: s, exact: true })).toHaveCount(0);
  }
  await page.getByRole('button', { name: 'تم التسليم', exact: true }).click();
  await page.getByRole('button', { name: 'تأكيد' }).click();
  await expect(page.getByText('اتسلّم الجهاز. اطبع فاتورة التسليم؟')).toBeVisible();
  await page.getByRole('button', { name: 'فاتورة التسليم' }).click();
  await expect(page).toHaveURL(new RegExp(`#/print/invoice/${id}`));
  const inv = page.getByTestId('print-invoice');
  await expect(inv).toContainText('شاشة مكسورة');
  await expect(inv.getByTestId('invoice-paid')).toContainText('500');
  await expect(inv.getByTestId('invoice-due')).toContainText('0');
  await expect(inv).toContainText('الضمان');
});

test('الطباعة: التلقائي مقفول ← مفيش تحويل، وفيه زرار لكل مستند، ومن غير استيكر بيطبع الورقي بس', async ({ page }, info) => {
  test.setTimeout(180_000);
  await prefs(page, info);
  await page.addInitScript(() => {
    window.print = () => undefined;
  });
  await registerShop(page, uniq('print2'), 'محل الطباعة 2');
  await page.goto('/#/settings?tab=print');
  await page.getByTestId('print-settings').getByRole('checkbox', { name: 'استيكر حراري يتلزق على الجهاز' }).click();
  await expect(page.getByText('اتحفظ').first()).toBeVisible();
  await page.goto('/#/intake');
  await page.locator('#intake-phone').fill(`011${String(Date.now()).slice(-8)}`);
  await page.getByLabel('اسم العميل').fill('عميل');
  await page.getByRole('button', { name: 'Samsung', exact: true }).click();
  await page.getByLabel('الموديل').fill('A15');
  await page.getByLabel('العطل زي ما العميل وصفه').fill('شحن');
  await page.getByRole('button', { name: 'حفظ الاستلام' }).click();
  await expect(page.getByText('اتسجّل الجهاز')).toBeVisible();
  await expect(page).toHaveURL(/#\/intake/);
  await expect(page.getByTestId('intake-print-sticker')).toHaveCount(0);
  await page.getByTestId('intake-print-receipt-a4').click();
  await expect(page.getByTestId('print-receipt-a4')).toBeVisible();
});
