import { expect, test, type Page } from '@playwright/test';
import { afterSplash, noHorizontalScroll, prefs, quickIntake, registerShop, uniq } from './helpers';

/** ألوان بكسلات صورة على الصفحة: هل فيها رمادي/ألوان، ولا أبيض وأسود صريح بس؟ */
async function pixelStats(page: Page, testid: string) {
  return page.getByTestId(testid).first().evaluate(async (img: HTMLImageElement) => {
    await img.decode();
    const c = document.createElement('canvas');
    c.width = img.naturalWidth;
    c.height = img.naturalHeight;
    const ctx = c.getContext('2d')!;
    ctx.drawImage(img, 0, 0);
    const d = ctx.getImageData(0, 0, c.width, c.height).data;
    let colored = 0;
    let gray = 0;
    let black = 0;
    for (let i = 0; i < d.length; i += 4) {
      if (d[i + 3] === 0) continue;
      const [r, g, b] = [d[i], d[i + 1], d[i + 2]];
      if (r === 0 && g === 0 && b === 0) black++;
      else if (r === g && g === b) gray++;
      else colored++;
    }
    return { colored, gray, black };
  });
}

test('هوية المحل: كل محل بيطبع باسمه ولوجوه، الإيصال أبيض وأسود والفاتورة ملونة، ولوجو التطبيق مش ظاهر للعميل', async ({ page, browser }, info) => {
  test.setTimeout(240_000);
  await prefs(page, info);
  await registerShop(page, uniq('idA'), 'محل النجوم');

  // هوية المحل الأول: لوجو ملون وشعار
  await page.goto('/#/settings');
  await page.getByRole('tab', { name: 'هوية المحل' }).click();
  await page.getByLabel('شعار قصير تحت الاسم').fill('صيانة بضمان حقيقي');
  await page.getByLabel('لوجو المحل').setInputFiles('public/icon-512.png');
  await expect(page.getByTestId('logo-crop')).toBeVisible();
  // المعاينة الحيّة قبل الحفظ
  await expect(page.getByTestId('preview-receipt').getByTestId('shop-logo-thermal')).toBeVisible();
  await expect(page.getByTestId('preview-invoice').getByTestId('shop-logo-color')).toBeVisible();
  await page.getByRole('button', { name: 'حفظ', exact: true }).click();
  await expect(page.getByText('اتحفظ').first()).toBeVisible();
  await noHorizontalScroll(page);
  const devA = await quickIntake(page, '01212121212');

  // الإيصال الحراري: لوجو المحل أبيض وأسود صريح، واسمه، ومن غير "بواسطة"
  await page.goto(devA.replace('/devices/', '/print/receipt/'));
  await expect(page.getByTestId('shop-logo-thermal')).toBeVisible();
  await expect(page.getByText('محل النجوم').first()).toBeVisible();
  await expect(page.getByText('صيانة بضمان حقيقي')).toBeVisible();
  const th = await pixelStats(page, 'shop-logo-thermal');
  expect(th.black).toBeGreaterThan(0);
  expect(th.colored + th.gray).toBe(0);
  await expect(page.getByTestId('powered-by')).toHaveCount(0);
  await expect(page.getByText('جوالك', { exact: true })).toHaveCount(0);

  // الفاتورة A4: اللوجو ملون
  await page.goto(devA.replace('/devices/', '/print/invoice/'));
  await expect(page.getByTestId('shop-logo-color')).toBeVisible();
  expect((await pixelStats(page, 'shop-logo-color')).colored).toBeGreaterThan(0);
  // الملصق
  await page.goto(devA.replace('/devices/', '/print/label/'));
  await expect(page.getByTestId('shop-logo-thermal')).toBeVisible();

  // صفحة التتبع: لوجو المحل واسمه، من غير لوجو التطبيق
  await page.goto(devA);
  await afterSplash(page);
  await page.getByRole('button', { name: 'واتساب', exact: true }).first().click();
  const text = await page.getByRole('dialog').getByLabel('معاينة').inputValue();
  expect(text).toContain('محل النجوم'); // الرسالة باسم المحل
  const token = (text.match(/#\/t\/([0-9a-f]{24})/) ?? [])[1];
  const ctx = await browser.newContext(info.project.use);
  const cust = await ctx.newPage();
  await prefs(cust, info);
  await cust.goto(`/#/t/${token}`);
  await expect(cust.getByTestId('shop-logo-color')).toBeVisible();
  await expect(cust.getByText('محل النجوم')).toBeVisible();
  await expect(cust.locator('[data-testid="app-mark"]')).toHaveCount(0);
  await ctx.close();
  await page.keyboard.press('Escape');

  // "بواسطة" اختياري
  await page.goto('/#/settings');
  await page.getByRole('tab', { name: 'هوية المحل' }).click();
  await page.getByText('اطبع سطر صغير في آخر الإيصال').click();
  await page.getByRole('button', { name: 'حفظ', exact: true }).click();
  await expect(page.getByText('اتحفظ').first()).toBeVisible();
  await page.goto(devA.replace('/devices/', '/print/receipt/'));
  await expect(page.getByTestId('powered-by')).toContainText('بواسطة جوالك');

  // المحل التاني من غير لوجو: الاسم كبير، ومفيش أي أثر لهوية المحل الأول
  const ctxB = await browser.newContext(info.project.use);
  const pb = await ctxB.newPage();
  await prefs(pb, info);
  await registerShop(pb, uniq('idB'), 'محل القمر');
  const devB = await quickIntake(pb, '01234343434');
  await pb.goto(devB.replace('/devices/', '/print/receipt/'));
  await expect(pb.getByTestId('shop-name-big')).toHaveText('محل القمر');
  await expect(pb.getByTestId('shop-logo-thermal')).toHaveCount(0);
  await expect(pb.getByText('محل النجوم')).toHaveCount(0);
  await expect(pb.getByText('صيانة بضمان حقيقي')).toHaveCount(0);
  await pb.goto(devB.replace('/devices/', '/print/invoice/'));
  await expect(pb.getByTestId('shop-name-big')).toHaveText('محل القمر');
  await expect(pb.getByTestId('powered-by')).toHaveCount(0);
  await ctxB.close();
});
