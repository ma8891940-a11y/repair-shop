import { expect, test, type Page } from '@playwright/test';
import { afterSplash, fillAmount, prefs, registerShop, uniq } from './helpers';

// S5 (تعديل صاحب المشروع): استيكر صغير وبسيط بمقاسات، و"طباعة وإرسال" في شاشة الاستلام نفسها وصفحة الجهاز
const PRESETS = ['30x20', '38x25', '40x30', '50x25', '50x30', '58x40', '60x40'];

/** كل سطر في الاستيكر جوه حدوده (من غير ما يطلع بره)، والمحتوى كله داخل في الارتفاع */
async function fitsInside(page: Page, testid: string) {
  return page.getByTestId(testid).first().evaluate((el) => {
    const box = el.getBoundingClientRect();
    // السطور نفسها (مش الأجزاء اللي جوه سطر الفلوس، دي بتتقص بـ "..." جوه السطر)
    const lines = [...el.children] as HTMLElement[];
    const out = lines
      .filter((c) => {
        const r = c.getBoundingClientRect();
        return !(r.top >= box.top - 0.5 && r.bottom <= box.bottom + 0.5 && r.left >= box.left - 0.5 && r.right <= box.right + 0.5);
      })
      .map((c) => `${c.dataset.testid}:${Math.round(c.getBoundingClientRect().bottom - box.bottom)}`);
    return { inside: out.length === 0, out: out.join(','), fitsHeight: el.scrollHeight <= el.clientHeight + 1, sh: el.scrollHeight, ch: el.clientHeight, lines: lines.length };
  });
}

test('الاستيكر: المقاسات السبعة كل البيانات جوه حدوده، والمقاس باليد والإطار والإزاحة والنسخ بيتحفظوا', async ({ page }, info) => {
  test.setTimeout(180_000);
  await prefs(page, info);
  await page.addInitScript(() => {
    window.print = () => undefined;
  });
  await registerShop(page, uniq('stk'), 'محل الاستيكر');
  await page.goto('/#/settings?tab=print');
  const ps = page.getByTestId('print-settings');
  // الافتراضي: 40×30، ومفيش حاجة تلقائي
  await expect(ps.getByTestId('preset-40x30')).toHaveAttribute('aria-pressed', 'true');
  for (const a of ['طباعة حرارية (إيصال الاستلام)', 'طباعة ورقية (إيصال A4)', 'استيكر الجهاز', 'ملصق QR للتتبع', 'إرسال واتساب للعميل']) {
    await expect(ps.getByRole('checkbox', { name: a })).toHaveAttribute('data-state', 'unchecked');
  }
  await expect(ps).toContainText('الهوامش None');
  // المعاينة الحية: كل مقاس، والبيانات كلها جوه
  for (const p of PRESETS) {
    await ps.getByTestId(`preset-${p}`).click();
    await expect(ps.getByTestId('preview-sticker')).toHaveAttribute('data-size', p);
    const r = await fitsInside(page, 'preview-sticker');
    expect(r, p).toMatchObject({ inside: true, fitsHeight: true, lines: 6 });
  }
  // المقاس باليد، والإطار، والإزاحة، والنسخ ← بعد إعادة التحميل زي ما هي
  await ps.getByTestId('sticker-w').fill('45');
  await ps.getByTestId('sticker-h').fill('28');
  await ps.getByRole('button', { name: 'احفظ المقاس' }).click();
  await expect(ps.getByTestId('preview-sticker')).toHaveAttribute('data-size', '45x28');
  await ps.getByRole('checkbox', { name: 'طباعة الإطار حوالين الاستيكر' }).click();
  // كل تغيير بيتحفظ على السيرفر بالترتيب: نستنى الحفظ اللي فيه القيمة الجديدة يوصل (مش وقت ثابت ولا أي حفظ)
  const saved = (has: string) =>
    page.waitForResponse((r) => r.url().includes('/rest/v1/shops') && r.request().method() === 'PATCH' && (r.request().postData() ?? '').includes(has) && r.ok());
  let done = saved('"dx":1.5');
  await ps.getByTestId('sticker-dx').fill('1.5');
  await ps.getByTestId('sticker-dx').blur();
  await done;
  done = saved('"copies":2');
  await ps.getByTestId('sticker-copies').fill('2');
  await done;
  await page.reload();
  await afterSplash(page);
  await expect(page.getByTestId('preview-sticker')).toHaveAttribute('data-size', '45x28');
  await expect(page.getByRole('checkbox', { name: 'طباعة الإطار حوالين الاستيكر' })).toHaveAttribute('data-state', 'checked');
  await expect(page.getByTestId('sticker-dx')).toHaveValue('1.5');
  await expect(page.getByTestId('sticker-copies')).toHaveValue('2');
  // طباعة اختبار (إطار ومسطرة) بالمقاس
  await page.goto('/#/print/sticker-test/test');
  await expect(page.getByTestId('sticker-test')).toContainText('45 × 28 mm');
});

test('طباعة وإرسال في شاشة الاستلام: التلقائي بيتعمل لوحده، وكل زرار بضغطة وعلامة، والاستيكر فيه الباقي صح، ورقم محفوظ، وصفحة الجهاز فيها نفس الأزرار', async ({ page }, info) => {
  test.setTimeout(240_000);
  await prefs(page, info);
  await page.addInitScript(() => {
    window.print = () => undefined;
    (window as unknown as { __opened: string[] }).__opened = [];
    window.open = ((u: string) => {
      (window as unknown as { __opened: string[] }).__opened.push(String(u));
      return {} as Window;
    }) as typeof window.open;
  });
  await registerShop(page, uniq('psend'), 'محل الطباعة');
  // تلقائي بعد الاستلام: الاستيكر والورقي والـ QR
  await page.goto('/#/settings?tab=print');
  const ps = page.getByTestId('print-settings');
  for (const a of ['استيكر الجهاز', 'طباعة ورقية (إيصال A4)', 'ملصق QR للتتبع']) {
    await ps.getByRole('checkbox', { name: a }).click();
    await expect(ps.getByRole('checkbox', { name: a })).toHaveAttribute('data-state', 'checked');
  }

  // الاستلام بتقدير 500، وEnter في آخر خانة بيحفظ
  const phone = `010${String(Date.now()).slice(-8)}`;
  await page.goto('/#/intake');
  await afterSplash(page);
  await page.locator('#intake-phone').fill(phone);
  await page.getByLabel('اسم العميل').fill('عميل الطباعة');
  await page.getByRole('button', { name: 'Samsung', exact: true }).click();
  await page.getByLabel('الموديل').fill('A35');
  await page.getByLabel('العطل زي ما العميل وصفه').fill('شاشة مكسورة');
  await page.getByLabel('التكلفة التقديرية').fill('500');
  // Enter في آخر خانة بيحفظ، و"طباعة وإرسال" بيظهر على طول في نفس الشاشة
  await page.getByLabel('التكلفة التقديرية').press('Enter');
  const panel = page.getByTestId('print-send');
  await expect(panel).toBeVisible();
  // اللي متعلّم تلقائي اتعمل من نفس الشاشة، والباقي لسه
  for (const a of ['sticker', 'paper', 'qr']) await expect(panel.getByTestId(`ps-${a}-done`)).toHaveAttribute('data-done', 'true', { timeout: 30_000 });
  for (const a of ['thermal', 'whatsapp']) await expect(panel.getByTestId(`ps-${a}-done`)).toHaveAttribute('data-done', 'false');
  await expect(page).toHaveURL(/#\/intake/);
  // الحراري بضغطة
  await panel.getByTestId('ps-thermal').click();
  await expect(panel.getByTestId('ps-thermal-done')).toHaveAttribute('data-done', 'true', { timeout: 30_000 });
  // واتساب: رسالة الاستلام برابط التتبع
  await panel.getByTestId('ps-whatsapp').click();
  await expect(panel.getByTestId('ps-whatsapp-done')).toContainText('اتبعت');
  const wa = (await page.evaluate(() => (window as unknown as { __opened: string[] }).__opened)).find((u) => u.startsWith('https://wa.me/'))!;
  expect(decodeURIComponent(wa)).toMatch(/#\/t\/[0-9a-f]{24}/);
  // رقم محفوظ: بيفضل بعد إعادة التحميل، وبيتطبع على الاستيكر لو اتختار
  await panel.getByTestId('saved-number').fill('A-777');
  await panel.getByTestId('saved-number-use').click();
  await panel.getByTestId('ps-sticker').click();
  await expect.poll(() => page.locator('[data-testid="print-frame"]').last().getAttribute('src').catch(() => ''), { timeout: 10_000 }).toContain('no=A-777');
  await page.keyboard.press('Escape');

  // صفحة الجهاز: نفس الأزرار والعلامات، ودفعة 200 ← الاستيكر: التكلفة 500 والمقدم 200 والباقي 300
  await page.goto('/#/devices');
  await page.getByText('عميل الطباعة').filter({ visible: true }).first().click();
  const id = page.url().split('/devices/')[1];
  const dp = page.getByTestId('print-send');
  await expect(dp.getByTestId('ps-thermal-done')).toHaveAttribute('data-done', 'true');
  await expect(dp.getByTestId('saved-number')).toHaveValue('A-777');
  await page.getByLabel('التكلفة النهائية').fill('500');
  await page.getByRole('button', { name: 'حفظ التكلفة' }).click();
  await expect(page.getByText('اتحفظت التكلفة')).toBeVisible();
  await page.getByRole('button', { name: 'تسجيل دفعة' }).click();
  await fillAmount(page.getByRole('dialog'), '200');
  await page.getByRole('dialog').getByRole('button', { name: 'سجّل' }).click();
  await expect(page.getByText('اتسجلت العملية')).toBeVisible();
  await page.goto(`/#/print/sticker/${id}`);
  const st = page.getByTestId('sticker');
  await expect(st.getByTestId('sticker-total')).toContainText('500');
  await expect(st.getByTestId('sticker-paid')).toContainText('200');
  await expect(st.getByTestId('sticker-due')).toContainText('300');
  await expect(st.getByTestId('sticker-customer')).toHaveText('عميل الطباعة');
  await expect(st.getByTestId('sticker-phone')).toHaveText(phone);
  await expect(st.getByTestId('sticker-issue')).toContainText('شاشة مكسورة');
  await expect(st.locator('img, svg')).toHaveCount(0); // من غير لوجو ولا QR ولا باركود
  expect(await fitsInside(page, 'sticker')).toMatchObject({ inside: true, fitsHeight: true });
  // ملصق الـ QR للتتبع (منفصل عن الاستيكر)
  await page.goto(`/#/print/label/${id}`);
  await expect(page.getByTestId('qr-img')).toBeVisible();

  // التسليم ← فاتورة التسليم فيها المدفوع والفاضل والضمان
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
  const inv = page.getByTestId('print-invoice');
  await expect(inv.getByTestId('invoice-paid')).toContainText('500');
  await expect(inv.getByTestId('invoice-due')).toContainText('0');
  await expect(inv).toContainText('الضمان');
});
