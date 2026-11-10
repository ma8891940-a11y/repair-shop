import { expect, test, type Page } from '@playwright/test';
import { activateInvite, afterSplash, prefs, quickIntake, registerShop, uniq } from './helpers';

// S3: المساعد في البرنامج كله (رد السيرفر متمثّل). اللي بيخرج من المتصفح من غير اسم العميل ولا رقمه،
// والاقتراح ما بيتنفذش غير بـ "تطبيق"، وإعدادات صاحب المحل بتتطبق
const NAME = 'سامح عبد الله';

async function mockAssistant(page: Page, sent: Record<string, unknown>[]) {
  await page.route('**/functions/v1/assistant', async (route) => {
    if (route.request().method() === 'OPTIONS') return route.fulfill({ status: 200, headers: { 'access-control-allow-origin': '*', 'access-control-allow-headers': '*' } });
    const body = route.request().postDataJSON() as Record<string, unknown>;
    if (body.status !== true) sent.push(body);
    const answers: Record<string, string> = {
      intake: '{"issue": "شاشة مكسورة ومحتاجة تغيير", "cost_min": 1400, "cost_max": 1600, "questions": ["الجهاز وقع في مية؟"]}',
      whatsapp: 'أهلا {name}، جهازك {device} رقم {order} اتسجل عندنا.',
      screen: 'دوس على "حفظ الاستلام" بعد ما تكمّل الخانات.',
      finance_qa: 'الربح كويس مقارنة بالمصروفات.',
      finance_week: 'الأسبوع ده الإيراد زاد.',
      report: 'أكتر عطل: الشاشات.',
    };
    const json = body.status === true ? { enabled: true } : { answer: answers[String(body.kind)] ?? 'تمام', left: 9 };
    await route.fulfill({ status: 200, contentType: 'application/json', headers: { 'access-control-allow-origin': '*' }, body: JSON.stringify(json) });
  });
}

test('المساعد في كل مكان: الاستلام (من تاريخ المحل وبالذكاء)، وواتساب، والزرار العايم، والمالية مقفولة لحد ما تتفتح، والتقارير، ومن غير بيانات العميل', async ({ page }, info) => {
  test.setTimeout(240_000);
  await prefs(page, info);
  const sent: Record<string, unknown>[] = [];
  await mockAssistant(page, sent);
  await registerShop(page, uniq('assist'), 'محل المساعد');
  const phone = `010${String(Date.now()).slice(-8)}`;

  // تاريخ المحل: جهاز A35 قبل كده بشاشة مكسورة بـ 1,500
  await quickIntake(page, `011${String(Date.now()).slice(-8)}`, 'عميل قديم');
  await page.getByLabel('التكلفة النهائية').fill('1,500');
  await page.getByRole('button', { name: 'حفظ التكلفة' }).click();
  await expect(page.getByText('اتحفظت التكلفة')).toBeVisible();

  // 1) الاستلام
  await page.goto('/#/intake');
  await page.locator('#intake-phone').fill(phone);
  await page.getByLabel('اسم العميل').fill(NAME);
  await page.getByRole('button', { name: 'Samsung', exact: true }).click();
  await page.getByLabel('الموديل').fill('A35');
  const issue = page.getByLabel('العطل زي ما العميل وصفه');
  await issue.fill(`${NAME} بيقول الشاشة وقعت، كلموه على ${phone}`);
  // من تاريخ المحل (شغال من غير نت ولا مفتاح): دوسة بتملا العطل والتكلفة
  const hint = page.getByTestId('intake-hint').first();
  await expect(hint).toContainText('شاشة مكسورة');
  await expect(hint).toContainText('1,500');
  // بالذكاء: الرد بيظهر، والفورم ما بيتغيّرش غير بـ "تطبيق"
  await page.getByTestId('assist-intake-ask').click();
  await expect(page.getByTestId('assist-intake-answer')).toContainText('شاشة مكسورة ومحتاجة تغيير');
  await expect(page.getByTestId('assist-intake-answer')).toContainText('الجهاز وقع في مية؟');
  await expect(issue).toHaveValue(new RegExp(NAME));
  await page.getByTestId('assist-intake-apply').click();
  await expect(issue).toHaveValue('شاشة مكسورة ومحتاجة تغيير');
  await expect(page.getByLabel('التكلفة التقديرية')).toHaveValue('1,500');
  await hint.click();
  await expect(issue).toHaveValue('شاشة مكسورة');
  const intakeReq = sent.find((b) => b.kind === 'intake')!;
  expect(String(intakeReq.device)).toContain('A35');
  expect(JSON.stringify(intakeReq)).toContain('شاشة مكسورة');

  // 2) الزرار العايم: الشرح المدمج دايمًا، والسؤال بيروح باسم الشاشة بس
  await page.getByTestId('screen-assist').click();
  await expect(page.getByTestId('screen-assist-panel')).toHaveAttribute('data-screen', 'intake');
  await expect(page.getByTestId('screen-help')).toContainText('رقم الموبايل');
  await page.getByLabel('سؤالك عن الشاشة دي').fill(`أحفظ إزاي؟ العميل ${NAME} رقمه ${phone}`);
  await page.getByTestId('screen-assist-ask').click();
  await expect(page.getByTestId('screen-assist-answer')).toContainText('حفظ الاستلام');
  await page.keyboard.press('Escape');
  expect(sent.find((b) => b.kind === 'screen')).toMatchObject({ screen: 'intake' });

  // 3) الحفظ ← صفحة الجهاز ← واتساب: المسودة بالمتغيرات والاسم بيتملي على الجهاز، و"تطبيق" بيحطها في الرسالة
  await page.getByRole('button', { name: 'حفظ الاستلام' }).click();
  await page.getByRole('button', { name: 'فتح الجهاز' }).click();
  await page.getByRole('button', { name: 'واتساب', exact: true }).first().click();
  const dlg = page.getByRole('dialog');
  await dlg.getByTestId('assist-wa-ask').click();
  await expect(dlg.getByTestId('assist-wa-answer')).toContainText("أهلا سامح، جهازك Samsung A35");
  await expect(dlg.getByRole('textbox').first()).not.toHaveValue(/أهلا/);
  await dlg.getByTestId('assist-wa-apply').click();
  await expect(dlg.getByRole('textbox').first()).toHaveValue(/أهلا سامح، جهازك Samsung A35/);
  await page.keyboard.press('Escape');

  // 4) المالية: مقفولة افتراضيًا ← تتفتح من الإعدادات ← المساعد (وفيها تنبيه الطبقة المجانية)
  await page.goto('/#/finance');
  await expect(page.getByTestId('finance-assist-off')).toBeVisible();
  await page.goto('/#/settings?tab=assistant');
  const st = page.getByTestId('assistant-settings');
  await expect(st.getByRole('checkbox', { name: 'أسئلة المالية والملخص الأسبوعي' })).toHaveAttribute('data-state', 'unchecked');
  await expect(st).toContainText('Google ممكن تستخدم البيانات');
  await st.getByRole('checkbox', { name: 'أسئلة المالية والملخص الأسبوعي' }).click();
  await expect(st.getByRole('checkbox', { name: 'أسئلة المالية والملخص الأسبوعي' })).toHaveAttribute('data-state', 'checked');
  await page.goto('/#/finance');
  await afterSplash(page);
  await page.getByLabel('مثلًا: ليه الربح قل الشهر ده؟').fill(`ليه الربح كده؟ ${phone}`);
  await page.getByTestId('finance-assist-ask').click();
  await expect(page.getByTestId('finance-assist-answer')).toContainText('الربح كويس');
  await page.getByTestId('finance-assist-week').click();
  await expect(page.getByTestId('finance-assist-answer')).toContainText('الإيراد زاد');
  const fin = sent.find((b) => b.kind === 'finance_qa')!;
  expect(Object.keys(fin).sort()).toEqual(['kind', 'numbers', 'period', 'question']);
  expect(Object.values(fin.numbers as Record<string, unknown>).every((v) => Number.isInteger(v))).toBe(true);

  // 5) التقارير: ملخص مكتوب
  await page.goto('/#/reports');
  await page.getByTestId('assist-report-ask').click();
  await expect(page.getByTestId('assist-report-answer')).toContainText('الشاشات');

  // في كل الطلبات: ولا اسم العميل ولا رقمه
  expect(sent.map((b) => b.kind)).toEqual(expect.arrayContaining(['intake', 'screen', 'whatsapp', 'finance_qa', 'finance_week', 'report']));
  const all = JSON.stringify(sent);
  expect(all).not.toContain(phone);
  expect(all).not.toContain('سامح');
  expect(all).not.toContain('عبد الله');
});

test('إعدادات المساعد بتتطبق: صاحب المحل بيقفله على الفنيين وبيقفل الاستلام، واقتراحات تاريخ المحل والدليل المدمج شغالين', async ({ page, browser }, info) => {
  test.setTimeout(240_000);
  await prefs(page, info);
  const sent: Record<string, unknown>[] = [];
  await mockAssistant(page, sent);
  await registerShop(page, uniq('assist2'), 'محل المساعد 2');
  const dev = await quickIntake(page, `012${String(Date.now()).slice(-8)}`, 'عميل');
  await page.goto('/#/settings?tab=assistant');
  const st = page.getByTestId('assistant-settings');
  await st.getByRole('checkbox', { name: 'الفنيين' }).click();
  await expect(st.getByRole('checkbox', { name: 'الفنيين' })).toHaveAttribute('data-state', 'unchecked');
  await st.getByRole('checkbox', { name: 'اقتراحات الاستلام' }).click();
  await expect(st.getByRole('checkbox', { name: 'اقتراحات الاستلام' })).toHaveAttribute('data-state', 'unchecked');
  // الاستلام: زرار الذكاء مش موجود، بس اقتراحات تاريخ المحل موجودة
  await page.goto('/#/intake');
  await page.getByRole('button', { name: 'Samsung', exact: true }).click();
  await page.getByLabel('الموديل').fill('A35');
  await expect(page.getByTestId('intake-hint').first()).toContainText('شاشة مكسورة');
  await expect(page.getByTestId('assist-intake-ask')).toHaveCount(0);

  // الفني: صفحة الجهاز بتقول إن المساعد مقفول هنا، والدليل المدمج شغال، والزرار العايم شرح بس
  await page.goto('/#/users');
  const em = uniq('tech-as');
  await page.getByLabel('الاسم').fill('فني');
  await page.getByLabel('الإيميل').fill(em);
  await page.getByLabel('الدور').selectOption('technician');
  await page.getByRole('button', { name: 'إرسال الدعوة' }).click();
  await expect(page.getByText('اتعملت الدعوة')).toBeVisible();
  const T = await activateInvite(browser, info, em);
  await mockAssistant(T.page, sent);
  await T.page.goto(dev);
  await afterSplash(T.page);
  await expect(T.page.getByTestId('assist-off-here')).toBeVisible();
  await expect(T.page.getByRole('button', { name: 'اقترح الأسباب وخطوات الفحص' })).toHaveCount(0);
  await T.page.getByRole('button', { name: 'دليل الأعطال المدمج' }).click();
  await expect(T.page.getByTestId('assistant-guide')).toBeVisible();
  await T.page.getByTestId('screen-assist').click();
  await expect(T.page.getByTestId('screen-help')).toBeVisible();
  await expect(T.page.getByTestId('screen-assist-ask')).toHaveCount(0);
  await T.ctx.close();
  expect(sent).toHaveLength(0);
});
