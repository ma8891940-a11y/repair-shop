import { expect, test } from '@playwright/test';
import { activateInvite, afterSplash, fillField, noHorizontalScroll, prefs, registerShop, uniq } from './helpers';

/** وقت محلي لخانة datetime-local (المتصفح والاختبار على نفس الجهاز) */
const local = (ms: number) => {
  const d = new Date(ms);
  const p = (n: number) => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}T${p(d.getHours())}:${p(d.getMinutes())}`;
};

// R2: الحضور والانصراف: زرار في الشريط العلوي، وشاشة "حضوري"، والفريق لصاحب المحل، والتصليح بسبب، والفني ما يشوفش الفريق
test('الحضور والانصراف: حضور ← انصراف ← الفريق ← تصليح بسبب ← إضافة ← الفني يشوف نفسه بس', async ({ page, browser }, info) => {
  test.setTimeout(240_000);
  await prefs(page, info);
  await registerShop(page, uniq('att'), 'محل الحضور');

  // 1) حضور من الشريط العلوي
  const top = page.getByTestId('att-button');
  await expect(top).toHaveAttribute('data-state', 'out');
  await top.click();
  await expect(page.getByText('اتسجّل حضورك')).toBeVisible();
  await expect(top).toHaveAttribute('data-state', 'in');

  // 2) الشاشة: السجل المفتوح في "حضوري" وفي الفريق، والزرارين متزامنين
  await page.goto('/#/attendance');
  await afterSplash(page);
  const mine = page.getByTestId('att-mine');
  await expect(mine.getByTestId('att-row')).toHaveCount(1);
  await expect(mine.getByTestId('att-minutes')).toHaveText('لسه حاضر');
  await expect(page.getByTestId('att-team').getByTestId('att-total')).toHaveCount(1);
  await page.getByTestId('att-button-page').click();
  await expect(page.getByText('اتسجّل انصرافك')).toBeVisible();
  await expect(top).toHaveAttribute('data-state', 'out');
  await expect(mine.getByTestId('att-minutes')).not.toHaveText('لسه حاضر');

  // 3) تصليح السجل: من غير سبب مرفوض، وبالسبب المدة بتتحسب من السيرفر
  const team = page.getByTestId('att-team');
  await team.getByTestId('att-fix').first().click();
  let dlg = page.getByRole('dialog');
  const now = Date.now();
  await dlg.getByTestId('att-in').fill(local(now - 3 * 3600_000));
  await dlg.getByTestId('att-out').fill(local(now - 30 * 60_000));
  await dlg.getByTestId('att-save').click();
  await expect(dlg.getByText('لازم تكتب السبب')).toBeVisible();
  await fillField(dlg.getByTestId('att-reason'), 'نسي يسجّل الانصراف');
  await dlg.getByTestId('att-save').click();
  await expect(dlg).toHaveCount(0);
  await expect(team.getByTestId('att-team-table').getByTestId('att-minutes').first()).toHaveText('2 س 30 د');

  // 4) ميعاد بداية الشغل
  await page.getByTestId('att-start').fill('09:00');
  await fillField(page.getByTestId('att-grace'), '10');
  await page.getByTestId('att-settings-save').click();
  await expect(page.getByText('اتحفظت الإعدادات')).toBeVisible();
  await noHorizontalScroll(page);

  // 5) الفني: يسجّل حضوره ويشوف نفسه بس، ومن غير "الفريق"
  await page.goto('/#/users');
  await afterSplash(page);
  const techEmail = uniq('att-tech');
  await page.getByLabel('الاسم').fill('فني الحضور');
  await page.getByLabel('الإيميل').fill(techEmail);
  await page.getByLabel('الدور').selectOption('technician');
  await page.getByRole('button', { name: 'إرسال الدعوة' }).click();
  await expect(page.getByText('اتعملت الدعوة')).toBeVisible();
  const tech = await activateInvite(browser, info, techEmail);
  await tech.page.goto('/#/attendance');
  await afterSplash(tech.page);
  await tech.page.getByTestId('att-button-page').click();
  await expect(tech.page.getByText('اتسجّل حضورك')).toBeVisible();
  await expect(tech.page.getByTestId('att-mine').getByTestId('att-row')).toHaveCount(1);
  await expect(tech.page.getByTestId('att-team')).toHaveCount(0);
  await expect(tech.page.getByTestId('att-settings')).toHaveCount(0);
  await tech.ctx.close();

  // 6) صاحب المحل بيشوف الفني في الفريق، ويضيف سجل بسبب
  await page.goto('/#/attendance');
  await afterSplash(page);
  await expect(team.getByTestId('att-total')).toHaveCount(2);
  await page.getByTestId('att-add').click();
  dlg = page.getByRole('dialog');
  await dlg.getByTestId('att-person').selectOption({ label: 'فني الحضور' });
  await dlg.getByTestId('att-in').fill(local(Date.now() - 6 * 3600_000));
  await dlg.getByTestId('att-out').fill(local(Date.now() - 5 * 3600_000));
  await fillField(dlg.getByTestId('att-reason'), 'كان في مشوار للمحل');
  await dlg.getByTestId('att-save').click();
  await expect(dlg).toHaveCount(0);
  await expect(team.getByTestId('att-team-table').getByTestId('att-row')).toHaveCount(3);
});
